//
//  hvf_vm.swift
//  VMMKit
//
//  Created by Simon Evans on 01/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

#if os(macOS)

import Hypervisor
import Logging


// Hypervisor Framework return codes
func hvError(_ error: hv_return_t) throws {
    let error = UInt32(bitPattern: error)
    switch error {
        case 0: return  // HV_SUCCESS
        case 0xfae94001: throw VMError.hvError
        case 0xfae94002: throw VMError.hvBusy
        case 0xfae94003: throw VMError.hvBadArgument
        case 0xfae94005: throw VMError.hvNoResources
        case 0xfae94006: throw VMError.hvNoDevice
        case 0xfae94007: throw VMError.hvDenied
        case 0xfae9400f: throw VMError.hvUnsupported
        default:         throw VMError.hvUnknownError(error)
    }
}


extension VirtualMachine {

    static private(set) var vmx_cap_pinbased: UInt64 = 0
    static private(set) var vmx_cap_procbased: UInt64 = 0
    static private(set) var vmx_cap_procbased2: UInt64 = 0
    static private(set) var vmx_cap_entry: UInt64 = 0
    static private(set) var vmx_cap_exit: UInt64 = 0


    internal func _createVM() throws {

        func printCap(_ name: String, _ value: UInt64) {
            let hi = String(UInt32(value >> 32), radix: 16)
            let lo = String(UInt32(value & 0xffff_ffff), radix: 16)
            logger.debug("\(name): \(hi)\t\(lo)")
        }

        var vmCreated = false
        do {
            try hvError(hv_vm_create(hv_vm_options_t(HV_VM_DEFAULT)))
            vmCreated = true
            /* get hypervisor enforced capabilities of the machine, (see Intel docs) */
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_PINBASED, &VirtualMachine.vmx_cap_pinbased))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_PROCBASED, &VirtualMachine.vmx_cap_procbased))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_PROCBASED2, &VirtualMachine.vmx_cap_procbased2))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_ENTRY, &VirtualMachine.vmx_cap_entry))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_EXIT, &VirtualMachine.vmx_cap_exit))
        } catch {
            if vmCreated {
                hv_vm_destroy()
            }
            throw error
        }
    }


    internal func _shutdownVM() throws {
        try hvError(hv_vm_destroy())
    }


    internal func _createMemory(at guestAddress: UInt64, size: UInt64, readOnly: Bool) throws -> MemoryRegion {
        return try MemoryRegion(size: size, at: guestAddress, readOnly: readOnly)
    }

    internal func _destroyMemory(region: MemoryRegion) throws {
        try hvError(hv_vm_unmap(region.guestAddress.rawValue, Int(region.size)))
    }


    /// This runs inside its own thread.
    internal func _createVCPU() throws -> VCPU {
        try VCPU.init(vm: self)
    }

}

#endif
