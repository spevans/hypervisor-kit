//
//  kvm_registers.swift
//  VMMKit
//
//  Created by Simon Evans on 01/03/2021.
//  Copyright © 2021 Simon Evans. All rights reserved.
//
//  Cached VCPU registers between VMExits.
//

#if os(Linux)

import CBits

extension SegmentRegister {

    init(_ kvmSegment: kvm_segment) {
        selector = kvmSegment.selector
        base = kvmSegment.base
        limit = kvmSegment.limit

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
        accessRights = bitArray.rawValue
    }

    var kvmSegment: kvm_segment {
        let bitArray = BitArray32(accessRights)
        return kvm_segment(base: base,
                           limit: limit,
                           selector: selector,
                           type: UInt8(bitArray[0...3]),
                           present: UInt8(bitArray[7]),
                           dpl: UInt8(bitArray[5...6]),
                           db: UInt8(bitArray[14]),
                           s: UInt8(bitArray[4]),
                           l: UInt8(bitArray[13]),
                           g: UInt8(bitArray[15]),
                           avl: UInt8(bitArray[12]),
                           unusable: 0, padding: 0)
    }
}

extension DescriptorTable {

    init(_ kvmDtable: kvm_dtable) {
        base = kvmDtable.base
        limit = kvmDtable.limit
    }

    var kvmDtable: kvm_dtable {
        return kvm_dtable(base: base, limit: limit, padding: (0, 0, 0))
    }
}

extension VirtualMachine.VCPU {
    // Access to the register set. This acts as a cache of the register and segment register values
    // to avoid excess ioctl() calls to get either of the 2 sets.
    // When the vCPU has finished executing, the _registers in the vcpu object is instansiated with
    // the final register values instead of the vcpu so that the final register values can be accessed.
    public final class Registers: RegisterProtocol {
        private var vcpu_fd: Int32?
        private var updatedRegisters = RegisterSet()
        private var _regs: kvm_regs?
        private var _sregs: kvm_sregs?

        private var _cs: SegmentRegister?
        private var _ds: SegmentRegister?
        private var _es: SegmentRegister?
        private var _fs: SegmentRegister?
        private var _gs: SegmentRegister?
        private var _ss: SegmentRegister?
        private var _taskRegister: SegmentRegister?
        private var _ldtr: SegmentRegister?
        private var _gdt: DescriptorTable?
        private var _idt: DescriptorTable?
        private var _rflags: CPU.RFLAGS?

        private var _rax: UInt64?
        private var _rbx: UInt64?
        private var _rcx: UInt64?
        private var _rdx: UInt64?
        private var _rsi: UInt64?
        private var _rdi: UInt64?
        private var _rsp: UInt64?
        private var _rbp: UInt64?
        private var _r8: UInt64?
        private var _r9: UInt64?
        private var _r10: UInt64?
        private var _r11: UInt64?
        private var _r12: UInt64?
        private var _r13: UInt64?
        private var _r14: UInt64?
        private var _r15: UInt64?
        private var _rip: UInt64?
        private var _cr0: UInt64?
        private var _cr2: UInt64?
        private var _cr3: UInt64?
        private var _cr4: UInt64?
        private var _efer: UInt64?

        static let regsRegisterSet: RegisterSet = [
            .rax, .rbx, .rcx, .rdx, .rsi, .rdi, .rsp, .rbp, .r8, .r9, .r10, .r11, .r12, .r13, .r14, .r15, .rip, .rflags
        ]
        static let sregsRegisterSet: RegisterSet = [
            .cs, .ds, .es, .fs, .gs, .ss, .taskRegister, .ldtr, .gdt, .idt, .cr0, .cr2, .cr4, .efer
        ]

        // Initialise an empty set of registers, used before first vCPU run.
        internal init(vcpu_fd: Int32) {
            self.vcpu_fd = vcpu_fd
        }

