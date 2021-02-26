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
    public final class VCPU {

        private let vcpuId: hv_vcpuid_t
        internal let vmcs: VMCS
        private let lock = NSLock()
        private let semaphore = DispatchSemaphore(value: 0)
        private var pendingInterrupt: VMCS.VMEntryInterruptionInfoField?
        private var shutdownRequested = false
        private var exitCount: UInt64 = 0

        internal var dataRead: VMExit.DataRead?
        private var dataWrite: VMExit.DataWrite?

        private var _status: VCPUStatus = .setup
        private(set) var status: VCPUStatus {
            get { lock.performLocked { _status } }
            set { lock.performLocked { _status = newValue } }
        }

        public unowned let vm: VirtualMachine
        public var registers = Registers()
        public var vmExitHandler: ((VirtualMachine.VCPU, VMExit) throws -> Bool)!
        public var completionHandler: (() -> ())? = nil


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
        }


        internal func runVCPU() {
            status = .waitingToStart
            semaphore.wait()
            status = .running
            // Shutdown might be requested before the vCPU is run, if so never enter the loop
            var finished = self.lock.performLocked { shutdownRequested }

            while !finished {
                do {
                    let vmExit = try self.runOnce()
                    status = .vmExit
                    finished = try vmExitHandler(self, vmExit)
                    if !finished {
                        finished = self.lock.performLocked { shutdownRequested }
                    }
                } catch {
                    vm.logger.error("runVCPU failed with \(error)")
                    finished = true
                }
            }
            if let handler = completionHandler {
                handler()
            }
            status = .shuttingDown
            do {
                try hvError(hv_vcpu_destroy(vcpuId))
            } catch {
                vm.logger.error("Error shutting down vCPU \(vcpuId): \(error)")
            }
            status = .shutdown
            Thread.exit()
        }


        public func start() {
            guard vmExitHandler != nil else { fatalError("vmExitHandler not set") }
            semaphore.signal()
        }


        private func runOnce() throws -> VMExit {

            if let read = dataRead {
                fatalError("Unsatisfied read \(read)")
            }

            var activityState = try vmcs.guestActivityState()
            while true {
                try registers.setupRegisters(vcpuId: vcpuId)
                try registers.setupSegmentRegisters(vmcs: vmcs)

                if activityState == .hlt {
                    // TODO: Need to wait for an interrupt to wake up or NMI of
                    vm.logger.trace("In HLT state")
                }

                if registers.rflags.interruptEnable {
                    if let interruptInfo = nextPendingIRQ() {
                        vm.logger.trace("Injecting interrupt: \(interruptInfo)")
                        try vmcs.vmEntryInterruptInfo(interruptInfo)
//                        try vmcs.vmEntryInstructionLength(0)
//                        try vmcs.vmEntryExceptionErrorCode(0)
//                        var i = try vmcs.guestInterruptibilityState()
//                        print("blockingByMovSS:", i.blockingByMovSS)
//                        print("blockingBySTI:", i.blockingBySTI)
//                        print("blockingByNMI:", i.blockingByNMI)
//                        print("blockingBySMI:", i.blockingBySMI)
//                        print("IF flag set, setting interrupt")
                        var interruptibilityState = try vmcs.guestInterruptibilityState()
                        interruptibilityState.blockingBySTI = false
                        interruptibilityState.blockingByMovSS = false
                        try vmcs.guestInterruptibilityState(interruptibilityState)
                        try vmcs.checkFieldsAreValid()
                    }
                }


                try hvError(hv_vcpu_run(vcpuId))
                try registers.readRegisters(vcpuId: vcpuId)
                try registers.readSegmentRegisters(vmcs: vmcs)

                exitCount += 1
                activityState = try vmcs.guestActivityState()
                if activityState == .shutdown { return .shutdown }
                guard let exitReason = try self.vmExit() else { continue }

                // FIXME: Determine why first vmexit is an EPT violation
                /*if exitCount == 1,
                    case let .memoryViolation(violation) = exitReason {
                    if violation.access == .instructionFetch && !violation.executable {
                        // Ignore instructionFetch on exectable memory, EPT cold start
                        // skip
                        continue
                    }
                }*/
                return exitReason
            }
        }


        public func skipInstruction() throws {
            let instrLen = try vmcs.vmExitInstructionLength()
            registers.rip += UInt64(instrLen)
        }
/*
        func readInstructionBytes() throws -> X86Instruction {

            let length = try vmcs.vmExitInstructionLength()
            let physicalAddr = UInt64(registers.cs.base) + registers.rip
            print("Reading \(length) bytes @ \(String(physicalAddr, radix: 16))")
            let instruction = try vm.readMemory(at: physicalAddr, count: Int(length))
            var decoder = Decoder(cpuMode: .realMode, bytes: instruction)
            return try decoder.decode()
        }
         */


        /// Used to satisfy the IO In read performed by the VCPU
        public func setIn(data: VMExit.DataWrite) {

            guard let read = self.dataRead else {
                fatalError("Datawrite without a valid dataRead")
            }
            guard read.bitWidth == data.bitWidth else {
                fatalError("bitwidth mismath: read.bitWidth=\(read.bitWidth) data.bitWidth=\(data.bitWidth)")
            }

            self.dataWrite = data

            switch data {
                case .byte(let value): registers.al = value
                case .word(let value): registers.ax = value
                case .dword(let value): registers.eax = value
                case .qword(let value): registers.rax = value
            }
            self.dataRead = nil
        }

        public func queue(irq: UInt8) {
            vm.logger.trace("queuing IRQ: \(irq)")
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

        public func shutdown() {
            lock.performLocked { shutdownRequested = true }
        }
    }
}


