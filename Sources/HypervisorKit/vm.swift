//
//  vm.swift
//  
//
//  Created by Simon Evans on 01/01/2020.
//

extension VirtualMachine {

    public func memoryRegion(containing guestAddress: PhysicalAddress) -> MemoryRegion? {
        for region in memoryRegions {
            if region.guestAddress <= guestAddress && region.guestAddress + region.size >= guestAddress {
                return region
            }
        }
        return nil
    }


    public func memory(at guestAddress: PhysicalAddress, count: UInt64) throws -> UnsafeMutableRawPointer {
        for region in memoryRegions {
            if region.guestAddress <= guestAddress && region.guestAddress + region.size >= guestAddress + count {
                let offset = guestAddress - region.guestAddress
                return region.pointer.advanced(by: Int(offset))
            }
        }
        throw HVError.invalidMemory
    }
}