        // readRegisters(registerSet:) must be called for a specific register berfore reading that register
        // so its shadow ivar will be non-nil
        public func readRegisters(_ registerSet: RegisterSet) throws {
            guard vcpu_fd != nil else {
                // If these values are nil then this should be a Register created when the
                // vcpu finished so all of the cache values should be set, so just return
                return
            }

            if !registerSet.isDisjoint(with: Self.regsRegisterSet) {
                let regs = try getRegs()
                if registerSet.contains(.rax), _rax == nil { _rax = regs.rax }
                if registerSet.contains(.rbx), _rbx == nil { _rbx = regs.rbx }
                if registerSet.contains(.rcx), _rcx == nil { _rcx = regs.rcx }
                if registerSet.contains(.rdx), _rdx == nil { _rdx = regs.rdx }
                if registerSet.contains(.rdi), _rdi == nil { _rdi = regs.rdi }
                if registerSet.contains(.rsi), _rsi == nil { _rsi = regs.rsi }
                if registerSet.contains(.rbp), _rbp == nil { _rbp = regs.rbp }
                if registerSet.contains(.rsp), _rsp == nil { _rsp = regs.rsp }
                if registerSet.contains(.r8),   _r8 == nil { _r8 = regs.r8 }
                if registerSet.contains(.r9),   _r9 == nil { _r9 = regs.r9 }
                if registerSet.contains(.r10), _r10 == nil { _r10 = regs.r10 }
                if registerSet.contains(.r11), _r11 == nil { _r11 = regs.r11 }
                if registerSet.contains(.r12), _r12 == nil { _r12 = regs.r12 }
                if registerSet.contains(.r13), _r13 == nil { _r13 = regs.r13 }
                if registerSet.contains(.r14), _r14 == nil { _r14 = regs.r14 }
                if registerSet.contains(.r15), _r15 == nil { _r15 = regs.r15 }
                if registerSet.contains(.rip), _rip == nil { _rip = regs.rip }
                if registerSet.contains(.rflags), _rflags == nil { _rflags = CPU.RFLAGS(regs.rflags) }
            }

            if !registerSet.isDisjoint(with: Self.sregsRegisterSet) {
                let sregs = try getSregs()
                if registerSet.contains(.cr0), _cr0 == nil { _cr0 = sregs.cr0 }
                if registerSet.contains(.cr2), _cr2 == nil { _cr2 = sregs.cr2 }
                if registerSet.contains(.cr3), _cr3 == nil { _cr3 = sregs.cr3 }
                if registerSet.contains(.cr4), _cr4 == nil { _cr4 = sregs.cr4 }
                if registerSet.contains(.efer), _efer == nil { _efer = sregs.efer }

                if registerSet.contains(.cs), _cs == nil { _cs = SegmentRegister(sregs.cs) }
                if registerSet.contains(.ss), _ss == nil { _ss = SegmentRegister(sregs.ss) }
                if registerSet.contains(.ds), _ds == nil { _ds = SegmentRegister(sregs.ds) }
                if registerSet.contains(.es), _es == nil { _es = SegmentRegister(sregs.es) }
                if registerSet.contains(.fs), _fs == nil { _fs = SegmentRegister(sregs.fs) }
                if registerSet.contains(.gs), _gs == nil { _gs = SegmentRegister(sregs.gs) }
                if registerSet.contains(.ldtr), _ldtr == nil { _ldtr = SegmentRegister(sregs.ldt) }
                if registerSet.contains(.taskRegister), _taskRegister == nil { _taskRegister = SegmentRegister(sregs.tr) }
                if registerSet.contains(.gdt), _gdt == nil { _gdt = DescriptorTable(sregs.gdt) }
                if registerSet.contains(.idt), _idt == nil { _idt = DescriptorTable(sregs.idt) }
            }
        }

        public var cs: SegmentRegister {
            get { _cs! }
            set { _cs = newValue; updatedRegisters.insert(.cs) }
        }

        public var ss: SegmentRegister {
            get { _ss! }
            set { _ss = newValue; updatedRegisters.insert(.ss) }
        }

        public var ds: SegmentRegister {
            get { _ds! }
            set { _ds = newValue; updatedRegisters.insert(.ds) }
        }

        public var es: SegmentRegister {
            get { _es! }
            set { _es = newValue; updatedRegisters.insert(.es) }
        }

        public var fs: SegmentRegister {
            get { _fs! }
            set { _fs = newValue; updatedRegisters.insert(.fs) }
        }

        public var gs: SegmentRegister {
            get { _gs! }
            set { _gs = newValue; updatedRegisters.insert(.gs) }
        }

        public var taskRegister: SegmentRegister {
            get { _taskRegister! }
            set { _taskRegister = newValue; updatedRegisters.insert(.taskRegister) }
        }

        public var ldtr: SegmentRegister {
            get { _ldtr! }
            set { _ldtr = newValue; updatedRegisters.insert(.ldtr) }
        }

