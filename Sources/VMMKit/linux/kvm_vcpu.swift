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
    public final class VCPU {

        private let vcpu_fd: Int32
        private let kvmRunPtr: KVM_RUN_PTR
        private let kvm_run_mmap_size: Int32

        private let lock = NSLock()
        private let semaphore = DispatchSemaphore(value: 0)
        private var pendingIRQ: UInt32?
        private var shutdownRequested = false

        private var _status: VCPUStatus = .setup
        private(set) var status: VCPUStatus {
            get { lock.performLocked { _status } }
            set { lock.performLocked { _status = newValue } }
        }

        public unowned let vm: VirtualMachine

        private var _regs: kvm_regs? = kvm_regs()
        private var _sregs: kvm_sregs? = kvm_sregs()
        private var _registers: Registers?
        public var registers: Registers {
            get { _registers = _registers ?? Registers(vcpu: self); return _registers! }
            set { _registers = newValue }
        }
        public var vmExitHandler: ((VirtualMachine.VCPU, VMExit) throws -> Bool)!
        public var completionHandler: (() -> ())? = nil


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
                    finished = try vmExitHandler(self, vmExit)
                    if !finished {
                        finished = self.lock.performLocked { shutdownRequested }
                    }
                } catch {
                    fatalError("processVMExit failed with \(error)")
                }
            }
            if let handler = completionHandler {
                handler()
            }
            status = .shuttingDown
            munmap(kvmRunPtr, Int(kvm_run_mmap_size))

            // Get a final copy of the CPU registers
            do {
                _registers = try Registers(regs: getRegs(), sregs: getSregs())
            } catch {
                fatalError("Cant read CPU registers \(error)")
            }
            close(vcpu_fd)
            status = .shutdown
            Thread.exit()
        }


        public func start() {
            semaphore.signal()
        }


        private func runOnce() throws -> VMExit {
            try setSregs()
            try setRegs()

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

            // reset the register cache
            _sregs = nil
            _regs = nil

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

        fileprivate func getRegs() throws -> kvm_regs {
            if _regs == nil {
                var regs = kvm_regs()
                guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_REGS, &regs) >= 0 else {
                    vm.logger.error("kvm: GET_REGS failed")
                    throw HVError.getRegisters
                }
                _regs = regs
            }
            return _regs!
        }

        fileprivate func setRegs() throws {
            if var regs = _regs {
                vm.logger.trace("setRegs, rip: \(String(regs.rip, radix: 16))")
                guard ioctl3arg(vcpu_fd, _IOCTL_KVM_SET_REGS, &regs) >= 0 else {
                    vm.logger.error("kvm: SET_REGS failed")
                    throw HVError.setRegisters
                }
            }
        }

        fileprivate func getSregs() throws -> kvm_sregs {
            if _sregs == nil {
                var sregs = kvm_sregs()
                guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_SREGS, &sregs) >= 0 else {
                    let e = errno
                    vm.logger.error("kvm: GET_SREGS failed \(e)")
                    throw HVError.getRegisters
                }
                _sregs = sregs
            }
            return _sregs!
        }

        fileprivate func setSregs() throws {
            if var sregs = _sregs {
                guard ioctl3arg(vcpu_fd, _IOCTL_KVM_SET_SREGS, &sregs) >= 0 else {
                    vm.logger.error("kvm: SET_REGS failed")
                    throw HVError.setRegisters
                }
            }
        }

        func shutdown() {
            lock.performLocked { shutdownRequested = true }
        }
    }
}


extension VirtualMachine.VCPU {
    public struct SegmentRegister {
        var kvmSegment = kvm_segment()


        init(_ kvmSegment: kvm_segment) {
            self.kvmSegment = kvmSegment
        }

        public var selector: UInt16 {
            get { kvmSegment.selector }
            set { kvmSegment.selector = newValue }
        }

        public var base: UInt {
            get { UInt(kvmSegment.base) }
            set { kvmSegment.base = UInt64(newValue) }
        }

        public var limit: UInt32 {
            get { kvmSegment.limit }
            set { kvmSegment.limit = newValue }
        }

