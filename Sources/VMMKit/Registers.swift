//
//  Registers.swift
//  VMMKit
//
//  Created by Simon Evans on 01/03/2021.
//  Copyright © 2021 Simon Evans. All rights reserved.
//
//  Cached VCPU registers between VMExits.
//


/// A type that provides access to the individual components of a Segment Register.
public struct SegmentRegister {

    /// The  selector value loaded into the Segment Register.
    /// In real mode, this is the base address of the segment.
    public var selector: UInt16

    /// The logical base address of the segment.
    public var base: UInt64

    /// The limit of the segment in bytes.
    public var limit: UInt32

    /// The access rights and attributes of the selector.
    public var accessRights: UInt32

    public init(selector: UInt16, base: UInt64, limit: UInt32, accessRights: UInt32) {
        self.selector = selector
        self.base = base
        self.limit = limit
        self.accessRights = accessRights
    }
}


/// A type that provides access to the individual components of a Descriptor Table.
/// Used by the GDT (Global Descriptor Table) and IDT (Interrupt Descriptor Table).
public struct DescriptorTable {

    /// The logical base address of the table.
    public var base: UInt64

    /// The limit of the table in bytes.
    public var limit: UInt16

    public init(base: UInt64, limit: UInt16) {
        self.base = base
        self.limit = limit
    }
}

extension VirtualMachine.VCPU {

    /// Access to the vCPU register set. This acts as a cache of the register and segment register values,
    /// to avoid excess operating system calls to read the values from the vm subsystem.
    /// When the vCPU has finished executing, the `VCPU.registers` holds the final
    /// register values of the vCPU.
    public final class Registers {

        internal var registerCacheControl: RegisterCacheControl

        /// Initialise an empty set of registers, used before first vCPU run.
        internal init(registerCacheControl: RegisterCacheControl) {
            self.registerCacheControl = registerCacheControl
        }

        /// The AL register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rax` in the `RegisterSet`.
        public var al: UInt8 {
            get { UInt8(truncatingIfNeeded: rax) }
            set { rax = (rax & ~0xff) | UInt64(newValue) }
        }

        /// The AH register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rax` in the `RegisterSet`.
        public var ah: UInt8 {
            get { UInt8(truncatingIfNeeded: rax >> 8) }
            set { rax = (rax & ~0xff00) | (UInt64(newValue) << 8) }
        }

        /// The AX register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rax` in the `RegisterSet`.
        public var ax: UInt16 {
            get { UInt16(truncatingIfNeeded: rax) }
            set { rax = (rax & ~0xffff) | UInt64(newValue) }
        }

        /// The EAX register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rax` in the `RegisterSet`.
        public var eax: UInt32 {
            get { UInt32(truncatingIfNeeded: rax) }
            set { rax = (rax & ~0xffff_ffff) | UInt64(newValue) }
        }

        /// The BL register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rax` in the `RegisterSet`.
        public var bl: UInt8 {
            get { UInt8(truncatingIfNeeded: rbx) }
            set { rbx = (rbx & ~0xff) | UInt64(newValue) }
        }

        /// The BH register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rbx` in the `RegisterSet`.
        public var bh: UInt8 {
            get { UInt8(truncatingIfNeeded: rbx >> 8) }
            set { rbx = (rbx & ~0xff00) | (UInt64(newValue) << 8) }
        }

        /// The BX register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rbx` in the `RegisterSet`.
        public var bx: UInt16 {
            get { UInt16(truncatingIfNeeded: rbx) }
            set { rbx = (rbx & ~0xffff) | UInt64(newValue) }
        }

        /// The EBX register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rbx` in the `RegisterSet`.
        public var ebx: UInt32 {
            get { UInt32(truncatingIfNeeded: rbx) }
            set { rbx = (rbx & ~0xffff_ffff) | UInt64(newValue) }
        }

        /// The CL register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rcx` in the `RegisterSet`.
        public var cl: UInt8 {
            get { UInt8(truncatingIfNeeded: rcx) }
            set { rcx = (rcx & ~0xff) | UInt64(newValue) }
        }

        /// The CH register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rcx` in the `RegisterSet`.
        public var ch: UInt8 {
            get { UInt8(truncatingIfNeeded: rcx >> 8) }
            set { rcx = (rcx & ~0xff00) | (UInt64(newValue) << 8) }
        }

        /// The CX register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rcx` in the `RegisterSet`.
        public var cx: UInt16 {
            get { UInt16(truncatingIfNeeded: rcx) }
            set { rcx = (rcx & ~0xffff) | UInt64(newValue) }
        }