        public var gdt: DescriptorTable {
            get { _gdt! }
            set { _gdt = newValue; updatedRegisters.insert(.gdt) }
        }

        public var idt: DescriptorTable {
            get { _idt! }
            set { _idt = newValue; updatedRegisters.insert(.idt) }
        }

        public var rflags: CPU.RFLAGS {
            get { _rflags! }
            set { _rflags = newValue; updatedRegisters.insert(.rflags) }
        }

        public var rax: UInt64 {
            get { _rax! }
            set { _rax = newValue; updatedRegisters.insert(.rax) }
        }

        public var rbx: UInt64 {
            get { _rbx! }
            set { _rbx = newValue; updatedRegisters.insert(.rbx) }
        }

        public var rcx: UInt64 {
            get { _rcx! }
            set { _rcx = newValue; updatedRegisters.insert(.rcx) }
        }

        public var rdx: UInt64 {
            get { _rdx! }
            set { _rdx = newValue; updatedRegisters.insert(.rdx) }
        }

        public var rdi: UInt64 {
            get { _rdi! }
            set { _rdi = newValue; updatedRegisters.insert(.rdi) }
        }

        public var rsi: UInt64 {
            get { _rsi! }
            set { _rsi = newValue; updatedRegisters.insert(.rsi) }
        }

        public var rbp: UInt64 {
            get { _rbp! }
            set { _rbp = newValue; updatedRegisters.insert(.rbp) }
        }

        public var rsp: UInt64 {
            get { _rsp! }
            set { _rsp = newValue; updatedRegisters.insert(.rsp) }
        }

        public var r8: UInt64 {
            get { _r8! }
            set { _r8 = newValue; updatedRegisters.insert(.r8) }
        }

        public var r9: UInt64 {
            get { _r9! }
            set { _r9 = newValue; updatedRegisters.insert(.r9) }
        }

        public var r10: UInt64 {
            get { _r10! }
            set { _r10 = newValue; updatedRegisters.insert(.r10) }
        }

        public var r11: UInt64 {
            get { _r11! }
            set { _r11 = newValue; updatedRegisters.insert(.r11) }
        }

        public var r12: UInt64 {
            get { _r12! }
            set { _r12 = newValue; updatedRegisters.insert(.r12) }
        }

        public var r13: UInt64 {
            get { _r13! }
            set { _r13 = newValue; updatedRegisters.insert(.r13) }
        }

        public var r14: UInt64 {
            get { _r14! }
            set { _r14 = newValue; updatedRegisters.insert(.r14) }
        }

        public var r15: UInt64 {
            get { _r15! }
            set { _r15 = newValue; updatedRegisters.insert(.r15) }
        }

        public var rip: UInt64 {
            get { _rip! }
            set { _rip = newValue; updatedRegisters.insert(.rip) }
        }

        public var cr0: UInt64 {
            get { _cr0! }
            set { _cr0 = newValue; updatedRegisters.insert(.cr0) }
        }

        public var cr2: UInt64 {
            get { _cr2! }
            set { _cr2 = newValue; updatedRegisters.insert(.cr2) }
        }

        public var cr3: UInt64 {
            get { _cr3! }
            set { _cr3 = newValue; updatedRegisters.insert(.cr3) }
        }

        public var cr4: UInt64 {
            get { _cr4! }
            set { _cr4 = newValue; updatedRegisters.insert(.cr4) }
        }

        public var efer: UInt64 {
            get { _efer! }
            set { _efer = newValue; updatedRegisters.insert(.efer) }
        }

        internal func clearCache() {
            updatedRegisters = RegisterSet()
            _regs = nil
            _sregs = nil
            _cs = nil
            _ds = nil
            _es = nil
            _fs = nil
            _gs = nil
            _ss = nil
            _taskRegister = nil
            _ldtr = nil
            _gdt = nil
            _idt = nil
            _rflags = nil
            _rax = nil
            _rbx = nil
            _rcx = nil
            _rdx = nil
            _rsi = nil
            _rdi = nil
            _rsp = nil
            _rbp = nil
            _r8 = nil
            _r9 = nil
            _r10 = nil
            _r11 = nil
            _r12 = nil
            _r13 = nil
            _r14 = nil
            _r15 = nil
            _rip = nil
            _cr0 = nil
            _cr2 = nil
            _cr3 = nil
            _cr4 = nil
            _efer = nil
        }

        internal func makeReadOnly() {
            self.vcpu_fd = nil
        }

