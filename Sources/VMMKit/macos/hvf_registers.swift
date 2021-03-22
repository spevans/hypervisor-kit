//
//  hvf_registers.swift
//  VMMKit
//
//  Created by Simon Evans on 01/03/2021.
//  Copyright © 2021 Simon Evans. All rights reserved.
//
//  Cached VCPU registers between VMExits.
//

#if os(macOS)

import Hypervisor

internal struct RegisterCacheControl: RegisterCacheControlProtocol {

    private var vcpuId: hv_vcpuid_t?
    private var vmcs: VMCS?
    internal var cache = RegisterCache()

    // Initialise an empty set of registers, used before first vCPU run.
    internal init(vcpuId: hv_vcpuid_t, vmcs: VMCS) {
        self.vcpuId = vcpuId
        self.vmcs = vmcs
    }

    /// readRegisters(registerSet:) must be called for a specific register before reading that register so that it can be loaded
    /// from the vCPU. It is not required before writing to a full width register (eg RAX) but writing to a narrower register (EAX, AX, AH, AL)
    /// does require it to be read first.
    internal mutating func readRegisters(_ registerSet: RegisterSet) throws {
        guard let vcpuId = self.vcpuId, let vmcs = self.vmcs else {
            // If these values are nil then this should be a Register created when the
            // vcpu finished so all of the cache values should be set, so just return
            return
        }

        func readRegister(_ register: hv_x86_reg_t) throws -> UInt64 {
            var value: UInt64 = 0
            try hvError(hv_vcpu_read_register(vcpuId, register, &value))
            return value
        }

        if registerSet.contains(.rax), cache._rax == nil { cache._rax = try readRegister(HV_X86_RAX) }
        if registerSet.contains(.rbx), cache._rbx == nil { cache._rbx = try readRegister(HV_X86_RBX) }
        if registerSet.contains(.rcx), cache._rcx == nil { cache._rcx = try readRegister(HV_X86_RCX) }
        if registerSet.contains(.rdx), cache._rdx == nil { cache._rdx = try readRegister(HV_X86_RDX) }
        if registerSet.contains(.rdi), cache._rdi == nil { cache._rdi = try readRegister(HV_X86_RDI) }
        if registerSet.contains(.rsi), cache._rsi == nil { cache._rsi = try readRegister(HV_X86_RSI) }
        if registerSet.contains(.rbp), cache._rbp == nil { cache._rbp = try readRegister(HV_X86_RBP) }
        if registerSet.contains(.rsp), cache._rsp == nil { cache._rsp = try readRegister(HV_X86_RSP) }
        if registerSet.contains(.r8),   cache._r8 == nil { cache._r8 = try readRegister(HV_X86_R8) }
        if registerSet.contains(.r9),   cache._r9 == nil { cache._r9 = try readRegister(HV_X86_R9) }
        if registerSet.contains(.r10), cache._r10 == nil { cache._r10 = try readRegister(HV_X86_R10) }
        if registerSet.contains(.r11), cache._r11 == nil { cache._r11 = try readRegister(HV_X86_R11) }
        if registerSet.contains(.r12), cache._r12 == nil { cache._r12 = try readRegister(HV_X86_R12) }
        if registerSet.contains(.r13), cache._r13 == nil { cache._r13 = try readRegister(HV_X86_R13) }
        if registerSet.contains(.r14), cache._r14 == nil { cache._r14 = try readRegister(HV_X86_R14) }
        if registerSet.contains(.r15), cache._r15 == nil { cache._r15 = try readRegister(HV_X86_R15) }
        if registerSet.contains(.rip), cache._rip == nil { cache._rip = try readRegister(HV_X86_RIP) }
        if registerSet.contains(.rflags), cache._rflags == nil { cache._rflags = CPU.RFLAGS(try readRegister(HV_X86_RFLAGS)) }
        if registerSet.contains(.cr0), cache._cr0 == nil { cache._cr0 = try readRegister(HV_X86_CR0) }
        if registerSet.contains(.cr2), cache._cr2 == nil { cache._cr2 = try readRegister(HV_X86_CR2) }
        if registerSet.contains(.cr3), cache._cr3 == nil { cache._cr3 = try readRegister(HV_X86_CR3) }
        if registerSet.contains(.cr4), cache._cr4 == nil { cache._cr4 = try readRegister(HV_X86_CR4) }
        if registerSet.contains(.efer), cache._cr4 == nil { cache._cr4 = try vmcs.guestIA32EFER() }

        if registerSet.contains(.cs), cache._cs == nil {
            cache._cs = try SegmentRegister(selector: vmcs.guestCSSelector(),
                                      base: vmcs.guestCSBase(),
                                      limit: vmcs.guestCSLimit(),
                                      accessRights: vmcs.guestCSAccessRights())
        }

        if registerSet.contains(.ss), cache._ss == nil {
            cache._ss = try SegmentRegister(selector: vmcs.guestSSSelector(),
                                      base: vmcs.guestSSBase(),
                                      limit: vmcs.guestSSLimit(),
                                      accessRights: vmcs.guestSSAccessRights())
        }

        if registerSet.contains(.ds), cache._ds == nil {
            cache._ds = try SegmentRegister(selector: vmcs.guestDSSelector(),
                                      base: vmcs.guestDSBase(),
                                      limit: vmcs.guestDSLimit(),
                                      accessRights: vmcs.guestDSAccessRights())
        }

        if registerSet.contains(.es), cache._es == nil {
            cache._es = try SegmentRegister(selector: vmcs.guestESSelector(),
                                      base: vmcs.guestESBase(),
                                      limit: vmcs.guestESLimit(),
                                      accessRights: vmcs.guestESAccessRights())

        }

        if registerSet.contains(.fs), cache._fs == nil {
            cache._fs = try SegmentRegister(selector: vmcs.guestFSSelector(),
                                      base: vmcs.guestFSBase(),
                                      limit: vmcs.guestFSLimit(),
                                      accessRights: vmcs.guestFSAccessRights())
        }

        if registerSet.contains(.gs), cache._gs == nil {
            cache._gs = try SegmentRegister(selector: vmcs.guestGSSelector(),
                                      base: vmcs.guestGSBase(),
                                      limit: vmcs.guestGSLimit(),
                                      accessRights: vmcs.guestGSAccessRights())
        }

        if registerSet.contains(.gdt), cache._gdt == nil {
            cache._gdt = try DescriptorTable(base: readRegister(HV_X86_GDT_BASE),
                                       limit: UInt16(readRegister(HV_X86_GDT_LIMIT)))
        }

        if registerSet.contains(.idt), cache._idt == nil {
            cache._idt = try DescriptorTable(base:readRegister(HV_X86_IDT_BASE),
                                       limit: UInt16(readRegister(HV_X86_IDT_LIMIT)))
        }

        if registerSet.contains(.ldtr), cache._ldtr == nil {
            cache._ldtr = try SegmentRegister(selector: vmcs.guestLDTRSelector(),
                                        base: vmcs.guestLDTRBase(),
                                        limit: vmcs.guestLDTRLimit(),
                                        accessRights: vmcs.guestLDTRAccessRights())
        }

        if registerSet.contains(.taskRegister), cache._taskRegister == nil {
            cache._taskRegister = try SegmentRegister(selector: vmcs.guestTRSelector(),
                                                base: vmcs.guestTRBase(),
                                                limit: vmcs.guestTRLimit(),
                                                accessRights: vmcs.guestTRAccessRights())
        }
    }

