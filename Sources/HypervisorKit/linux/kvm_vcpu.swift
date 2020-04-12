//
//  kvm_vcpu.swift
//
//
//  Created by Simon Evans on 26/12/2019.
//

#if os(Linux)

import CBits
import Foundation
import Dispatch


extension VirtualMachine {
    public final class VCPU {

        public struct SegmentRegister {
            var kvmSegment = kvm_segment()

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
                    print("Addess rights: ")
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


        public struct Registers {
            fileprivate var regs = kvm_regs()
            fileprivate var sregs = kvm_sregs()

            public var cs = SegmentRegister()
            public var ss = SegmentRegister()
            public var ds = SegmentRegister()
            public var es = SegmentRegister()
            public var fs = SegmentRegister()
            public var gs = SegmentRegister()
            public var tr = SegmentRegister()
            public var ldtr = SegmentRegister()


            init(regs: kvm_regs, sregs: kvm_sregs) {
                self.regs = regs
                self.sregs = sregs
                self.cs = SegmentRegister(kvmSegment: sregs.cs)
                self.ss = SegmentRegister(kvmSegment: sregs.ss)
                self.ds = SegmentRegister(kvmSegment: sregs.ds)
                self.es = SegmentRegister(kvmSegment: sregs.es)
                self.fs = SegmentRegister(kvmSegment: sregs.fs)
                self.gs = SegmentRegister(kvmSegment: sregs.gs)
                self.tr = SegmentRegister(kvmSegment: sregs.tr)
                self.ldtr = SegmentRegister(kvmSegment: sregs.ldt)
            }

            init() {
            }


            mutating func updateSRegs() {
                sregs.cs = cs.kvmSegment
                sregs.ds = ds.kvmSegment
                sregs.es = es.kvmSegment
                sregs.fs = fs.kvmSegment
                sregs.gs = gs.kvmSegment
                sregs.ss = ss.kvmSegment
                sregs.tr = tr.kvmSegment
            }

            mutating func readSRegs() {
                cs.kvmSegment = sregs.cs
                ds.kvmSegment = sregs.ds
                es.kvmSegment = sregs.es
                fs.kvmSegment = sregs.fs
                gs.kvmSegment = sregs.gs
                ss.kvmSegment = sregs.ss

            }

            public var rax: UInt64 {
                get { regs.rax }
                set { regs.rax = newValue }
            }

            public var rbx: UInt64 {
                get { regs.rbx }
                set { regs.rbx = newValue }
            }

            public var rcx: UInt64 {
                get { regs.rcx }
                set { regs.rcx = newValue }
            }

            public var rdx: UInt64 {
                get { regs.rdx }
                set { regs.rdx = newValue }
            }

            public var rsi: UInt64 {
                get { regs.rsi }
                set { regs.rsi = newValue }
            }

            public var rdi: UInt64 {
                get { regs.rdi }
                set { regs.rdi = newValue }
            }

            public var rsp: UInt64 {
                get { regs.rsp }
                set { regs.rsp = newValue }
            }

            public var rbp: UInt64 {
                get { regs.rbp }
                set { regs.rbp = newValue }
            }

            public var r8: UInt64 {
                get { regs.r8 }
                set { regs.r8 = newValue }
            }

            public var r9: UInt64 {
                get { regs.r9 }
                set { regs.r9 = newValue }
            }

            public var r10: UInt64 {
                get { regs.r10 }
                set { regs.r10 = newValue }
            }

            public var r11: UInt64 {
                get { regs.r11 }
                set { regs.r11 = newValue }
            }

            public var r12: UInt64 {
                get { regs.r12 }
                set { regs.r12 = newValue }
            }

            public var r13: UInt64 {
                get { regs.r13 }
                set { regs.r13 = newValue }
            }

            public var r14: UInt64 {
                get { regs.r14 }
                set { regs.r14 = newValue }
            }

            public var r15: UInt64 {
                get { regs.r15 }
                set { regs.r15 = newValue }
            }

            public var rip: UInt64 {
                get { regs.rip }
                set { regs.rip = newValue }
            }

            public var rflags: CPU.RFLAGS {
                get { CPU.RFLAGS(regs.rflags) }
                set { regs.rflags = newValue.rawValue }
            }

            public var cr0: UInt64 {
                get { sregs.cr0 }
                set { sregs.cr0 = newValue }
            }

            public var cr2: UInt64 {
                get { sregs.cr2 }
                set { sregs.cr2 = newValue }
            }

