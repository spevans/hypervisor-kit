//
//  vm.swift
//  
//
//  Created by Simon Evans on 01/12/2019.
//

#if os(macOS)

import Hypervisor

enum HVError: Error {
    case error(hv_return_t)
    case noMemory
    case vmRunError
    case invalidMemory
}

func hvError(_ error: hv_return_t) throws {
    guard error == HV_SUCCESS else {
        throw HVError.error(error)
    }
}


public final class VirtualMachine {

    static private(set) var vmx_cap_pinbased: UInt64 = 0
    static private(set) var vmx_cap_procbased: UInt64 = 0
    static private(set) var vmx_cap_procbased2: UInt64 = 0
    static private(set) var vmx_cap_entry: UInt64 = 0

    public private(set) var vcpus: [VCPU] = []
    public private(set) var memoryRegions: [MemoryRegion] = []
    
    
    public init() throws {
        func printCap(_ name: String, _ value: UInt64) {
            let hi = String(UInt32(value >> 32), radix: 16)
            let lo = String(UInt32(value & 0xffff_ffff), radix: 16)
            print("\(name): \(hi)\t\(lo)")
        }
        
        do {
            try hvError(hv_vm_create(hv_vm_options_t(HV_VM_DEFAULT)))
            print("VM Created")
            /* get hypervisor enforced capabilities of the machine, (see Intel docs) */
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_PINBASED, &VirtualMachine.vmx_cap_pinbased))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_PROCBASED, &VirtualMachine.vmx_cap_procbased))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_PROCBASED2, &VirtualMachine.vmx_cap_procbased2))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_ENTRY, &VirtualMachine.vmx_cap_entry))
        } catch {
            throw error
        }
    }
    
    public func addMemory(at guestAddress: UInt64, size: UInt64, readOnly: Bool = false) throws -> MemoryRegion {
        precondition(guestAddress & 0xfff == 0)
        precondition(size & 0xfff == 0)

        let memRegion = try MemoryRegion(size: size, at: guestAddress, readOnly: readOnly)
        memoryRegions.append(memRegion)
        return memRegion
    }

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

/*
    func readMemory(at guestAddress: PhysicalAddress, count: Int) throws -> [UInt8] {
        for region in memoryRegions {
            if region.guestAddress <= guestAddress && region.guestAddress + region.size >= guestAddress + count {
                let offset = guestAddress - region.guestAddress
                let ptr = region.pointer.advanced(by: Int(offset))
                let buffer = UnsafeRawBufferPointer(start: ptr, count: count)
                return Array<UInt8>(buffer)
            }
        }
        throw HVError.invalidMemory
    }
  */
    public func createVCPU() throws -> VCPU {
        let vcpu = try VCPU.init(vm: self)
        vcpus.append(vcpu)
        return vcpu
    }
    
    deinit {
        do {
            while let vcpu = vcpus.first {
                try vcpu.shutdown()
                vcpus.remove(at: 0)
            }
            
            while let memory = memoryRegions.first {
                try hvError(hv_vm_unmap(memory.guestAddress.rawValue, Int(memory.size)))
                memoryRegions.remove(at: 0)
            }
            
            try hvError(hv_vm_destroy())
        } catch {
            fatalError("Error shutting down \(error)")
        }
    }
}

#endif
