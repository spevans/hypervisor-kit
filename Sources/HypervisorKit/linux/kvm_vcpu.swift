//
//  kvm_vcpu.swift
//  HypervisorKit
//
//  Created by Simon Evans on 26/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

#if os(Linux)

@_implementationOnly import CHypervisorKit
import Foundation
import Dispatch


extension VirtualMachine.VCPU {

    // This must be run on the vcpu's thread
    internal func preflightCheck() throws {
    }


    internal func destroy() throws {
        munmap(kvmRunPtr, Int(kvm_run_mmap_size))
        close(vcpu_fd)
    }


    internal func runOnce() throws -> VMExit {
        try registers.registerCacheControl.setupRegisters()

        try registers.registerCacheControl.readRegisters(.rflags)
        if registers.rflags.interruptEnable {
            if let irq = nextPendingIRQ() {
                var interrupt = kvm_interrupt(irq: UInt32(irq))
                vm.logger.trace("_IOCTL_KVM_INTERRUPT: \(interrupt)")
                let result = ioctl3arg(vcpu_fd, _IOCTL_KVM_INTERRUPT, &interrupt)
                switch result {
                    case 0: break
                    case -EEXIST: throw VMError.irqAlreadyQueued
                    case -EINVAL: throw VMError.irqNumberInvalid
                    case -ENXIO: throw VMError.irqAlreadyHandledByKernelPIC
                    default: fatalError("KVM_INTERRUPT returned \(result)") // Includes EFAULT for bad memory location
                }
            }
        }

        let ret = ioctl2arg(vcpu_fd, _IOCTL_KVM_RUN)
        guard ret >= 0 else {
            throw VMError.kvmRunError
        }

        // Reset the register cache
        registers.registerCacheControl.clearCache()

        guard let exitReason = KVMExit(rawValue: kvmRunPtr.pointee.exit_reason) else {
            fatalError("Invalid KVM exit reason: \(kvmRunPtr.pointee.exit_reason)")
        }

        return exitReason.vmExit(kvmRunPtr: kvmRunPtr)
    }

    public func skipInstruction() throws {
        fatalError("TODO")
    }

    /// Used to satisfy the IO In read performed by the VCPU
    public func setIn(data: VMExit.DataWrite) {
        let io = kvmRunPtr.pointee.io
        let dataOffset = io.data_offset
        let bitWidth = io.size * 8
        if io.count != 1 { fatalError("IO op with count != 1") }

        guard io.direction == 0 else {  // In
            fatalError("setIn() when IO Op is an OUT")
        }

        guard data.bitWidth == bitWidth else {
            fatalError("Bitwith mismatch, have \(data.bitWidth) want \(bitWidth)")
        }

        let ptr = UnsafeMutableRawPointer(kvmRunPtr).advanced(by: Int(dataOffset))

        switch data {
            case .byte(let value): ptr.storeBytes(of: value, as: UInt8.self)
            case .word(let value): ptr.storeBytes(of: value, as: UInt16.self)
            case .dword(let value): ptr.storeBytes(of: value, as: UInt32.self)
            case .qword(let value): ptr.storeBytes(of: value, as: UInt64.self)
        }
    }
}

#endif