    internal mutating func setupRegisters() throws {
        guard let vcpuId = self.vcpuId, let vmcs = self.vmcs else {
            throw HVError.vcpuHasBeenShutdown
        }

        if cache.updatedRegisters.contains(.cs) {
            let cs = cache._cs!
            try vmcs.guestCSSelector(cs.selector)
            try vmcs.guestCSBase(cs.base)
            try vmcs.guestCSLimit(cs.limit)
            try vmcs.guestCSAccessRights(cs.accessRights)
        }

        if cache.updatedRegisters.contains(.ss) {
            let ss = cache._ss!
            try vmcs.guestSSSelector(ss.selector)
            try vmcs.guestSSBase(ss.base)
            try vmcs.guestSSLimit(ss.limit)
            try vmcs.guestSSAccessRights(ss.accessRights)
        }

        if cache.updatedRegisters.contains(.ds) {
            let ds = cache._ds!
            try vmcs.guestDSSelector(ds.selector)
            try vmcs.guestDSBase(ds.base)
            try vmcs.guestDSLimit(ds.limit)
            try vmcs.guestDSAccessRights(ds.accessRights)
        }

        if cache.updatedRegisters.contains(.es) {
            let es = cache._es!
            try vmcs.guestESSelector(es.selector)
            try vmcs.guestESBase(es.base)
            try vmcs.guestESLimit(es.limit)
            try vmcs.guestESAccessRights(es.accessRights)
        }

        if cache.updatedRegisters.contains(.fs) {
            let fs = cache._fs!
            try vmcs.guestFSSelector(fs.selector)
            try vmcs.guestFSBase(fs.base)
            try vmcs.guestFSLimit(fs.limit)
            try vmcs.guestFSAccessRights(fs.accessRights)
        }

        if cache.updatedRegisters.contains(.cs) {
            let gs = cache._gs!
            try vmcs.guestGSSelector(gs.selector)
            try vmcs.guestGSBase(gs.base)
            try vmcs.guestGSLimit(gs.limit)
            try vmcs.guestGSAccessRights(gs.accessRights)
        }

        if cache.updatedRegisters.contains(.taskRegister) {
            let taskRegister = cache._taskRegister!
            try vmcs.guestTRSelector(taskRegister.selector)
            try vmcs.guestTRBase(taskRegister.base)
            try vmcs.guestTRLimit(taskRegister.limit)
            try vmcs.guestTRAccessRights(taskRegister.accessRights)
        }

        if cache.updatedRegisters.contains(.ldtr) {
            let ldtr = cache._ldtr!
            try vmcs.guestLDTRSelector(ldtr.selector)
            try vmcs.guestLDTRBase(ldtr.base)
            try vmcs.guestLDTRLimit(ldtr.limit)
            try vmcs.guestLDTRAccessRights(ldtr.accessRights)
        }

        if cache.updatedRegisters.contains(.gdt) {
            let gdt = cache._gdt!
            try hvError(hv_vcpu_write_register(vcpuId, HV_X86_GDT_BASE, gdt.base))
            try hvError(hv_vcpu_write_register(vcpuId, HV_X86_GDT_LIMIT, UInt64(gdt.limit)))
        }

        if cache.updatedRegisters.contains(.idt) {
            let idt = cache._idt!
            try hvError(hv_vcpu_write_register(vcpuId, HV_X86_IDT_BASE, idt.base))
            try hvError(hv_vcpu_write_register(vcpuId, HV_X86_IDT_LIMIT, UInt64(idt.limit)))
        }

        if cache.updatedRegisters.contains(.rflags) {
            try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RFLAGS, cache._rflags!.rawValue))
        }

        if cache.updatedRegisters.contains(.rax) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RAX, cache._rax!)) }
        if cache.updatedRegisters.contains(.rbx) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RBX, cache._rbx!)) }
        if cache.updatedRegisters.contains(.rcx) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RCX, cache._rcx!)) }
        if cache.updatedRegisters.contains(.rdx) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RDX, cache._rdx!)) }
        if cache.updatedRegisters.contains(.rsi) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RSI, cache._rsi!)) }
        if cache.updatedRegisters.contains(.rdi) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RDI, cache._rdi!)) }
        if cache.updatedRegisters.contains(.rsp) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RSP, cache._rsp!)) }
        if cache.updatedRegisters.contains(.rbp) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RBP, cache._rbp!)) }
        if cache.updatedRegisters.contains(.r8)  { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R8, cache._r8!))   }
        if cache.updatedRegisters.contains(.r9)  { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R9, cache._r9!))   }
        if cache.updatedRegisters.contains(.r10) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R10, cache._r10!)) }
        if cache.updatedRegisters.contains(.r11) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R11, cache._r11!)) }
        if cache.updatedRegisters.contains(.r12) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R12, cache._r12!)) }
        if cache.updatedRegisters.contains(.r13) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R13, cache._r13!)) }
        if cache.updatedRegisters.contains(.r14) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R14, cache._r14!)) }
        if cache.updatedRegisters.contains(.r15) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R15, cache._r15!)) }
        if cache.updatedRegisters.contains(.rip) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RIP, cache._rip!)) }
        if cache.updatedRegisters.contains(.cr0) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_CR0, cache._cr0!)) }
        if cache.updatedRegisters.contains(.cr2) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_CR2, cache._cr2!)) }
        if cache.updatedRegisters.contains(.cr3) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_CR3, cache._cr3!)) }
        if cache.updatedRegisters.contains(.cr4) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_CR4, cache._cr4!)) }
        if cache.updatedRegisters.contains(.efer) { try vmcs.guestIA32EFER(cache._efer!) }

        cache.updatedRegisters = []
    }

    internal mutating func clearCache() {
        cache = RegisterCache()
    }

    internal mutating func makeReadOnly() {
        self.vcpuId = nil
        self.vmcs = nil
    }
}

#endif
