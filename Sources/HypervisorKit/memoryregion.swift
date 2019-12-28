//
//  memoryregion.swift
//
//
//  Created by Simon Evans on 27/12/2019.
//

import Foundation

#if os(macOS)
import Hypervisor
#endif

import CBits


enum HVKError: Error {
    case memoryError
}

public final class MemoryRegion {

    internal let pointer: UnsafeMutableRawPointer

#if os(macOS)

    let guestAddress: PhysicalAddress
    let size: UInt64
    var rawBuffer: UnsafeMutableRawBufferPointer { UnsafeMutableRawBufferPointer(start: pointer, count: Int(size)) }

    init?(size: UInt64, at address: RawAddress) {
        // 4KB Aligned memory
        guard let ram = valloc(Int(size)) else { return nil }
        print("Allocated \(size) bytes @ \(String(UInt(bitPattern: ram), radix: 16))")
        ram.initializeMemory(as: UInt8.self, repeating: 0, count: Int(size))
        pointer = ram
        let flags = hv_memory_flags_t(HV_MEMORY_READ | HV_MEMORY_WRITE | HV_MEMORY_EXEC)
        do {
            print("Mapping ram size: \(String(size, radix: 16)) @ \(String(address, radix: 16))")
            try hvError(hv_vm_map(ram, address, Int(size), flags))
        } catch {
            return nil
        }
        guestAddress = PhysicalAddress(address)
        self.size = size

    }

    deinit {
        free(pointer)
    }

#elseif os(Linux)
    internal let region: kvm_userspace_memory_region

    var guestAddress: PhysicalAddress { PhysicalAddress(region.guest_phys_addr) }
    var size: UInt64 { region.memory_size }
    var rawBuffer: UnsafeMutableRawBufferPointer { UnsafeMutableRawBufferPointer(start: pointer, count: Int(region.memory_size)) }


    init?(size: UInt64, at address: UInt64, slot: Int) {
        guard let ptr = mmap(nil, Int(size), PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE, -1, 0),
            ptr != UnsafeMutableRawPointer(bitPattern: -1) else {
                return nil
        }
        pointer = ptr

        region = kvm_userspace_memory_region(slot: UInt32(slot), flags: 0,
                                             guest_phys_addr: address,
                                             memory_size: UInt64(size),
                                             userspace_addr: UInt64(UInt(bitPattern: ptr)))
    }

    deinit {
        munmap(pointer, Int(region.memory_size))
    }

#endif

    public func loadBinary(from binary: Data, atOffset offset: UInt64 = 0) throws {
        guard binary.count <= size - offset else { throw HVKError.memoryError }
        let buffer = UnsafeMutableRawBufferPointer(start: pointer.advanced(by: Int(offset)), count: binary.count)
        binary.copyBytes(to: buffer)
    }
}