        internal func setupRegisters() throws {
            guard let vcpu_fd = vcpu_fd else {
                throw HVError.vcpuHasBeenShutdown
            }

            if !updatedRegisters.isDisjoint(with: Self.regsRegisterSet) {
                var regs = try getRegs()
                if updatedRegisters.contains(.rax) { regs.rax = _rax! }
                if updatedRegisters.contains(.rbx) { regs.rbx = _rbx! }
                if updatedRegisters.contains(.rcx) { regs.rcx = _rcx! }
                if updatedRegisters.contains(.rdx) { regs.rdx = _rdx! }
                if updatedRegisters.contains(.rdi) { regs.rdi = _rdi! }
                if updatedRegisters.contains(.rsi) { regs.rsi = _rsi! }
                if updatedRegisters.contains(.rbp) { regs.rbp = _rbp! }
                if updatedRegisters.contains(.rsp) { regs.rsp = _rsp! }
                if updatedRegisters.contains(.r8) { regs.r8 = _r8! }
                if updatedRegisters.contains(.r9) { regs.r9 = _r9! }
                if updatedRegisters.contains(.r10) { regs.r10 = _r10! }
                if updatedRegisters.contains(.r11) { regs.r11 = _r11! }
                if updatedRegisters.contains(.r12) { regs.r12 = _r12! }
                if updatedRegisters.contains(.r13) { regs.r13 = _r13! }
                if updatedRegisters.contains(.r14) { regs.r14 = _r14! }
                if updatedRegisters.contains(.r15) { regs.r15 = _r15! }
                if updatedRegisters.contains(.rip) { regs.rip = _rip! }
                if updatedRegisters.contains(.rflags) { regs.rflags = _rflags!.rawValue }

                guard ioctl3arg(vcpu_fd, _IOCTL_KVM_SET_REGS, &regs) >= 0 else {
                    throw HVError.setRegisters
                }
            }

            if !updatedRegisters.isDisjoint(with: Self.sregsRegisterSet) {
                var sregs = try getSregs()

                if updatedRegisters.contains(.cr0) { sregs.cr0 = _cr0! }
                if updatedRegisters.contains(.cr2) { sregs.cr2 = _cr2! }
                if updatedRegisters.contains(.cr3) { sregs.cr3 = _cr3! }
                if updatedRegisters.contains(.cr4) { sregs.cr4 = _cr4! }
                if updatedRegisters.contains(.efer) { sregs.efer = _efer! }
                if updatedRegisters.contains(.cs) { sregs.cs = _cs!.kvmSegment }
                if updatedRegisters.contains(.ss) { sregs.ss = _ss!.kvmSegment }
                if updatedRegisters.contains(.ds) { sregs.ds = _ds!.kvmSegment }
                if updatedRegisters.contains(.es) { sregs.es = _es!.kvmSegment }
                if updatedRegisters.contains(.fs) { sregs.fs = _fs!.kvmSegment }
                if updatedRegisters.contains(.gs) { sregs.gs = _gs!.kvmSegment }
                if updatedRegisters.contains(.ldtr) { sregs.ldt = _ldtr!.kvmSegment }
                if updatedRegisters.contains(.taskRegister) { sregs.tr = _taskRegister!.kvmSegment }
                if updatedRegisters.contains(.gdt) { sregs.gdt = _gdt!.kvmDtable }
                if updatedRegisters.contains(.idt) { sregs.idt = _idt!.kvmDtable }

                guard ioctl3arg(vcpu_fd, _IOCTL_KVM_SET_SREGS, &sregs) >= 0 else {
                    throw HVError.setRegisters
                }
            }
        }

        private func getRegs() throws -> kvm_regs {
            if let regs = _regs { return regs }
            guard let vcpu_fd = vcpu_fd else {
                throw HVError.vcpuHasBeenShutdown
            }
            var regs = kvm_regs()
            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_REGS, &regs) >= 0 else {
                throw HVError.getRegisters
            }
            _regs = regs
            return regs
        }

        private func getSregs() throws -> kvm_sregs {
            if let sregs = _sregs { return sregs }
            guard let vcpu_fd = vcpu_fd else {
                throw HVError.vcpuHasBeenShutdown
            }
            var sregs = kvm_sregs()
            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_SREGS, &sregs) >= 0 else {
                throw HVError.getRegisters
            }
            _sregs = sregs
            return sregs
        }
    }
}

#endif