extension VirtualMachine.VCPU {
    public struct SegmentRegister {
        public var selector: UInt16 = 0
        public var base: UInt = 0
        public var limit: UInt32 = 0
        public var accessRights: UInt32 = 0
    }

    public struct Registers {

        public var cs: SegmentRegister = SegmentRegister()
        public var ss: SegmentRegister = SegmentRegister()
        public var ds: SegmentRegister = SegmentRegister()
        public var es: SegmentRegister = SegmentRegister()
        public var fs: SegmentRegister = SegmentRegister()
        public var gs: SegmentRegister = SegmentRegister()
        public var tr: SegmentRegister = SegmentRegister()
        public var ldtr: SegmentRegister = SegmentRegister()

        public var rax: UInt64 = 0
        public var rbx: UInt64 = 0
        public var rcx: UInt64 = 0
        public var rdx: UInt64 = 0
        public var rsi: UInt64 = 0
        public var rdi: UInt64 = 0
        public var rsp: UInt64 = 0
        public var rbp: UInt64 = 0
        public var r8: UInt64 = 0
        public var r9: UInt64 = 0
        public var r10: UInt64 = 0
        public var r11: UInt64 = 0
        public var r12: UInt64 = 0
        public var r13: UInt64 = 0
        public var r14: UInt64 = 0
        public var r15: UInt64 = 0
        public var rip: UInt64 = 0
        public var rflags: CPU.RFLAGS = CPU.RFLAGS()
        public var cr0: UInt64 = 0
        public var cr2: UInt64 = 0
        public var cr3: UInt64 = 0
        public var cr4: UInt64 = 0
        public var cr8: UInt64 = 0

        public var gdtrBase: UInt64 = 0
        public var gdtrLimit: UInt64 = 0
        public var idtrBase: UInt64 = 0
        public var idtrLimit: UInt64 = 0


        private func readRegister(_ vcpuId: hv_vcpuid_t, _ register: hv_x86_reg_t) throws -> UInt64 {
            var value: UInt64 = 0
            try hvError(hv_vcpu_read_register(vcpuId, register, &value))
            return value
        }

        func writeRegister(_ vcpuId: hv_vcpuid_t, _ register: hv_x86_reg_t, _ value: UInt64) throws {
            try hvError(hv_vcpu_write_register(vcpuId, register, value))
        }

        func setupRegisters(vcpuId: hv_vcpuid_t) throws {
            try writeRegister(vcpuId, HV_X86_RAX, rax)
            try writeRegister(vcpuId, HV_X86_RBX, rbx)
            try writeRegister(vcpuId, HV_X86_RCX, rcx)
            try writeRegister(vcpuId, HV_X86_RDX, rdx)
            try writeRegister(vcpuId, HV_X86_RSI, rsi)
            try writeRegister(vcpuId, HV_X86_RDI, rdi)
            try writeRegister(vcpuId, HV_X86_RSP, rsp)
            try writeRegister(vcpuId, HV_X86_RBP, rbp)
            try writeRegister(vcpuId, HV_X86_R8, r8)
            try writeRegister(vcpuId, HV_X86_R9, r9)
            try writeRegister(vcpuId, HV_X86_R10, r10)
            try writeRegister(vcpuId, HV_X86_R11, r11)
            try writeRegister(vcpuId, HV_X86_R12, r12)
            try writeRegister(vcpuId, HV_X86_R13, r13)
            try writeRegister(vcpuId, HV_X86_R14, r14)
            try writeRegister(vcpuId, HV_X86_R15, r15)
            try writeRegister(vcpuId, HV_X86_RIP, rip)
            try writeRegister(vcpuId, HV_X86_RFLAGS, rflags.rawValue)
            try writeRegister(vcpuId, HV_X86_CR0, cr0)
            try writeRegister(vcpuId, HV_X86_CR2, cr2)
            try writeRegister(vcpuId, HV_X86_CR3, cr3)
            try writeRegister(vcpuId, HV_X86_CR4, cr4)
            try writeRegister(vcpuId, HV_X86_GDT_BASE, gdtrBase)
            try writeRegister(vcpuId, HV_X86_GDT_LIMIT, gdtrLimit)
            try writeRegister(vcpuId, HV_X86_IDT_BASE, idtrBase)
            try writeRegister(vcpuId, HV_X86_IDT_LIMIT, idtrLimit)
        }

