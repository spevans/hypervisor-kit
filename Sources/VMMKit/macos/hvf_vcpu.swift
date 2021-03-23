//
//  hvf_vcpu.swift
//  VMMKit
//
//  Created by Simon Evans on 08/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

#if os(macOS)

import Hypervisor
import Foundation


extension VirtualMachine {
    public final class VCPU: VCPUProtocol {

        private let vcpuId: hv_vcpuid_t
        internal let vmcs: VMCS
        private let lock = NSLock()
        internal let semaphore = DispatchSemaphore(value: 0)
        private var pendingInterrupt: VMCS.VMEntryInterruptionInfoField?
        private var exitCount: UInt64 = 0

        internal var dataRead: VMExit.DataRead?
        private var dataWrite: VMExit.DataWrite?

        private var _shutdownRequested = false
        internal var shutdownRequested: Bool {
            get { lock.performLocked { _shutdownRequested } }
            set { lock.performLocked { _shutdownRequested = newValue } }
        }

        private var _status: VCPUStatus = .setup
        internal var status: VCPUStatus {
            get { lock.performLocked { _status } }
            set { lock.performLocked { _status = newValue } }
        }

        public unowned let vm: VirtualMachine
        public let registers: Registers
        public var vmExitHandler: ((VirtualMachine.VCPU, VMExit) throws -> Bool) = { _, _ in true }
        public var completionHandler: (() -> ())?


        init(vm: VirtualMachine) throws {
            self.vm = vm
            var _vcpuId: hv_vcpuid_t = 0
            try hvError(hv_vcpu_create(&_vcpuId, UInt64(HV_VCPU_DEFAULT)))
            self.vcpuId = _vcpuId
            vmcs = VMCS(vcpu: vcpuId)

            let VMCS_PRI_PROC_BASED_CTLS_HLT       = UInt64(1 << 7)
            let VMCS_PRI_PROC_BASED_CTLS_CR8_LOAD  = UInt64(1 << 19)
            let VMCS_PRI_PROC_BASED_CTLS_CR8_STORE = UInt64(1 << 20)

            func cap2ctrl(_ cap: UInt64, _ ctrl: UInt64) -> UInt64 {
                return (ctrl | (cap & 0xffffffff)) & (cap >> 32)
            }
            try vmcs.pinBasedVMExecControls(UInt32(truncatingIfNeeded: cap2ctrl(VirtualMachine.vmx_cap_pinbased, 0)))

            try vmcs.primaryProcVMExecControls(UInt32(truncatingIfNeeded: cap2ctrl(VirtualMachine.vmx_cap_procbased,
                                                                                    VMCS_PRI_PROC_BASED_CTLS_HLT |
                                                                                    VMCS_PRI_PROC_BASED_CTLS_CR8_LOAD |
                                                                                    VMCS_PRI_PROC_BASED_CTLS_CR8_STORE)))
            try vmcs.secondaryProcVMExecControls(UInt32(truncatingIfNeeded: cap2ctrl(VirtualMachine.vmx_cap_procbased2, 0)))
            try vmcs.vmEntryControls(UInt32(truncatingIfNeeded: cap2ctrl(VirtualMachine.vmx_cap_entry, 0)))

            try vmcs.guestActivityState(.active)
            try vmcs.vmEntryInterruptInfo(VMCS.VMEntryInterruptionInfoField(0))
            try vmcs.guestInterruptibilityState(VMCS.InterruptibilityState(0))
            try vmcs.exceptionBitmap(0xffffffff)
            try vmcs.cr0mask(0x60000000)
            try vmcs.cr0ReadShadow(CPU.CR0Register(0))
            try vmcs.cr4mask(0)
            try vmcs.cr4ReadShadow(CPU.CR4Register(0))
            registers = Registers(registerCacheControl: RegisterCacheControl(vcpuId: vcpuId, vmcs: vmcs))
        }

        /// readRegisters(registerSet:) must be called for a specific register before reading that register so that it can be loaded
        /// from the vCPU. It is not required before writing to a full width register (eg RAX) but writing to a narrower register (EAX, AX, AH, AL)
        /// does require it to be read first.
        public func readRegisters(_ registerSet: RegisterSet) throws -> Registers {
            try registers.registerCacheControl.readRegisters(registerSet)
            return registers
        }

        // This runs in its own thread created in VirtualMachine.addVCPU()
        internal func runVCPU() {
            semaphore.wait()
            status = .running
            // Shutdown might be requested before the vCPU is run, if so never enter the loop
            var finished = shutdownRequested

            while !finished {
                do {
                    let vmExit = try self.runOnce()
                    status = .vmExit
                    finished = try vmExitHandler(self, vmExit)
                    if !finished {
                        finished = shutdownRequested
                    }
                } catch {
                    vm.logger.error("runVCPU failed with \(error)")
                    finished = true
                }
            }
            status = .shuttingDown
            do {
                // Get a final copy of the CPU registers
                try registers.registerCacheControl.readRegisters(.all)
                registers.registerCacheControl.makeReadOnly()
            } catch {
                vm.logger.error("Cannont read vCPU registers: \(error)")
            }
            do {
                try hvError(hv_vcpu_destroy(vcpuId))
            } catch {
                vm.logger.error("Error shutting down vCPU \(vcpuId): \(error)")
            }
            status = .shutdown
            if let handler = completionHandler {
                handler()
            }
            Thread.exit()
        }


        // This must be run on the vcpu's thread
        internal func preflightCheck() throws {
            try registers.registerCacheControl.setupRegisters()
            try vmcs.checkFieldsAreValid()
        }


        public func start() throws {
            guard status == .waitingToStart else { throw VMError.vcpuNotWaitingToStart }
            semaphore.signal()
        }


        // FIXME, runOnce should only run once.
        private func runOnce() throws -> VMExit {

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

                if activityState == .hlt {
                    // TODO: Need to wait for an interrupt to wake up or NMI of
                    vm.logger.trace("In HLT state")
                }

                try registers.registerCacheControl.readRegisters(.rflags)
                if registers.rflags.interruptEnable {
                    if let interruptInfo = nextPendingIRQ() {
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

        public func queue(irq: UInt8) {
            vm.logger.trace("Queuing IRQ: \(irq)")
            lock.lock()
            pendingInterrupt = VMCS.VMEntryInterruptionInfoField(vector: irq, type: .external, deliverErrorCode: false)
            lock.unlock()
        }

        public func clearPendingIRQ() {
            vm.logger.trace("Clearing pending irq")
            lock.lock()
            pendingInterrupt = nil
            lock.unlock()
        }

        private func nextPendingIRQ() -> VMCS.VMEntryInterruptionInfoField? {
            lock.lock()
            defer { lock.unlock() }
            if let interruptInfo = pendingInterrupt, interruptInfo.valid {
                pendingInterrupt = nil
                return interruptInfo
            } else {
                return nil
            }
        }
    }
}

#endif