        /// The ECX register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rcx` in the `RegisterSet`.
        public var ecx: UInt32 {
            get { UInt32(truncatingIfNeeded: rcx) }
            set { rcx = (rcx & ~0xffff_ffff) | UInt64(newValue) }
        }

        /// The DL register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rdx` in the `RegisterSet`.
        public var dl: UInt8 {
            get { UInt8(truncatingIfNeeded: rdx) }
            set { rdx = (rdx & ~0xff) | UInt64(newValue) }
        }

        /// The DH register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rdx` in the `RegisterSet`.
        public var dh: UInt8 {
            get { UInt8(truncatingIfNeeded: rdx >> 8) }
            set { rdx = (rdx & ~0xff00) | (UInt64(newValue) << 8) }
        }

        /// The DX register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rdx` in the `RegisterSet`.
        public var dx: UInt16 {
            get { UInt16(truncatingIfNeeded: rdx) }
            set { rdx = (rdx & ~0xffff) | UInt64(newValue) }
        }

        /// The EDX register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rdx` in the `RegisterSet`.
        public var edx: UInt32 {
            get { UInt32(truncatingIfNeeded: rdx) }
            set { rdx = (rdx & ~0xffff_ffff) | UInt64(newValue) }
        }

        /// The DI register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rdi` in the `RegisterSet`.
        public var di: UInt16 {
            get { UInt16(truncatingIfNeeded: rdi) }
            set { rdi = (rdi & ~0xffff) | UInt64(newValue) }
        }

        /// The EDI register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rdi` in the `RegisterSet`.
        public var edi: UInt32 {
            get { UInt32(truncatingIfNeeded: rdi) }
            set { rdi = (rdi & ~0xffff_ffff) | UInt64(newValue) }
        }

        /// The SI register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rsi` in the `RegisterSet`.
        public var si: UInt16 {
            get { UInt16(truncatingIfNeeded: rsi) }
            set { rsi = (rsi & ~0xffff) | UInt64(newValue) }
        }

        /// The ESI register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rsi` in the `RegisterSet`.
        public var esi: UInt32 {
            get { UInt32(truncatingIfNeeded: rsi) }
            set { rsi = (rsi & ~0xffff_ffff) | UInt64(newValue) }
        }

        /// The BP register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rbp` in the `RegisterSet`.
        public var bp: UInt16 {
            get { UInt16(truncatingIfNeeded: rbp) }
            set { rbp = (rbp & ~0xffff) | UInt64(newValue) }
        }

        /// The EBP register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rbp` in the `RegisterSet`.
        public var ebp: UInt32 {
            get { UInt32(truncatingIfNeeded: rbp) }
            set { rbp = (rbp & ~0xffff_ffff) | UInt64(newValue) }
        }

        /// The SP register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rsp` in the `RegisterSet`.
        public var sp: UInt16 {
            get { UInt16(truncatingIfNeeded: rsp) }
            set { rsp = (rsp & ~0xffff) | UInt64(newValue) }
        }

        /// The ESP register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rsp` in the `RegisterSet`.
        public var esp: UInt32 {
            get { UInt32(truncatingIfNeeded: rsp) }
            set { rsp = (rsp & ~0xffff_ffff) | UInt64(newValue) }
        }

        /// The IP register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rip` in the `RegisterSet`.
        public var ip: UInt16 {
            get { UInt16(truncatingIfNeeded: rip) }
            set { rip = (rip & ~0xffff) | UInt64(newValue) }
        }

        /// The EIP register value in the vCPU.
        ///
        /// Reading or writing this value requires calling `readRegisters` with `.rip` in the `RegisterSet`.
        public var eip: UInt32 {
            get { UInt32(truncatingIfNeeded: rip) }
            set { rip = (rip & ~0xffff_ffff) | UInt64(newValue) }
        }

        /// The CS SegmentRegister value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.cs` in the `RegisterSet`.
        public var cs: SegmentRegister {
            get { registerCacheControl.cache._cs! }
            set { registerCacheControl.cache._cs = newValue; registerCacheControl.cache.updatedRegisters.insert(.cs) }
        }

        /// The SS SegmentRegister value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.ss` in the `RegisterSet`.
        public var ss: SegmentRegister {
            get { registerCacheControl.cache._ss! }
            set { registerCacheControl.cache._ss = newValue; registerCacheControl.cache.updatedRegisters.insert(.ss) }
        }