        public var accessRights: UInt32 {
            get {
                var bitArray = BitArray32(0)
                bitArray[0...3] = UInt32(kvmSegment.type)
                bitArray[4] = Int(kvmSegment.s)
                bitArray[5...6] = UInt32(kvmSegment.dpl)
                bitArray[7] = Int(kvmSegment.present)
                bitArray[8...11] = 0 // reserverd
                bitArray[12] = Int(kvmSegment.avl)
                bitArray[13] = Int(kvmSegment.l)
                bitArray[14] = Int(kvmSegment.db)
                bitArray[15] = Int(kvmSegment.g)
                bitArray[16] = 0 // usable
                return bitArray.rawValue
            }
            set {
                let bitArray = BitArray32(newValue)
                kvmSegment.type = UInt8(bitArray[0...3])
                kvmSegment.s = UInt8(bitArray[4])
                kvmSegment.dpl = UInt8(bitArray[5...6])
                kvmSegment.present = UInt8(bitArray[7])
                kvmSegment.avl = UInt8(bitArray[12])
                kvmSegment.l = UInt8(bitArray[13])
                kvmSegment.db = UInt8(bitArray[14])
                kvmSegment.g = UInt8(bitArray[15])
            }
        }
    }


    // Access to the register set. This acts as a cache of the register and segment register values
    // to avoid excess ioctl() calls to get either of the 2 sets.
    // When the vCPU has finished executing, the _registers in the vcpu object is instansiated with
    // the final register values instead of the vcpu so that the final register values can be accessed.
    public struct Registers {
        private var vcpu: VirtualMachine.VCPU?
        private var _regs: kvm_regs?
        private var _sregs: kvm_sregs?

        fileprivate init(vcpu: VirtualMachine.VCPU) {
            self.vcpu = vcpu
        }

        fileprivate init(regs: kvm_regs, sregs: kvm_sregs) {
            self._regs = regs
            self._sregs = sregs
        }

        @discardableResult
        private func getRegs() throws -> kvm_regs {
            if let vcpu = vcpu {
                return try vcpu.getRegs()
            }
            return _regs!
        }

        @discardableResult
        private func getSregs() throws -> kvm_sregs {
            if let vcpu = vcpu {
                return try vcpu.getSregs()
            }
            return _sregs!
        }


        public var cs: SegmentRegister {
            get {
                let sregs = try! getSregs()
                return SegmentRegister(sregs.cs)
            }
            set {
                try! getSregs()
                vcpu?._sregs!.cs = newValue.kvmSegment
            }
        }

        public var ds: SegmentRegister {
            get {
                let sregs = try! getSregs()
                return SegmentRegister(sregs.ds)
            }
            set {
                try! getSregs()
                vcpu?._sregs!.ds = newValue.kvmSegment
            }
        }

        public var es: SegmentRegister {
            get {
                let sregs = try! getSregs()
                return SegmentRegister(sregs.es)
            }
            set {
                try! getSregs()
                vcpu?._sregs!.es = newValue.kvmSegment
            }
        }

        public var fs: SegmentRegister {
            get {
                let sregs = try! getSregs()
                return SegmentRegister(sregs.fs)
            }
            set {
                try! getSregs()
                vcpu?._sregs!.fs = newValue.kvmSegment
            }
        }

        public var gs: SegmentRegister {
            get {
                let sregs = try! getSregs()
                return SegmentRegister(sregs.gs)
            }
            set {
                try! getSregs()
                vcpu?._sregs!.gs = newValue.kvmSegment
            }
        }

        public var ss: SegmentRegister {
            get {
                let sregs = try! getSregs()
                return SegmentRegister(sregs.ss)
            }
            set {
                try! getSregs()
                vcpu?._sregs!.ss = newValue.kvmSegment
            }
        }

        public var tr: SegmentRegister {
            get {
                let sregs = try! getSregs()
                return SegmentRegister(sregs.tr)
            }
            set {
                try! getSregs()
                vcpu?._sregs!.tr = newValue.kvmSegment
            }
        }

        public var ldtr: SegmentRegister {
            get {
                let sregs = try! getSregs()
                return SegmentRegister(sregs.ldt)
            }
            set {
                try! getSregs()
                vcpu?._sregs!.ldt = newValue.kvmSegment
            }
        }

