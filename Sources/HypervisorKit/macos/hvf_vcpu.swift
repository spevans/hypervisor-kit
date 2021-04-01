//
//  hvf_vcpu.swift
//  HypervisorKit
//
//  Created by Simon Evans on 08/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

#if os(macOS)

import Hypervisor
import Foundation

extension VirtualMachine.VCPU {

    // This must be run on the vcpu's thread. It is run after the vCPU has been setup but before
    // being run for the first time.
    internal func preflightCheck() throws {
        try registers.registerCacheControl.setupRegisters()
        try vmcs.checkFieldsAreValid()
    }

    internal func destroy() throws {
        try hvError(hv_vcpu_destroy(vcpuId))
    }

    // FIXME, runOnce should only run once.
    internal func runOnce() throws -> VMExit {

        if let read = dataRead {
            guard let write = dataWrite else {
                fatalError("Unsatisfied read \(read)")
            }
            try registers.registerCacheControl.readRegisters(.rax)
            switch write {
                case .byte(let value): registers.al = value
                case .word(let value): registers.ax = value
                case .dword(let value): registers.eax = value
                case .qword(let value): registers.rax = value
            }
            self.dataRead = nil
            self.dataWrite = nil
        }

        var activityState = try vmcs.guestActivityState()
        while true {
            try registers.registerCacheControl.setupRegisters()

            try registers.registerCacheControl.readRegisters(.rflags)
            if registers.rflags.interruptEnable {
                if hltState {
                    // TODO, better check for NMI/IRQ and STI
                    vm.logger.trace("In HLT state waiting for IRQ")
                    waitForPendingIRQ()
                    vm.logger.trace("IRQ is not pending")
                    hltState = false
                }
                if let irq = nextPendingIRQ() {
                    let interruptInfo = VMCS.VMEntryInterruptionInfoField(vector: irq, type: .external, deliverErrorCode: false)
                    vm.logger.trace("Injecting interrupt: \(interruptInfo)")
                    try vmcs.vmEntryInterruptInfo(interruptInfo)
                    var interruptibilityState = try vmcs.guestInterruptibilityState()
                    interruptibilityState.blockingBySTI = false
                    interruptibilityState.blockingByMovSS = false
                    try vmcs.guestInterruptibilityState(interruptibilityState)
                    try vmcs.checkFieldsAreValid()
                }
            }

            try hvError(hv_vcpu_run(vcpuId))
            // Reset the register cache
            registers.registerCacheControl.clearCache()

            exitCount += 1
            activityState = try vmcs.guestActivityState()
            if activityState == .shutdown { return .shutdown }
            guard let exitReason = try self.vmExit() else { continue }
            return exitReason
        }
    }


    public func skipInstruction() throws {
        let instrLen = try vmcs.vmExitInstructionLength()
        try registers.registerCacheControl.readRegisters(.rip)
        registers.rip += UInt64(instrLen)
    }


    /// Used to satisfy the IO In read performed by the VCPU
    public func setIn(data: VMExit.DataWrite) {
        guard let read = self.dataRead else {
            fatalError("Datawrite without a valid dataRead")
        }
        guard read.bitWidth == data.bitWidth else {
            fatalError("bitwidth mismath: read.bitWidth=\(read.bitWidth) data.bitWidth=\(data.bitWidth)")
        }
        self.dataWrite = data
    }
}

#endif
