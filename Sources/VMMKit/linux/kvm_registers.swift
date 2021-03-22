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

internal struct RegisterCacheControl: RegisterCacheControlProtocol {

    private var vcpu_fd: Int32?
    private var _regs: kvm_regs?
    private var _sregs: kvm_sregs?
    internal var cache = RegisterCache()

    static let regsRegisterSet: RegisterSet = [
        .rax, .rbx, .rcx, .rdx, .rsi, .rdi, .rsp, .rbp, .r8, .r9, .r10, .r11, .r12, .r13, .r14, .r15, .rip, .rflags
    ]
    static let sregsRegisterSet: RegisterSet = [
        .cs, .ds, .es, .fs, .gs, .ss, .taskRegister, .ldtr, .gdt, .idt, .cr0, .cr2, .cr4, .efer
    ]

    internal init(vcpu_fd: Int32) {
        self.vcpu_fd = vcpu_fd
    }

    /// readRegisters(registerSet:) must be called for a specific register before reading that register so that it can be loaded11
    /// from the vCPU. It is not required before writing to a full width register (eg RAX) but writing to a narrower register (EAX, AX, AH, AL)
    /// does require it to be read first.
    internal mutating func readRegisters(_ registerSet: RegisterSet) throws {
        guard vcpu_fd != nil else {
            // If these values are nil then this should be a Register created when the
            // vcpu finished so all of the cache values should be set, so just return
            return
        }

        if !registerSet.isDisjoint(with: Self.regsRegisterSet) {
            let regs = try getRegs()
            if registerSet.contains(.rax), cache._rax == nil { cache._rax = regs.rax }
            if registerSet.contains(.rbx), cache._rbx == nil { cache._rbx = regs.rbx }
            if registerSet.contains(.rcx), cache._rcx == nil { cache._rcx = regs.rcx }
            if registerSet.contains(.rdx), cache._rdx == nil { cache._rdx = regs.rdx }
            if registerSet.contains(.rdi), cache._rdi == nil { cache._rdi = regs.rdi }
            if registerSet.contains(.rsi), cache._rsi == nil { cache._rsi = regs.rsi }
            if registerSet.contains(.rbp), cache._rbp == nil { cache._rbp = regs.rbp }
            if registerSet.contains(.rsp), cache._rsp == nil { cache._rsp = regs.rsp }
            if registerSet.contains(.r8),   cache._r8 == nil { cache._r8 = regs.r8 }
            if registerSet.contains(.r9),   cache._r9 == nil { cache._r9 = regs.r9 }
            if registerSet.contains(.r10), cache._r10 == nil { cache._r10 = regs.r10 }
            if registerSet.contains(.r11), cache._r11 == nil { cache._r11 = regs.r11 }
            if registerSet.contains(.r12), cache._r12 == nil { cache._r12 = regs.r12 }
            if registerSet.contains(.r13), cache._r13 == nil { cache._r13 = regs.r13 }
            if registerSet.contains(.r14), cache._r14 == nil { cache._r14 = regs.r14 }
            if registerSet.contains(.r15), cache._r15 == nil { cache._r15 = regs.r15 }
            if registerSet.contains(.rip), cache._rip == nil { cache._rip = regs.rip }
            if registerSet.contains(.rflags), cache._rflags == nil { cache._rflags = CPU.RFLAGS(regs.rflags) }
        }

        if !registerSet.isDisjoint(with: Self.sregsRegisterSet) {
            let sregs = try getSregs()
            if registerSet.contains(.cr0), cache._cr0 == nil { cache._cr0 = sregs.cr0 }
            if registerSet.contains(.cr2), cache._cr2 == nil { cache._cr2 = sregs.cr2 }
            if registerSet.contains(.cr3), cache._cr3 == nil { cache._cr3 = sregs.cr3 }
            if registerSet.contains(.cr4), cache._cr4 == nil { cache._cr4 = sregs.cr4 }
            if registerSet.contains(.efer), cache._efer == nil { cache._efer = sregs.efer }

            if registerSet.contains(.cs), cache._cs == nil { cache._cs = SegmentRegister(sregs.cs) }
            if registerSet.contains(.ss), cache._ss == nil { cache._ss = SegmentRegister(sregs.ss) }
            if registerSet.contains(.ds), cache._ds == nil { cache._ds = SegmentRegister(sregs.ds) }
            if registerSet.contains(.es), cache._es == nil { cache._es = SegmentRegister(sregs.es) }
            if registerSet.contains(.fs), cache._fs == nil { cache._fs = SegmentRegister(sregs.fs) }
            if registerSet.contains(.gs), cache._gs == nil { cache._gs = SegmentRegister(sregs.gs) }
            if registerSet.contains(.ldtr), cache._ldtr == nil { cache._ldtr = SegmentRegister(sregs.ldt) }
            if registerSet.contains(.taskRegister), cache._taskRegister == nil { cache._taskRegister = SegmentRegister(sregs.tr) }
            if registerSet.contains(.gdt), cache._gdt == nil { cache._gdt = DescriptorTable(sregs.gdt) }
            if registerSet.contains(.idt), cache._idt == nil { cache._idt = DescriptorTable(sregs.idt) }
        }
    }

