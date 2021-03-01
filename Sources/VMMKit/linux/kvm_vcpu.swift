//
//  kvm_vcpu.swift
//  VMMKit
//
//  Created by Simon Evans on 26/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

#if os(Linux)

import CBits
import Foundation
import Dispatch


extension VirtualMachine {
    public final class VCPU: VCPUProtocol {

        private let vcpu_fd: Int32
        private let kvmRunPtr: KVM_RUN_PTR
        private let kvm_run_mmap_size: Int32

        private let lock = NSLock()
        internal let semaphore = DispatchSemaphore(value: 0)
        private var pendingIRQ: UInt32?

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


        init(vm: VirtualMachine, vcpu_fd: Int32) throws {
            self.vcpu_fd = vcpu_fd
            self.vm = vm

            guard let mmapSize = VirtualMachine.vcpuMmapSize else {
                vm.logger.error("Cannot vCPU mmap size")
                throw HVError.vmSubsystemFail
            }
            kvm_run_mmap_size = mmapSize

            guard let ptr = mmap(nil, Int(kvm_run_mmap_size), PROT_READ | PROT_WRITE, MAP_SHARED, vcpu_fd, 0),
                ptr != UnsafeMutableRawPointer(bitPattern: -1) else {
                    close(vcpu_fd)
                    vm.logger.error("Cannot mmap vcpu")
                    throw HVError.vmSubsystemFail
            }
            kvmRunPtr = ptr.bindMemory(to: kvm_run.self, capacity: 1)
            registers = Registers(vcpu_fd: vcpu_fd)
        }

        public func readRegisters(_ registerSet: RegisterSet) throws -> Registers {
            try registers.readRegisters(registerSet)
            return registers
        }

        // This runs in its own thread created in VirtualMachine.createVCPU()
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
                    fatalError("processVMExit failed with \(error)")
                }
            }
            status = .shuttingDown
            munmap(kvmRunPtr, Int(kvm_run_mmap_size))

            do {
                // Get a final copy of the CPU registers
                try registers.readRegisters(.all)
                registers.makeReadOnly()
            } catch {
                fatalError("Cant read CPU registers \(error)")
            }
            close(vcpu_fd)
            status = .shutdown
            if let handler = completionHandler {
                handler()
            }
            Thread.exit()
        }


        public func start() throws {
            guard status == .waitingToStart else { throw HVError.vcpuNotWaitingToStart }
            semaphore.signal()
        }


        private func runOnce() throws -> VMExit {
            try registers.setupRegisters()

            try registers.readRegisters(.rflags)
            if registers.rflags.interruptEnable {
                if let irq = nextPendingIRQ() {
                    var interrupt = kvm_interrupt(irq: irq)
                    vm.logger.trace("_IOCTL_KVM_INTERRUPT: \(interrupt)")
                    let result = ioctl3arg(vcpu_fd, _IOCTL_KVM_INTERRUPT, &interrupt)
                    switch result {
                        case 0: break
                        case -EEXIST: throw HVError.irqAlreadyQueued
                        case -EINVAL: throw HVError.irqNumberInvalid
                        case -ENXIO: throw HVError.irqAlreadyHandledByKernelPIC
                        default: fatalError("KVM_INTERRUPT returned \(result)") // Includes EFAULT for bad memory location
                    }
                }
            }

            let ret = ioctl2arg(vcpu_fd, _IOCTL_KVM_RUN)
            guard ret >= 0 else {
                throw HVError.vmRunError
            }

            // Reset the register cache
            registers.clearCache()

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

        /// Queues a hardware interrupt. irq is the interrupt number, not pin or line.
        /// IE IRQ0x0 => INT0H  IRQ0x30 => INT30H etc
        public func queue(irq: UInt8) {
            vm.logger.trace("queuing IRQ: \(irq)")
            lock.lock()
            pendingIRQ = UInt32(irq)
            lock.unlock()
        }

        public func clearPendingIRQ() {
            vm.logger.trace("Clearing pending irq")
            lock.lock()
            pendingIRQ = nil
            lock.unlock()
        }

        private func nextPendingIRQ() -> UInt32? {
            lock.lock()
            defer { lock.unlock() }
            if let irq = pendingIRQ {
                pendingIRQ = nil
                return irq
            }
            return nil
        }

    }
}

#endif
