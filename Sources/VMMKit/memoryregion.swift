//
//  memoryregion.swift
//  VMMKit
//
//  Created by Simon Evans on 27/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import Foundation
import CBits
#if os(macOS)
import Hypervisor
#endif


public final class MemoryRegion {

    static private let pageSize = 4096
    internal let pointer: UnsafeMutableRawPointer
    public var rawBuffer: UnsafeMutableRawBufferPointer { UnsafeMutableRawBufferPointer(start: pointer, count: Int(size)) }
    public let readOnly: Bool
    public var isWriteable: Bool { readOnly == false }

#if os(macOS)

    public let guestAddress: PhysicalAddress
    public let size: UInt64

    private var dirtyPageLog: [Bool] = []
    private let pageCount: Int


    init(size: UInt64, at address: RawAddress, readOnly: Bool = false) throws {
        precondition(address & 0xfff == 0)
        precondition(size & 0xfff == 0)

        // 4KB Aligned memory
        var ptr: UnsafeMutableRawPointer? = nil

        guard posix_memalign(&ptr, MemoryRegion.pageSize, Int(size)) == 0, let _pointer = ptr else {
            throw VMError.memoryAllocationFailure
        }
        pointer = _pointer

        self.readOnly = readOnly
        pointer.initializeMemory(as: UInt8.self, repeating: 0, count: Int(size))

        let flags: hv_memory_flags_t
        if readOnly {
            flags = hv_memory_flags_t(HV_MEMORY_READ | HV_MEMORY_EXEC)
        } else {
            flags = hv_memory_flags_t(HV_MEMORY_READ | HV_MEMORY_WRITE | HV_MEMORY_EXEC)
        }

        try hvError(hv_vm_map(pointer, address, Int(size), flags))

        guestAddress = PhysicalAddress(address)
        self.size = size
        self.pageCount = Int((size + UInt64(MemoryRegion.pageSize) - 1) / UInt64(MemoryRegion.pageSize))
        dirtyPageLog.reserveCapacity(pageCount)
        for _ in 0..<pageCount {
            dirtyPageLog.append(false)
        }
    }

    public func setWriteTo(address guestPhysicalAddress: PhysicalAddress) {
        precondition(self.isWriteable)
        let page = (guestPhysicalAddress - self.guestAddress) / MemoryRegion.pageSize
        dirtyPageLog[page] = true
    }

    deinit {
        free(pointer)
    }

#elseif os(Linux)

    static private let KVM_MEM_LOG_DIRTY_PAGES = 1
    static private let KVM_MEM_READONLY        = 2

    internal let kvmRegion: kvm_userspace_memory_region

    var guestAddress: PhysicalAddress { PhysicalAddress(kvmRegion.guest_phys_addr) }
    var size: UInt64 { kvmRegion.memory_size }


    init(size: UInt64, at address: UInt64, slot: Int, readOnly: Bool = false) throws {
        // 4KB Aligned memory
        var ptr: UnsafeMutableRawPointer? = nil

        guard posix_memalign(&ptr, MemoryRegion.pageSize, Int(size)) == 0, ptr != nil else {
            throw VMError.memoryAllocationFailure
        }
        pointer = ptr!
        self.readOnly = readOnly

        let flags = readOnly ? MemoryRegion.KVM_MEM_READONLY : 0

        kvmRegion = kvm_userspace_memory_region(slot: UInt32(slot), flags: UInt32(flags),
                                             guest_phys_addr: address,
                                             memory_size: UInt64(size),
                                             userspace_addr: UInt64(UInt(bitPattern: ptr)))
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
        var output = "\(hexNum(offset + idx, width: 5)): "
        for byte in buffer {
            output += hexNum(byte, width: 2)
            output += " "
            idx += 1
            if idx == count { break }
            if idx.isMultiple(of: 16) {
                output += "\n\(hexNum(offset + idx, width: 5)): "
            }
        }
        return output
    }
}
