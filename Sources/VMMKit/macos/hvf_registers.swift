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

extension VirtualMachine.VCPU {

    public final class Registers: RegisterProtocol {
        private var vcpuId: hv_vcpuid_t?
        private var vmcs: VMCS?
        private var updatedRegisters = RegisterSet()

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

        // Initialise an empty set of registers, used before first vCPU run.
        internal init(vcpuId: hv_vcpuid_t, vmcs: VMCS) {
            self.vcpuId = vcpuId
            self.vmcs = vmcs
        }

        // readRegisters(registerSet:) must be called for a specific register berfore reading that register
        // so its shadow ivar will be non-nil
        public func readRegisters(_ registerSet: RegisterSet) throws {
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

            if registerSet.contains(.rax), _rax == nil { _rax = try readRegister(HV_X86_RAX) }
            if registerSet.contains(.rbx), _rbx == nil { _rbx = try readRegister(HV_X86_RBX) }
            if registerSet.contains(.rcx), _rcx == nil { _rcx = try readRegister(HV_X86_RCX) }
            if registerSet.contains(.rdx), _rdx == nil { _rdx = try readRegister(HV_X86_RDX) }
            if registerSet.contains(.rdi), _rdi == nil { _rdi = try readRegister(HV_X86_RDI) }
            if registerSet.contains(.rsi), _rsi == nil { _rsi = try readRegister(HV_X86_RSI) }
            if registerSet.contains(.rbp), _rbp == nil { _rbp = try readRegister(HV_X86_RBP) }
            if registerSet.contains(.rsp), _rsp == nil { _rsp = try readRegister(HV_X86_RSP) }
            if registerSet.contains(.r8),   _r8 == nil { _r8 = try readRegister(HV_X86_R8) }
            if registerSet.contains(.r9),   _r9 == nil { _r9 = try readRegister(HV_X86_R9) }
            if registerSet.contains(.r10), _r10 == nil { _r10 = try readRegister(HV_X86_R10) }
            if registerSet.contains(.r11), _r11 == nil { _r11 = try readRegister(HV_X86_R11) }
            if registerSet.contains(.r12), _r12 == nil { _r12 = try readRegister(HV_X86_R12) }
            if registerSet.contains(.r13), _r13 == nil { _r13 = try readRegister(HV_X86_R13) }
            if registerSet.contains(.r14), _r14 == nil { _r14 = try readRegister(HV_X86_R14) }
            if registerSet.contains(.r15), _r15 == nil { _r15 = try readRegister(HV_X86_R15) }
            if registerSet.contains(.rip), _rip == nil { _rip = try readRegister(HV_X86_RIP) }
            if registerSet.contains(.rflags), _rflags == nil { _rflags = CPU.RFLAGS(try readRegister(HV_X86_RFLAGS)) }
            if registerSet.contains(.cr0), _cr0 == nil { _cr0 = try readRegister(HV_X86_CR0) }
            if registerSet.contains(.cr2), _cr2 == nil { _cr2 = try readRegister(HV_X86_CR2) }
            if registerSet.contains(.cr3), _cr3 == nil { _cr3 = try readRegister(HV_X86_CR3) }
            if registerSet.contains(.cr4), _cr4 == nil { _cr4 = try readRegister(HV_X86_CR4) }
            if registerSet.contains(.efer), _cr4 == nil { _cr4 = try vmcs.guestIA32EFER() }

            if registerSet.contains(.cs), _cs == nil {
                _cs = try SegmentRegister(selector: vmcs.guestCSSelector(),
                                          base: vmcs.guestCSBase(),
                                          limit: vmcs.guestCSLimit(),
                                          accessRights: vmcs.guestCSAccessRights())
            }

            if registerSet.contains(.ss), _ss == nil {
                _ss = try SegmentRegister(selector: vmcs.guestSSSelector(),
                                          base: vmcs.guestSSBase(),
                                          limit: vmcs.guestSSLimit(),
                                          accessRights: vmcs.guestSSAccessRights())
            }

            if registerSet.contains(.ds), _ds == nil {
                _ds = try SegmentRegister(selector: vmcs.guestDSSelector(),
                                          base: vmcs.guestDSBase(),
                                          limit: vmcs.guestDSLimit(),
                                          accessRights: vmcs.guestDSAccessRights())
            }

            if registerSet.contains(.es), _es == nil {
                _es = try SegmentRegister(selector: vmcs.guestESSelector(),
                                          base: vmcs.guestESBase(),
                                          limit: vmcs.guestESLimit(),
                                          accessRights: vmcs.guestESAccessRights())

            }

            if registerSet.contains(.fs), _fs == nil {
                _fs = try SegmentRegister(selector: vmcs.guestFSSelector(),
                                          base: vmcs.guestFSBase(),
                                          limit: vmcs.guestFSLimit(),
                                          accessRights: vmcs.guestFSAccessRights())
            }

            if registerSet.contains(.gs), _gs == nil {
                _gs = try SegmentRegister(selector: vmcs.guestGSSelector(),
                                          base: vmcs.guestGSBase(),
                                          limit: vmcs.guestGSLimit(),
                                          accessRights: vmcs.guestGSAccessRights())
            }

            if registerSet.contains(.gdt), _gdt == nil {
                _gdt = try DescriptorTable(base: readRegister(HV_X86_GDT_BASE),
                                           limit: UInt16(readRegister(HV_X86_GDT_LIMIT)))
            }

            if registerSet.contains(.idt), _idt == nil {
                _idt = try DescriptorTable(base:readRegister(HV_X86_IDT_BASE),
                                           limit: UInt16(readRegister(HV_X86_IDT_LIMIT)))
            }

            if registerSet.contains(.ldtr), _ldtr == nil {
                _ldtr = try SegmentRegister(selector: vmcs.guestLDTRSelector(),
                                            base: vmcs.guestLDTRBase(),
                                            limit: vmcs.guestLDTRLimit(),
                                            accessRights: vmcs.guestLDTRAccessRights())
            }

            if registerSet.contains(.taskRegister), _taskRegister == nil {
                _taskRegister = try SegmentRegister(selector: vmcs.guestTRSelector(),
                                                    base: vmcs.guestTRBase(),
                                                    limit: vmcs.guestTRLimit(),
                                                    accessRights: vmcs.guestTRAccessRights())
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
            self.vcpuId = nil
            self.vmcs = nil
        }

        internal func setupRegisters() throws {
            guard let vcpuId = self.vcpuId, let vmcs = self.vmcs else {
                throw HVError.vcpuHasBeenShutdown
            }

            if updatedRegisters.contains(.cs) {
                let cs = _cs!
                try vmcs.guestCSSelector(cs.selector)
                try vmcs.guestCSBase(cs.base)
                try vmcs.guestCSLimit(cs.limit)
                try vmcs.guestCSAccessRights(cs.accessRights)
            }

            if updatedRegisters.contains(.ss) {
                let ss = _ss!
                try vmcs.guestSSSelector(ss.selector)
                try vmcs.guestSSBase(ss.base)
                try vmcs.guestSSLimit(ss.limit)
                try vmcs.guestSSAccessRights(ss.accessRights)
            }

            if updatedRegisters.contains(.ds) {
                let ds = _ds!
                try vmcs.guestDSSelector(ds.selector)
                try vmcs.guestDSBase(ds.base)
                try vmcs.guestDSLimit(ds.limit)
                try vmcs.guestDSAccessRights(ds.accessRights)
            }

            if updatedRegisters.contains(.es) {
                let es = _es!
                try vmcs.guestESSelector(es.selector)
                try vmcs.guestESBase(es.base)
                try vmcs.guestESLimit(es.limit)
                try vmcs.guestESAccessRights(es.accessRights)
            }

            if updatedRegisters.contains(.fs) {
                let fs = _fs!
                try vmcs.guestFSSelector(fs.selector)
                try vmcs.guestFSBase(fs.base)
                try vmcs.guestFSLimit(fs.limit)
                try vmcs.guestFSAccessRights(fs.accessRights)
            }

            if updatedRegisters.contains(.cs) {
                let gs = _gs!
                try vmcs.guestGSSelector(gs.selector)
                try vmcs.guestGSBase(gs.base)
                try vmcs.guestGSLimit(gs.limit)
                try vmcs.guestGSAccessRights(gs.accessRights)
            }

            if updatedRegisters.contains(.taskRegister) {
                let taskRegister = _taskRegister!
                try vmcs.guestTRSelector(taskRegister.selector)
                try vmcs.guestTRBase(taskRegister.base)
                try vmcs.guestTRLimit(taskRegister.limit)
                try vmcs.guestTRAccessRights(taskRegister.accessRights)
            }

            if updatedRegisters.contains(.ldtr) {
                let ldtr = _ldtr!
                try vmcs.guestLDTRSelector(ldtr.selector)
                try vmcs.guestLDTRBase(ldtr.base)
                try vmcs.guestLDTRLimit(ldtr.limit)
                try vmcs.guestLDTRAccessRights(ldtr.accessRights)
            }

            if updatedRegisters.contains(.gdt) {
                let gdt = _gdt!
                try hvError(hv_vcpu_write_register(vcpuId, HV_X86_GDT_BASE, gdt.base))
                try hvError(hv_vcpu_write_register(vcpuId, HV_X86_GDT_LIMIT, UInt64(gdt.limit)))
            }

            if updatedRegisters.contains(.idt) {
                let idt = _idt!
                try hvError(hv_vcpu_write_register(vcpuId, HV_X86_IDT_BASE, idt.base))
                try hvError(hv_vcpu_write_register(vcpuId, HV_X86_IDT_LIMIT, UInt64(idt.limit)))
            }

            if updatedRegisters.contains(.rflags) {
                try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RFLAGS, _rflags!.rawValue))
            }

