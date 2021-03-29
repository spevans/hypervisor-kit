//
//  vcpu.swift
//  HypervisorKit
//
//  Created by Simon Evans on 27/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import Foundation

#if os(macOS)
import Hypervisor
#elseif os(Linux)
@_implementationOnly import CHypervisorKit
#endif

/// A Type defining the VMExitHandler.
public typealias VMExitHandler = ((VirtualMachine.VCPU, VMExit) throws -> Bool)

enum VCPUStatus {
    case setup
    case waitingToStart
    case running
    case vmExit
    case shuttingDown
    case shutdown
}


extension VirtualMachine {
    public final class VCPU {

#if os(macOS)
        internal let vcpuId: hv_vcpuid_t
        internal let vmcs: VMCS
        internal var dataRead: VMExit.DataRead?
        internal var dataWrite: VMExit.DataWrite?
        internal var exitCount: UInt64 = 0
#elseif os(Linux)
        internal let vcpu_fd: Int32
        internal let kvmRunPtr: KVM_RUN_PTR
        internal let kvm_run_mmap_size: Int32
#endif
        internal unowned let vm: VirtualMachine

        private let lock = NSLock()
        private var pendingIRQ: UInt8?
        internal let semaphore = DispatchSemaphore(value: 0)

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

        /// The register values in the vCPU. Before reading register values, they must
        /// be read from the vCPU using `readRegisters()`.
        public let registers: Registers
        /// The handler that is called on every VM exit.
        public var vmExitHandler: VMExitHandler = { _, _ in true }
        /// The handler that is called when the vCPU has finished running and is being shutdown.
        public var completionHandler: (() -> ())?

#if os(macOS)
        internal init(vm: VirtualMachine) throws {
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
#elseif os(Linux)

        internal init(vm: VirtualMachine, vcpu_fd: Int32) throws {
            self.vcpu_fd = vcpu_fd
            self.vm = vm

            guard let mmapSize = VirtualMachine.vcpuMmapSize else {
                vm.logger.error("Cannot vCPU mmap size")
                throw VMError.kvmCannotGetVcpuSize
            }
            kvm_run_mmap_size = mmapSize

            guard let ptr = mmap(nil, Int(kvm_run_mmap_size), PROT_READ | PROT_WRITE, MAP_SHARED, vcpu_fd, 0),
                  ptr != UnsafeMutableRawPointer(bitPattern: -1) else {
                close(vcpu_fd)
                vm.logger.error("Cannot mmap vcpu")
                throw VMError.kvmCannotMmapVcpu
            }
            kvmRunPtr = ptr.bindMemory(to: kvm_run.self, capacity: 1)
            registers = Registers(registerCacheControl: RegisterCacheControl(vcpu_fd: vcpu_fd))
        }
#endif

        /// Cache selected registers from the vCPU.
        /// ```
        /// When the vCPU has exited, the register values need to copied from the underlying VMCS.
        /// This is an expensive operation so instead of copying all of the registers, selected registers
        /// can be read and the values cached.
        /// More registers can be read in a further call however any registers that were already read will
        /// not be read again.
        /// It is not required before writing to a full width register (eg RAX) but writing to a narrower
        /// register (EAX, AX, AH, AL)
        ///
        /// Usage:
        /// let registers = vcpu.readRegisters([.rip, .rax])
        /// let rip = registers.rip
        /// let rbx = registers.rbx         // Error, RBX not read
        /// vcpu.readRegisters([.rax, rbx]) // RBX now read in, RAX not read in again
        /// vcpu.rsi = 1                    // .rsi is a full register write
        /// vcpu.al = 2                     // OK, RAX already read in
        /// vcpu.cx = 3                     // Error, RCX needs to be read first.
        /// ```
        /// - parameters registerSet: The `RegisterSet` containing the registers to read from the vCPU.
        /// - throws: `VMError.vcpuReadRegisterFailed` if an error occured reading the registers from the vCPU.
        public func readRegisters(_ registerSet: RegisterSet) throws -> Registers {
            do {
                try registers.registerCacheControl.readRegisters(registerSet)
                return registers
            } catch {
                vm.logger.debug("Error reading registers from vCPU: \(error)")
                throw VMError.vcpuReadRegisterFailed
            }
        }

        /// Signal the vCPU to start running.
        /// ```
        /// After a vCPU is created, it is in a suspended state until it is started. This can only be
        /// called once. After it has been started, the next call will be to `shutdown()`.
        /// ```
        /// - throws: `VMError.vcpuNotWaitingToStart` if the vCPU is not in the suspended state.
        public func start() throws {
            guard status == .waitingToStart else { throw VMError.vcpuNotWaitingToStart }
            semaphore.signal()
        }

        /// Shutdown the vCPU.
        /// ```
        /// The vCPU is signaled to shutdown. When it next exits the vCPU will not re-enter its runloop
        /// but will exit the loop instead. After signalling the vCPU, the state will be checked for the
        /// next 100ms to check if it has exited.
        /// ```
        /// - returns: `true` if the vCPU has been sucessfully shutdown, `false` otherwise.
        public func shutdown() -> Bool {
            if status == .shutdown { return true }
            shutdownRequested = true
            let currentStatus = self.status
            if currentStatus == .setup || currentStatus == .waitingToStart {
                // Tell the thread to wakeup so that it can immediately exit.
                self.semaphore.signal()
            }
            for _ in 1...100 {
                if status == .shutdown { return true }
                Thread.sleep(forTimeInterval: 0.001) // 1ms
            }
            return status == .shutdown
        }

        /// Queues a hardware interrupt.
        /// ```
        /// The IRQ is injected into the VM on the next VM emtry. The IRQ is specified as the
        /// software interrupt that would be run. eg the timer is usually connected to IRQ0 on the PIC.
        /// and by default IRQ0 will invoke INT8. So queue this interrupt the IRQ would be specified as 8 NOT 0.
        /// ```
        /// - parameter irq:The pending IRQ to queue.
        public func queue(irq: UInt8) {
            vm.logger.trace("queuing IRQ: \(irq)")
            lock.performLocked { pendingIRQ = irq }
        }

        /// Clears any IRQ that is pending.
        public func clearPendingIRQ() {
            vm.logger.trace("Clearing pending irq")
            lock.performLocked { pendingIRQ = nil }
        }

        internal func nextPendingIRQ() -> UInt8? {
            return lock.performLocked {
                defer { pendingIRQ = nil }
                return pendingIRQ
            }
        }

        // Set the initial vCPU register values for Real mode.
        internal func setupRealMode() {
            vm.logger.debug("setupRealMode()")
            vm.logger.debug("setupRealMode(), registers: \(registers)")
            registers.cr0 = CPU.CR0Register(0x60000030).value
            registers.cr2 = 0
            registers.cr3 = CPU.CR3Register(0).value
            registers.cr4 = CPU.CR4Register(0x2000).value

            registers.rip = 0xFFF0
            registers.rflags = CPU.RFLAGS(2)
            registers.rsp = 0x0
            registers.rax = 0x0

            registers.cs = SegmentRegister(selector: 0xf000, base: 0xf0000, limit: 0xffff, accessRights: 0x9b)
            registers.ds = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0xffff, accessRights: 0x93)

            registers.es = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0xffff, accessRights: 0x93)
            registers.fs = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0xffff, accessRights: 0x93)
            registers.gs = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0xffff, accessRights: 0x93)
            registers.ss = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0xffff, accessRights: 0x93)

            registers.taskRegister = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0x0000, accessRights: 0x83)
            registers.ldtr = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0x0000, accessRights: 0x10000)

            registers.gdt = DescriptorTable(base: 0, limit: 0xffff)
            registers.idt = DescriptorTable(base: 0, limit: 0xffff)
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
                    finished = try vmExitHandler(self, vmExit)
                    if !finished {
                        finished = shutdownRequested
                    }
                } catch {
                    vm.logger.error("processVMExit failed with \(error)")
                }
            }
            status = .shuttingDown

            do {
                // Get a final copy of the CPU registers
                try registers.registerCacheControl.readRegisters(.all)
                registers.registerCacheControl.makeReadOnly()
            } catch {
                vm.logger.error("Cant read CPU registers \(error)")
            }

            do {
                try destroy()
            } catch {
                vm.logger.error("Error shutting down vCPU: \(error)")
            }

            status = .shutdown
            if let handler = completionHandler {
                handler()
            }
            Thread.exit()
        }
    }
}
