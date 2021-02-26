//
//  hvf_vm.swift
//  VMMKit
//
//  Created by Simon Evans on 01/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

#if os(macOS)

import Hypervisor
import Foundation
import Dispatch
import Logging


enum HVError: Error {
    case hvError
    case hvBusy
    case hvBadArgument
    case hvNoResources
    case hvNoDevice
    case hvDenied
    case hvUnsupported
    case hvUnknownError(UInt32)
    case noMemory
    case vmRunError
    case invalidMemory
    case vcpuNotWaitingToStart
    case vcpusStillRunning
}

// Hypervisor Framework return codes
func hvError(_ error: hv_return_t) throws {
    let error = UInt32(bitPattern: error)
    switch error {
        case 0: return  // HV_SUCCESS
        case 0xfae94001: throw HVError.hvError
        case 0xfae94002: throw HVError.hvBusy
        case 0xfae94003: throw HVError.hvBadArgument
        case 0xfae94005: throw HVError.hvNoResources
        case 0xfae94006: throw HVError.hvNoDevice
        case 0xfae94007: throw HVError.hvDenied
        case 0xfae9400f: throw HVError.hvUnsupported
        default:         throw HVError.hvUnknownError(error)
    }
}


public final class VirtualMachine {

    static private(set) var vmx_cap_pinbased: UInt64 = 0
    static private(set) var vmx_cap_procbased: UInt64 = 0
    static private(set) var vmx_cap_procbased2: UInt64 = 0
    static private(set) var vmx_cap_entry: UInt64 = 0
    static private(set) var vmx_cap_exit: UInt64 = 0

    private var _shutdown = false
    internal let logger: Logger
    public private(set) var vcpus: [VCPU] = []
    public private(set) var memoryRegions: [MemoryRegion] = []


    public init(logger: Logger) throws {

        self.logger = logger
        func printCap(_ name: String, _ value: UInt64) {
            let hi = String(UInt32(value >> 32), radix: 16)
            let lo = String(UInt32(value & 0xffff_ffff), radix: 16)
            logger.debug("\(name): \(hi)\t\(lo)")
        }

        do {
            try hvError(hv_vm_create(hv_vm_options_t(HV_VM_DEFAULT)))
            logger.debug("VM Created")
            /* get hypervisor enforced capabilities of the machine, (see Intel docs) */
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_PINBASED, &VirtualMachine.vmx_cap_pinbased))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_PROCBASED, &VirtualMachine.vmx_cap_procbased))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_PROCBASED2, &VirtualMachine.vmx_cap_procbased2))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_ENTRY, &VirtualMachine.vmx_cap_entry))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_EXIT, &VirtualMachine.vmx_cap_exit))
        } catch {
            throw error
        }
    }


    deinit {
        guard _shutdown == true else {
            fatalError("VM has not been shutdown().")
        }
    }


    public func shutdown() throws {
        logger.info("Shutting down VM - deinit")
        precondition(_shutdown == false)
        guard allVcpusShutdown() else {
            throw HVError.vcpusStillRunning
        }
        vcpus = []

        while let memory = memoryRegions.last {
            try hvError(hv_vm_unmap(memory.guestAddress.rawValue, Int(memory.size)))
            memoryRegions.removeLast()
        }

        try hvError(hv_vm_destroy())
        _shutdown = true
    }


    public func addMemory(at guestAddress: UInt64, size: UInt64, readOnly: Bool = false) throws -> MemoryRegion {
        logger.info("Adding \(size) bytes at address 0x\(String(guestAddress, radix: 16))")
        precondition(guestAddress & 0xfff == 0)
        precondition(size & 0xfff == 0)

        let memRegion = try MemoryRegion(size: size, at: guestAddress, readOnly: readOnly)
        memoryRegions.append(memRegion)
        return memRegion
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


    @discardableResult
    public func createVCPU(startup: @escaping (VCPU) -> ()) throws -> VCPU {

        var vcpu: VCPU? = nil
        var createError: Error? = nil
        let semaphore = DispatchSemaphore(value: 0)

        let thread = Thread {
            do {
                let _vcpu = try VCPU.init(vm: self)
                vcpu = _vcpu
                startup(_vcpu)
                try _vcpu.preflightCheck()
                _vcpu.status = .waitingToStart
                semaphore.signal()
                _vcpu.runVCPU()
            } catch {
                createError = error
                return
            }
        }
        thread.start()
        semaphore.wait()
        if let error = createError { throw error }
        vcpus.append(vcpu!)
        return vcpu!
    }

}

#endif