        /// The DS SegmentRegister value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.ds` in the `RegisterSet`.
        public var ds: SegmentRegister {
            get { registerCacheControl.cache._ds! }
            set { registerCacheControl.cache._ds = newValue; registerCacheControl.cache.updatedRegisters.insert(.ds) }
        }

        /// The ES SegmentRegister value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.es` in the `RegisterSet`.
        public var es: SegmentRegister {
            get { registerCacheControl.cache._es! }
            set { registerCacheControl.cache._es = newValue; registerCacheControl.cache.updatedRegisters.insert(.es) }
        }

        /// The FS SegmentRegister value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.fs` in the `RegisterSet`.
        public var fs: SegmentRegister {
            get { registerCacheControl.cache._fs! }
            set { registerCacheControl.cache._fs = newValue; registerCacheControl.cache.updatedRegisters.insert(.fs) }
        }

        /// The GS SegmentRegister value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.gs` in the `RegisterSet`.
        public var gs: SegmentRegister {
            get { registerCacheControl.cache._gs! }
            set { registerCacheControl.cache._gs = newValue; registerCacheControl.cache.updatedRegisters.insert(.gs) }
        }

        /// The TR (TaskRegister)  value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.taskRegister` in the `RegisterSet`.
        public var taskRegister: SegmentRegister {
            get { registerCacheControl.cache._taskRegister! }
            set { registerCacheControl.cache._taskRegister = newValue; registerCacheControl.cache.updatedRegisters.insert(.taskRegister) }
        }

        /// The LDTR (Local Descriptor Table Register) value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.ldtr` in the `RegisterSet`.
        public var ldtr: SegmentRegister {
            get { registerCacheControl.cache._ldtr! }
            set { registerCacheControl.cache._ldtr = newValue; registerCacheControl.cache.updatedRegisters.insert(.ldtr) }
        }

        /// The GDT (Global Descriptor Table)  value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.gdt` in the `RegisterSet`.
        public var gdt: DescriptorTable {
            get { registerCacheControl.cache._gdt! }
            set { registerCacheControl.cache._gdt = newValue; registerCacheControl.cache.updatedRegisters.insert(.gdt) }
        }

        /// The IDT (Interrupt Descriptor Table)  value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.idt` in the `RegisterSet`.
        public var idt: DescriptorTable {
            get { registerCacheControl.cache._idt! }
            set { registerCacheControl.cache._idt = newValue; registerCacheControl.cache.updatedRegisters.insert(.idt) }
        }

        /// The CPU Flags value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.rflags` in the `RegisterSet`.
        public var rflags: CPU.RFLAGS {
            get { registerCacheControl.cache._rflags! }
            set { registerCacheControl.cache._rflags = newValue; registerCacheControl.cache.updatedRegisters.insert(.rflags) }
        }

        /// The RAX register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.rax` in the `RegisterSet`.
        public var rax: UInt64 {
            get { registerCacheControl.cache._rax! }
            set { registerCacheControl.cache._rax = newValue; registerCacheControl.cache.updatedRegisters.insert(.rax) }
        }

        /// The RBX register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.rbx` in the `RegisterSet`.
        public var rbx: UInt64 {
            get { registerCacheControl.cache._rbx! }
            set { registerCacheControl.cache._rbx = newValue; registerCacheControl.cache.updatedRegisters.insert(.rbx) }
        }

        /// The RCX register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.rcx` in the `RegisterSet`.
        public var rcx: UInt64 {
            get { registerCacheControl.cache._rcx! }
            set { registerCacheControl.cache._rcx = newValue; registerCacheControl.cache.updatedRegisters.insert(.rcx) }
        }

        /// The RDX register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.radx` in the `RegisterSet`.
        public var rdx: UInt64 {
            get { registerCacheControl.cache._rdx! }
            set { registerCacheControl.cache._rdx = newValue; registerCacheControl.cache.updatedRegisters.insert(.rdx) }
        }

        /// The RDI register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.rdi` in the `RegisterSet`.
        public var rdi: UInt64 {
            get { registerCacheControl.cache._rdi! }
            set { registerCacheControl.cache._rdi = newValue; registerCacheControl.cache.updatedRegisters.insert(.rdi) }
        }

        /// The RSI register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.rsi` in the `RegisterSet`.
        public var rsi: UInt64 {
            get { registerCacheControl.cache._rsi! }
            set { registerCacheControl.cache._rsi = newValue; registerCacheControl.cache.updatedRegisters.insert(.rsi) }
        }