        public var rax: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.rax
            }
            set {
                try! getRegs()
                vcpu?._regs!.rax = newValue
            }
        }

        public var rbx: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.rbx
            }
            set {
                try! getRegs()
                vcpu?._regs!.rbx = newValue
            }
        }

        public var rcx: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.rcx
            }
            set {
                try! getRegs()
                vcpu?._regs!.rcx = newValue
            }
        }

        public var rdx: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.rdx
            }
            set {
                try! getRegs()
                vcpu?._regs!.rdx = newValue
            }
        }

        public var rsi: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.rsi
            }
            set {
                try! getRegs()
                vcpu?._regs!.rsi = newValue
            }
        }

        public var rdi: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.rdi
            }
            set {
                try! getRegs()
                vcpu?._regs!.rdi = newValue
            }
        }

        public var rsp: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.rsp
            }
            set {
                try! getRegs()
                vcpu?._regs!.rsp = newValue
            }
        }

        public var rbp: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.rbp
            }
            set {
                try! getRegs()
                vcpu?._regs!.rbp = newValue
            }
        }

        public var r8: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.r8
            }
            set {
                try! getRegs()
                vcpu?._regs!.r8 = newValue
            }
        }

        public var r9: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.r9
            }
            set {
                try! getRegs()
                vcpu?._regs!.r9 = newValue
            }
        }

        public var r10: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.r10
            }
            set {
                try! getRegs()
                vcpu?._regs!.r10 = newValue
            }
        }

        public var r11: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.r11
            }
            set {
                try! getRegs()
                vcpu?._regs!.r11 = newValue
            }
        }

        public var r12: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.r12
            }
            set {
                try! getRegs()
                vcpu?._regs!.r12 = newValue
            }
        }

        public var r13: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.r13
            }
            set {
                try! getRegs()
                vcpu?._regs!.r13 = newValue
            }
        }

        public var r14: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.r14
            }
            set {
                try! getRegs()
                vcpu?._regs!.r14 = newValue
            }
        }

        public var r15: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.r15
            }
            set {
                try! getRegs()
                vcpu?._regs!.r15 = newValue
            }
        }

        public var rip: UInt64 {
            get {
                let regs = try! getRegs()
                return regs.rip
            }
            set {
                try! getRegs()
                vcpu?._regs!.rip = newValue
            }
        }

        public var rflags: CPU.RFLAGS {
            get {
                let regs = try! getRegs()
                return CPU.RFLAGS(regs.rflags)
            }
            set {
                try! getRegs()
                vcpu?._regs!.rflags = newValue.rawValue
            }
        }

        public var cr0: UInt64 {
            get {
                let sregs = try! getSregs()
                return sregs.cr0
            }
            set {
                try! getSregs()
                vcpu?._sregs!.cr0 = newValue
            }
        }

        public var cr2: UInt64 {
            get {
                let sregs = try! getSregs()
                return sregs.cr2
            }
            set {
                try! getSregs()
                vcpu?._sregs!.cr2 = newValue
            }
        }

        public var cr3: UInt64 {
            get {
                let sregs = try! getSregs()
                return sregs.cr3
            }
            set {
                try! getSregs()
                vcpu?._sregs!.cr3 = newValue
            }
        }

        public var cr4: UInt64 {
            get {
                let sregs = try! getSregs()
                return sregs.cr4
            }
            set {
                try! getSregs()
                vcpu?._sregs!.cr4 = newValue
            }
        }

        public var cr8: UInt64 {
            get {
                let sregs = try! getSregs()
                return sregs.cr8
            }
            set {
                try! getSregs()
                vcpu?._sregs!.cr8 = newValue
            }
        }

        public var efer: UInt64 {
            get {
                let sregs = try! getSregs()
                return sregs.efer
            }
            set {
                try! getSregs()
                vcpu?._sregs!.efer = newValue
            }
        }

        public var gdtrBase: UInt64 {
            get {
                let sregs = try! getSregs()
                return sregs.gdt.base
            }
            set {
                try! getSregs()
                vcpu?._sregs!.gdt.base = newValue
            }
        }

        public var gdtrLimit: UInt16 {
            get {
                let sregs = try! getSregs()
                return sregs.gdt.limit
            }
            set {
                try! getSregs()
                vcpu?._sregs!.gdt.limit = newValue
            }
        }

        public var idtrBase: UInt64 {
            get {
                let sregs = try! getSregs()
                return sregs.idt.base
            }
            set {
                try! getSregs()
                vcpu?._sregs!.idt.base = newValue
            }
        }

        public var idtrLimit: UInt16 {
            get {
                let sregs = try! getSregs()
                return sregs.idt.limit
            }
            set {
                try! getSregs()
                vcpu?._sregs!.idt.limit = newValue
            }
        }
    }
}

#endif
