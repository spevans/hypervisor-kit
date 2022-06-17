//
//  memoryregion.swift
//  HypervisorKit
//
//  Created by Simon Evans on 27/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import Foundation
@_implementationOnly import CHypervisorKit
import BABAB

#if os(macOS)
import Hypervisor
#endif


public final class MemoryRegion {

#if os(macOS)
    struct SubRegion {
        let pointer: UnsafeMutableRawPointer
        let guestAddress: PhysicalAddress
        let size: UInt64
        var isReadable: Bool
        var isWritable: Bool
        var rawBuffer:  UnsafeMutableRawBufferPointer {
            UnsafeMutableRawBufferPointer(start: pointer, count: Int(size))
        }
    }
#endif

#if os(Linux)
    struct SubRegion {
        internal let kvmRegion: kvm_userspace_memory_region
        var pointer: UnsafeMutableRawPointer { UnsafeMutableRawPointer(bitPattern: UInt(kvmRegion.userspace_addr))! }
        var guestAddress: PhysicalAddress { PhysicalAddress(kvmRegion.guest_phys_addr) }
        var size: UInt64 { kvmRegion.memory_size }
        let isReadable = true
        var isWritable: Bool { kvmRegion.flags & KVM_MEM_READONLY == 0 }
        var rawBuffer:  UnsafeMutableRawBufferPointer {
            UnsafeMutableRawBufferPointer(start: pointer, count: Int(size))
        }
    }
#endif


    static private let pageSize = 4096
    private(set) internal var subRegions: [SubRegion]
    internal let pointer: UnsafeMutableRawPointer
    public var rawBuffer: UnsafeMutableRawBufferPointer { UnsafeMutableRawBufferPointer(start: pointer, count: Int(size)) }

    public let guestAddress: PhysicalAddress
    public let size: UInt64

#if os(macOS)

    // If memory region is not read-only, then set a flag when a page in the memory region is first written to.
    private var dirtyPageLog: [Bool] = []
    private let pageCount: Int


    init(sizes: [UInt64], at address: RawAddress, readOnly: Bool = false) throws {
        precondition(address & 0xfff == 0)
        precondition(!sizes.isEmpty)

        subRegions = []
        subRegions.reserveCapacity(sizes.count)
        var totalSize = 0
        for size in sizes {
            precondition(size & 0xfff == 0)
            totalSize += Int(size);
        }

        // 4KB Aligned memory
        var ptr: UnsafeMutableRawPointer? = nil

        guard posix_memalign(&ptr, MemoryRegion.pageSize, totalSize) == 0, let _pointer = ptr else {
            throw VMError.memoryAllocationFailure
        }
        pointer = _pointer
        pointer.initializeMemory(as: UInt8.self, repeating: 0, count: totalSize)

        let flags: hv_memory_flags_t
        if readOnly {
            flags = hv_memory_flags_t(HV_MEMORY_READ | HV_MEMORY_EXEC)
        } else {
            flags = hv_memory_flags_t(HV_MEMORY_READ | HV_MEMORY_WRITE | HV_MEMORY_EXEC)
        }

        var offset: UInt64 = 0
        for size in sizes {
            let ptr = pointer.advanced(by: Int(offset))
            let guestAddress = address + offset
            try hvError(hv_vm_map(ptr, guestAddress, Int(size), flags))
            let subRegion = SubRegion(pointer: ptr,
                                      guestAddress: PhysicalAddress(guestAddress),
                                      size: size,
                                      isReadable: true,
                                      isWritable: !readOnly)
            subRegions.append(subRegion)
            offset += size
        }

        guestAddress = PhysicalAddress(address)
        self.size = UInt64(totalSize)
        self.pageCount = (totalSize + MemoryRegion.pageSize - 1) / MemoryRegion.pageSize
        dirtyPageLog.reserveCapacity(pageCount)
        for _ in 0..<pageCount {
            dirtyPageLog.append(false)
        }
     }

