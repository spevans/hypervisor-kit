//
//  File.swift
//  
//
//  Created by Simon Evans on 08/12/2019.
//

import Hypervisor

extension VirtualMachine {
    final class VCPU {

        struct SegmentRegister {
            var selector: UInt16 = 0
            var base: UInt = 0
            var limit: UInt32 = 0
            var accessRights: UInt32 = 0
        }

        struct Registers {

            var cs: SegmentRegister = SegmentRegister()
            var ss: SegmentRegister = SegmentRegister()
            var ds: SegmentRegister = SegmentRegister()
            var es: SegmentRegister = SegmentRegister()
            var fs: SegmentRegister = SegmentRegister()
            var gs: SegmentRegister = SegmentRegister()
            var tr: SegmentRegister = SegmentRegister()
            var ldtr: SegmentRegister = SegmentRegister()

            var rax: UInt64 = 0
            var rbx: UInt64 = 0
            var rcx: UInt64 = 0
            var rdx: UInt64 = 0
            var rsi: UInt64 = 0
            var rdi: UInt64 = 0
            var rsp: UInt64 = 0
            var rbp: UInt64 = 0
            var r8: UInt64 = 0
            var r9: UInt64 = 0
            var r10: UInt64 = 0
            var r11: UInt64 = 0
            var r12: UInt64 = 0
            var r13: UInt64 = 0
            var r14: UInt64 = 0
            var r15: UInt64 = 0
            var rip: UInt64 = 0
            var rflags: UInt64 = 0
            var cr0: UInt64 = 0
            var cr2: UInt64 = 0
            var cr3: UInt64 = 0
            var cr4: UInt64 = 0
            var cr8: UInt64 = 0

            var gdtrBase: UInt64 = 0
            var gdtrLimit: UInt64 = 0
            var idtrBase: UInt64 = 0
            var idtrLimit: UInt64 = 0


            func readRegister(_ vcpuId: hv_vcpuid_t, _ register: hv_x86_reg_t) throws -> UInt64 {
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
                try writeRegister(vcpuId, HV_X86_RFLAGS, rflags)
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
                rflags = try readRegister(vcpuId, HV_X86_RFLAGS)
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
        }

        var registers = Registers()

        let vcpuId: hv_vcpuid_t
        let vmcs: VMCS

        init() throws {
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

            try vmcs.exceptionBitmap(0xffffffff)
            try vmcs.cr0mask(0x60000000)
            try vmcs.cr0ReadShadow(CPU.CR0Register(0))
            try vmcs.cr4mask(0)
            try vmcs.cr4ReadShadow(CPU.CR4Register(0))
        }

        func run() throws -> VMXExit {
            try registers.setupRegisters(vcpuId: vcpuId)
            try registers.setupSegmentRegisters(vmcs: vmcs)
            try hvError(hv_vcpu_run(vcpuId))
            try registers.readRegisters(vcpuId: vcpuId)

            return try vmcs.exitReason()
        }

        func shutdown() throws {
            try hvError(hv_vcpu_destroy(vcpuId))
        }
    }
}