    internal mutating func setupRegisters() throws {
        guard let vcpu_fd = vcpu_fd else {
            throw HVError.vcpuHasBeenShutdown
        }

        if !cache.updatedRegisters.isDisjoint(with: Self.regsRegisterSet) {
            var regs = try getRegs()
            if cache.updatedRegisters.contains(.rax) { regs.rax = cache._rax! }
            if cache.updatedRegisters.contains(.rbx) { regs.rbx = cache._rbx! }
            if cache.updatedRegisters.contains(.rcx) { regs.rcx = cache._rcx! }
            if cache.updatedRegisters.contains(.rdx) { regs.rdx = cache._rdx! }
            if cache.updatedRegisters.contains(.rdi) { regs.rdi = cache._rdi! }
            if cache.updatedRegisters.contains(.rsi) { regs.rsi = cache._rsi! }
            if cache.updatedRegisters.contains(.rbp) { regs.rbp = cache._rbp! }
            if cache.updatedRegisters.contains(.rsp) { regs.rsp = cache._rsp! }
            if cache.updatedRegisters.contains(.r8) { regs.r8 = cache._r8! }
            if cache.updatedRegisters.contains(.r9) { regs.r9 = cache._r9! }
            if cache.updatedRegisters.contains(.r10) { regs.r10 = cache._r10! }
            if cache.updatedRegisters.contains(.r11) { regs.r11 = cache._r11! }
            if cache.updatedRegisters.contains(.r12) { regs.r12 = cache._r12! }
            if cache.updatedRegisters.contains(.r13) { regs.r13 = cache._r13! }
            if cache.updatedRegisters.contains(.r14) { regs.r14 = cache._r14! }
            if cache.updatedRegisters.contains(.r15) { regs.r15 = cache._r15! }
            if cache.updatedRegisters.contains(.rip) { regs.rip = cache._rip! }
            if cache.updatedRegisters.contains(.rflags) { regs.rflags = cache._rflags!.rawValue }

            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_SET_REGS, &regs) >= 0 else {
                throw HVError.setRegisters
            }
        }

        if !cache.updatedRegisters.isDisjoint(with: Self.sregsRegisterSet) {
            var sregs = try getSregs()

            if cache.updatedRegisters.contains(.cr0) { sregs.cr0 = cache._cr0! }
            if cache.updatedRegisters.contains(.cr2) { sregs.cr2 = cache._cr2! }
            if cache.updatedRegisters.contains(.cr3) { sregs.cr3 = cache._cr3! }
            if cache.updatedRegisters.contains(.cr4) { sregs.cr4 = cache._cr4! }
            if cache.updatedRegisters.contains(.efer) { sregs.efer = cache._efer! }
            if cache.updatedRegisters.contains(.cs) { sregs.cs = cache._cs!.kvmSegment }
            if cache.updatedRegisters.contains(.ss) { sregs.ss = cache._ss!.kvmSegment }
            if cache.updatedRegisters.contains(.ds) { sregs.ds = cache._ds!.kvmSegment }
            if cache.updatedRegisters.contains(.es) { sregs.es = cache._es!.kvmSegment }
            if cache.updatedRegisters.contains(.fs) { sregs.fs = cache._fs!.kvmSegment }
            if cache.updatedRegisters.contains(.gs) { sregs.gs = cache._gs!.kvmSegment }
            if cache.updatedRegisters.contains(.ldtr) { sregs.ldt = cache._ldtr!.kvmSegment }
            if cache.updatedRegisters.contains(.taskRegister) { sregs.tr = cache._taskRegister!.kvmSegment }
            if cache.updatedRegisters.contains(.gdt) { sregs.gdt = cache._gdt!.kvmDtable }
            if cache.updatedRegisters.contains(.idt) { sregs.idt = cache._idt!.kvmDtable }

            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_SET_SREGS, &sregs) >= 0 else {
                throw HVError.setRegisters
            }
        }
        cache.updatedRegisters = []
    }

    internal mutating func clearCache() {
        cache = RegisterCache()
        _regs = nil
        _sregs = nil
    }

    internal mutating func makeReadOnly() {
        self.vcpu_fd = nil
    }

    private mutating func getRegs() throws -> kvm_regs {
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

    private mutating func getSregs() throws -> kvm_sregs {
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

#endif