            public var cr3: UInt64 {
                get { sregs.cr3 }
                set { sregs.cr3 = newValue }
            }

            public var cr4: UInt64 {
                get { sregs.cr4 }
                set { sregs.cr4 = newValue }
            }

            public var cr8: UInt64 {
                get { sregs.cr8 }
                set { sregs.cr8 = newValue }
            }

            public var efer: UInt64 {
                get { sregs.efer }
                set { sregs.efer = newValue }
            }

            public var gdtrBase: UInt64 {
                get { sregs.gdt.base }
                set { sregs.gdt.base = newValue }
            }

            public var gdtrLimit: UInt32 {
                get { UInt32(sregs.gdt.limit) }
                set { sregs.gdt.limit = UInt16(newValue) }
            }

            public var idtrBase: UInt64  {
                get { sregs.idt.base }
                set { sregs.idt.base = newValue }
            }

            public var idtrLimit:  UInt32 {
                get { UInt32(sregs.idt.limit) }
                set { sregs.idt.limit = UInt16(newValue) }
            }
        }

        private let vcpu_fd: Int32
        private let semaphore = DispatchSemaphore(value: 0)
        private let kvmRunPtr: KVM_RUN_PTR
        private let kvm_run_mmap_size: Int32

        private let lock = NSLock()
        private var pendingIRQ: UInt32?

        public unowned let vm: VirtualMachine
        public var registers = Registers()


        init(vm: VirtualMachine, vcpu_fd: Int32) throws {
            self.vcpu_fd = vcpu_fd
            self.vm = vm

            guard let mmapSize = VirtualMachine.vcpuMmapSize else { throw HVError.vmSubsystemFail }
            kvm_run_mmap_size = mmapSize

            guard let ptr = mmap(nil, Int(kvm_run_mmap_size), PROT_READ | PROT_WRITE, MAP_SHARED, vcpu_fd, 0),
                ptr != UnsafeMutableRawPointer(bitPattern: -1) else {
                    close(vcpu_fd)
                    print("cant mmap vcpu")
                    throw HVError.vmSubsystemFail
            }
            kvmRunPtr = ptr.bindMemory(to: kvm_run.self, capacity: 1)

            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_REGS, &registers.regs) >= 0 else {
                print("Cant get regs")
                throw HVError.vmSubsystemFail
            }

            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_SREGS, &registers.sregs) >= 0 else {
                print("Cant get sregs")
                throw HVError.vmSubsystemFail
            }
        }


        public func runVCPU(vmExitHandler: @escaping (VirtualMachine.VCPU, VMExit) throws -> Bool,
                            completionHandler: @escaping () -> ()) {
            semaphore.wait()
            var finished = false
            while !finished {
                do {
                    let vmExit = try self.runOnce()
                    finished = try vmExitHandler(self, vmExit)
                } catch {
                    fatalError("processVMExit failed with \(error)")
                }
            }
        }


        public func start() {
            semaphore.signal()
        }


        private func runOnce() throws -> VMExit {

            registers.updateSRegs()

            if registers.rflags.interruptEnable {
                if let irq = nextPendingIRQ() {
                    var interrupt = kvm_interrupt(irq: irq)
                    print("_IOCTL_KVM_INTERRUPT:", interrupt)
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

            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_SET_REGS, &registers.regs) >= 0 else {
                throw HVError.setRegisters
            }

            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_SET_SREGS, &registers.sregs) >= 0 else {
                throw HVError.setRegisters
            }

            let ret = ioctl2arg(vcpu_fd, _IOCTL_KVM_RUN)
            guard ret >= 0 else {
                throw HVError.vmRunError
            }

            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_REGS, &registers.regs) >= 0 else {
                throw HVError.getRegisters
            }

            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_SREGS, &registers.sregs) >= 0 else {
                throw HVError.getRegisters
            }

            registers.readSRegs()

            guard let exitReason = KVMExit(rawValue: kvmRunPtr.pointee.exit_reason) else {
                fatalError("Invalid KVM exit reason: \(kvmRunPtr.pointee.exit_reason)")
            }

            return exitReason.vmExit(kvmRunPtr: kvmRunPtr)
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
            print("queuing IRQ:", irq)
            lock.lock()
            pendingIRQ = UInt32(irq)
            lock.unlock()
        }

        public func clearPendingIRQ() {
            print("Clearing pending irq")
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


        func shutdown() {
            munmap(kvmRunPtr, Int(kvm_run_mmap_size))
            close(vcpu_fd)
        }
    }
}

#endif