    internal func setWriteTo(address guestPhysicalAddress: PhysicalAddress) {
        guard self.isAddressWritable(gpa: guestPhysicalAddress) else { return }
        let page = (guestPhysicalAddress - self.guestAddress) / MemoryRegion.pageSize
        dirtyPageLog[page] = true
    }

    deinit {
        free(pointer)
    }

#elseif os(Linux)

    static private let KVM_MEM_LOG_DIRTY_PAGES  = 1
    static internal let KVM_MEM_READONLY: UInt32 = 2


    init(sizes: [UInt64], at address: UInt64, slot: Int, readOnly: Bool = false) throws {
        precondition(address & 0xfff == 0)
        precondition(!sizes.isEmpty)

        subRegions = []
        subRegions.reserveCapacity(sizes.count)
        var totalSize = 0
        for size in sizes {
            precondition(size & 0xfff == 0)
            totalSize += Int(size);
        }

        // 4KB Aligned memory
        var ptr: UnsafeMutableRawPointer? = nil

        guard posix_memalign(&ptr, MemoryRegion.pageSize, totalSize) == 0, let _pointer = ptr else {
            throw VMError.memoryAllocationFailure
        }
        pointer = _pointer
        pointer.initializeMemory(as: UInt8.self, repeating: 0, count: totalSize)


        let flags = readOnly ? MemoryRegion.KVM_MEM_READONLY : 0

        var offset: UInt64 = 0
        var slot = slot
        for size in sizes {
            let ptr = pointer.advanced(by: Int(offset))
            let guestAddress = address + offset
            let kvmRegion = kvm_userspace_memory_region(slot: UInt32(slot), flags: flags,
                                                 guest_phys_addr: guestAddress,
                                                 memory_size: UInt64(size),
                                                 userspace_addr: UInt64(UInt(bitPattern: ptr)))

            let subRegion = SubRegion(kvmRegion: kvmRegion)
            subRegions.append(subRegion)
            offset += size
            slot += 1
        }

        guestAddress = PhysicalAddress(address)
        self.size = UInt64(totalSize)
    }

    deinit {
        free(pointer)
    }

#endif

    public func loadBinary(from binary: Data, atOffset offset: UInt64 = 0) throws {
        guard binary.count <= size - offset else {
            throw VMError.memoryRegionTooSmall
        }
        let buffer = UnsafeMutableRawBufferPointer(start: pointer.advanced(by: Int(offset)), count: binary.count)
        binary.copyBytes(to: buffer)
    }


    public func dumpMemory(at offset: Int, count: Int) -> String {
        let ptr = self.rawBuffer.baseAddress!.advanced(by: offset)
        let buffer = UnsafeRawBufferPointer(start: ptr, count: count)

        var idx = 0
        var output = "\(hexNum(UInt16(offset + idx))): "
        for byte in buffer {
            output += hexNum(byte)
            output += " "
            idx += 1
            if idx == count { break }
            if idx.isMultiple(of: 16) {
                output += "\n\(hexNum(UInt16(offset + idx))): "
            }
        }
        return output
    }

    public func isAddressReadable(gpa: PhysicalAddress) -> Bool {
        if let index = findSubRegionIndex(containing: gpa) {
            return subRegions[index].isReadable
        } else {
            return false
        }
    }

    public func isAddressWritable(gpa: PhysicalAddress) -> Bool {
        if let index = findSubRegionIndex(containing: gpa) {
            return subRegions[index].isWritable
        } else {
            return false
        }
    }

    internal func modifySubRegion(gpa: PhysicalAddress, size: UInt64, modifier: (SubRegion) throws -> SubRegion) throws {
        if let index = findSubRegionIndex(containing: gpa) {
            let region = self.subRegions[index]
            if region.guestAddress == gpa && region.size == size {
                self.subRegions[index] = try modifier(region)
                return
            }
        }
        throw VMError.invalidMemoryRegion
    }

    private func findSubRegionIndex(containing gpa: PhysicalAddress) -> Int? {
        for index in subRegions.startIndex..<subRegions.endIndex {
            let region = subRegions[index]
            if gpa >= region.guestAddress && gpa < region.guestAddress + region.size {
                return index
            }
        }
        return nil
    }
}