        /// The RBP register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.rbp` in the `RegisterSet`.
        public var rbp: UInt64 {
            get { registerCacheControl.cache._rbp! }
            set { registerCacheControl.cache._rbp = newValue; registerCacheControl.cache.updatedRegisters.insert(.rbp) }
        }

        /// The RSP register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.rsp` in the `RegisterSet`.
        public var rsp: UInt64 {
            get { registerCacheControl.cache._rsp! }
            set { registerCacheControl.cache._rsp = newValue; registerCacheControl.cache.updatedRegisters.insert(.rsp) }
        }

        /// The R8 register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.r8` in the `RegisterSet`.
        public var r8: UInt64 {
            get { registerCacheControl.cache._r8! }
            set { registerCacheControl.cache._r8 = newValue; registerCacheControl.cache.updatedRegisters.insert(.r8) }
        }

        /// The R9 register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.r9` in the `RegisterSet`.
        public var r9: UInt64 {
            get { registerCacheControl.cache._r9! }
            set { registerCacheControl.cache._r9 = newValue; registerCacheControl.cache.updatedRegisters.insert(.r9) }
        }

        /// The R10 register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.r10` in the `RegisterSet`.
        public var r10: UInt64 {
            get { registerCacheControl.cache._r10! }
            set { registerCacheControl.cache._r10 = newValue; registerCacheControl.cache.updatedRegisters.insert(.r10) }
        }

        /// The R11 register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.r11` in the `RegisterSet`.
        public var r11: UInt64 {
            get { registerCacheControl.cache._r11! }
            set { registerCacheControl.cache._r11 = newValue; registerCacheControl.cache.updatedRegisters.insert(.r11) }
        }

        /// The R12 register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.r12` in the `RegisterSet`.
        public var r12: UInt64 {
            get { registerCacheControl.cache._r12! }
            set { registerCacheControl.cache._r12 = newValue; registerCacheControl.cache.updatedRegisters.insert(.r12) }
        }

        /// The R13 register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.r13` in the `RegisterSet`.
        public var r13: UInt64 {
            get { registerCacheControl.cache._r13! }
            set { registerCacheControl.cache._r13 = newValue; registerCacheControl.cache.updatedRegisters.insert(.r13) }
        }

        /// The R14 register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.r14` in the `RegisterSet`.
        public var r14: UInt64 {
            get { registerCacheControl.cache._r14! }
            set { registerCacheControl.cache._r14 = newValue; registerCacheControl.cache.updatedRegisters.insert(.r14) }
        }

        /// The R15 register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.r15` in the `RegisterSet`.
        public var r15: UInt64 {
            get { registerCacheControl.cache._r15! }
            set { registerCacheControl.cache._r15 = newValue; registerCacheControl.cache.updatedRegisters.insert(.r15) }
        }

        /// The RIP register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.rip` in the `RegisterSet`.
        public var rip: UInt64 {
            get { registerCacheControl.cache._rip! }
            set { registerCacheControl.cache._rip = newValue; registerCacheControl.cache.updatedRegisters.insert(.rip) }
        }

        /// The CR0 register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.cr0` in the `RegisterSet`.
        public var cr0: UInt64 {
            get { registerCacheControl.cache._cr0! }
            set { registerCacheControl.cache._cr0 = newValue; registerCacheControl.cache.updatedRegisters.insert(.cr0) }
        }

        /// The CR2 register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.cr2` in the `RegisterSet`.
        public var cr2: UInt64 {
            get { registerCacheControl.cache._cr2! }
            set { registerCacheControl.cache._cr2 = newValue; registerCacheControl.cache.updatedRegisters.insert(.cr2) }
        }

        /// The CR3 register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.cr3` in the `RegisterSet`.
        public var cr3: UInt64 {
            get { registerCacheControl.cache._cr3! }
            set { registerCacheControl.cache._cr3 = newValue; registerCacheControl.cache.updatedRegisters.insert(.cr3) }
        }

        /// The CR4 register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.cr4` in the `RegisterSet`.
        public var cr4: UInt64 {
            get { registerCacheControl.cache._cr4! }
            set { registerCacheControl.cache._cr4 = newValue; registerCacheControl.cache.updatedRegisters.insert(.cr4) }
        }

        /// The EFER register value in the vCPU.
        ///
        /// Reading this value requires calling `readRegisters` with `.efer` in the `RegisterSet`.
        public var efer: UInt64 {
            get { registerCacheControl.cache._efer! }
            set { registerCacheControl.cache._efer = newValue; registerCacheControl.cache.updatedRegisters.insert(.efer) }
        }
    }
}