            if updatedRegisters.contains(.rax) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RAX, _rax!)) }
            if updatedRegisters.contains(.rbx) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RBX, _rbx!)) }
            if updatedRegisters.contains(.rcx) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RCX, _rcx!)) }
            if updatedRegisters.contains(.rdx) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RDX, _rdx!)) }
            if updatedRegisters.contains(.rsi) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RSI, _rsi!)) }
            if updatedRegisters.contains(.rdi) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RDI, _rdi!)) }
            if updatedRegisters.contains(.rsp) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RSP, _rsp!)) }
            if updatedRegisters.contains(.rbp) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RBP, _rbp!)) }
            if updatedRegisters.contains(.r8)  { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R8, _r8!))   }
            if updatedRegisters.contains(.r9)  { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R9, _r9!))   }
            if updatedRegisters.contains(.r10) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R10, _r10!)) }
            if updatedRegisters.contains(.r11) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R11, _r11!)) }
            if updatedRegisters.contains(.r12) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R12, _r12!)) }
            if updatedRegisters.contains(.r13) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R13, _r13!)) }
            if updatedRegisters.contains(.r14) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R14, _r14!)) }
            if updatedRegisters.contains(.r15) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_R15, _r15!)) }
            if updatedRegisters.contains(.rip) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_RIP, _rip!)) }
            if updatedRegisters.contains(.cr0) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_CR0, _cr0!)) }
            if updatedRegisters.contains(.cr2) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_CR2, _cr2!)) }
            if updatedRegisters.contains(.cr3) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_CR3, _cr3!)) }
            if updatedRegisters.contains(.cr4) { try hvError(hv_vcpu_write_register(vcpuId, HV_X86_CR4, _cr4!)) }
            if updatedRegisters.contains(.efer) { try vmcs.guestIA32EFER(_efer!) }
        }
    }
}

#endif