        mutating func readRegisters(vcpuId: hv_vcpuid_t) throws {
            rax = try readRegister(vcpuId, HV_X86_RAX)
            rbx = try readRegister(vcpuId, HV_X86_RBX)
            rcx = try readRegister(vcpuId, HV_X86_RCX)
            rdx = try readRegister(vcpuId, HV_X86_RDX)
            rsi = try readRegister(vcpuId, HV_X86_RSI)
            rdi = try readRegister(vcpuId, HV_X86_RDI)
            rsp = try readRegister(vcpuId, HV_X86_RSP)
            rbp = try readRegister(vcpuId, HV_X86_RBP)
            r8 = try readRegister(vcpuId, HV_X86_R8)
            r9 = try readRegister(vcpuId, HV_X86_R9)
            r10 = try readRegister(vcpuId, HV_X86_R10)
            r11 = try readRegister(vcpuId, HV_X86_R11)
            r12 = try readRegister(vcpuId, HV_X86_R12)
            r13 = try readRegister(vcpuId, HV_X86_R13)
            r14 = try readRegister(vcpuId, HV_X86_R14)
            r15 = try readRegister(vcpuId, HV_X86_R15)
            rip = try readRegister(vcpuId, HV_X86_RIP)
            rflags = CPU.RFLAGS(try readRegister(vcpuId, HV_X86_RFLAGS))
            cr0 = try readRegister(vcpuId, HV_X86_CR0)
            cr2 = try readRegister(vcpuId, HV_X86_CR2)
            cr3 = try readRegister(vcpuId, HV_X86_CR3)
            cr4 = try readRegister(vcpuId, HV_X86_CR4)
            gdtrBase = try readRegister(vcpuId, HV_X86_GDT_BASE)
            gdtrLimit = try readRegister(vcpuId, HV_X86_GDT_LIMIT)
            idtrBase = try readRegister(vcpuId, HV_X86_IDT_BASE)
            idtrLimit = try readRegister(vcpuId, HV_X86_IDT_LIMIT)
        }


        func setupSegmentRegisters(vmcs: VMCS) throws {
            try vmcs.guestCSSelector(cs.selector)
            try vmcs.guestCSBase(cs.base)
            try vmcs.guestCSLimit(cs.limit)
            try vmcs.guestCSAccessRights(cs.accessRights)

            try vmcs.guestSSSelector(ss.selector)
            try vmcs.guestSSBase(ss.base)
            try vmcs.guestSSLimit(ss.limit)
            try vmcs.guestSSAccessRights(ss.accessRights)

            try vmcs.guestDSSelector(ds.selector)
            try vmcs.guestDSBase(ds.base)
            try vmcs.guestDSLimit(ds.limit)
            try vmcs.guestDSAccessRights(ds.accessRights)

            try vmcs.guestESSelector(es.selector)
            try vmcs.guestESBase(es.base)
            try vmcs.guestESLimit(es.limit)
            try vmcs.guestESAccessRights(es.accessRights)

            try vmcs.guestFSSelector(fs.selector)
            try vmcs.guestFSBase(fs.base)
            try vmcs.guestFSLimit(fs.limit)
            try vmcs.guestFSAccessRights(fs.accessRights)

            try vmcs.guestGSSelector(gs.selector)
            try vmcs.guestGSBase(gs.base)
            try vmcs.guestGSLimit(gs.limit)
            try vmcs.guestGSAccessRights(gs.accessRights)

            try vmcs.guestTRSelector(tr.selector)
            try vmcs.guestTRBase(tr.base)
            try vmcs.guestTRLimit(tr.limit)
            try vmcs.guestTRAccessRights(tr.accessRights)

            try vmcs.guestLDTRSelector(ldtr.selector)
            try vmcs.guestLDTRBase(ldtr.base)
            try vmcs.guestLDTRLimit(ldtr.limit)
            try vmcs.guestLDTRAccessRights(ldtr.accessRights)
        }


        mutating func readSegmentRegisters(vmcs: VMCS) throws {
            cs.selector = try vmcs.guestCSSelector()
            cs.base = try vmcs.guestCSBase()
            cs.limit = try vmcs.guestCSLimit()
            cs.accessRights = try vmcs.guestCSAccessRights()

            ss.selector = try vmcs.guestSSSelector()
            ss.base = try vmcs.guestSSBase()
            ss.limit = try vmcs.guestSSLimit()
            ss.accessRights = try vmcs.guestSSAccessRights()

            ds.selector = try vmcs.guestDSSelector()
            ds.base = try vmcs.guestDSBase()
            ds.limit = try vmcs.guestDSLimit()
            ds.accessRights = try vmcs.guestDSAccessRights()

            es.selector = try vmcs.guestESSelector()
            es.base = try vmcs.guestESBase()
            es.limit = try vmcs.guestESLimit()
            es.accessRights = try vmcs.guestESAccessRights()

            fs.selector = try vmcs.guestFSSelector()
            fs.base = try vmcs.guestFSBase()
            fs.limit = try vmcs.guestFSLimit()
            fs.accessRights = try vmcs.guestFSAccessRights()

            gs.selector = try vmcs.guestGSSelector()
            gs.base = try vmcs.guestGSBase()
            gs.limit = try vmcs.guestGSLimit()
            gs.accessRights = try vmcs.guestGSAccessRights()

        }
    }
}

#endif
