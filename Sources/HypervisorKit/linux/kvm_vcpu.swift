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
        while true {
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
            guard let exitReason = try self.vmExit() else { continue }
            return exitReason
        }
    }
}

#endif
