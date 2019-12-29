//
//  vcpu.swift
//  
//
//  Created by Simon Evans on 27/12/2019.
//


extension VirtualMachine.VCPU.Registers {
    public var al: UInt8 {
        get { UInt8(truncatingIfNeeded: rax) }
        set { rax = (rax & ~0xff) | UInt64(newValue) }
    }

    public var ah: UInt8 {
        get { UInt8(truncatingIfNeeded: rax >> 8) }
        set { rax = (rax & ~0xff00) | (UInt64(newValue) << 8) }
    }

    public var ax: UInt16 {
        get { UInt16(truncatingIfNeeded: rax) }
        set { rax = (rax & ~0xffff) | UInt64(newValue) }
    }

    public var eax: UInt32 {
        get { UInt32(truncatingIfNeeded: rax) }
        set { rax = (rax & ~0xffff_ffff) | UInt64(newValue) }
    }


    public var bl: UInt8 {
        get { UInt8(truncatingIfNeeded: rbx) }
        set { rbx = (rbx & ~0xff) | UInt64(newValue) }
    }

    public var bh: UInt8 {
        get { UInt8(truncatingIfNeeded: rbx >> 8) }
        set { rbx = (rbx & ~0xff00) | (UInt64(newValue) << 8) }
    }

    public var bx: UInt16 {
        get { UInt16(truncatingIfNeeded: rbx) }
        set { rbx = (rbx & ~0xffff) | UInt64(newValue) }
    }

    public var ebx: UInt32 {
        get { UInt32(truncatingIfNeeded: rbx) }
        set { rbx = (rbx & ~0xffff_ffff) | UInt64(newValue) }
    }

    public var cl: UInt8 {
        get { UInt8(truncatingIfNeeded: rcx) }
        set { rcx = (rcx & ~0xff) | UInt64(newValue) }
    }

    public var ch: UInt8 {
        get { UInt8(truncatingIfNeeded: rcx >> 8) }
        set { rcx = (rcx & ~0xff00) | (UInt64(newValue) << 8) }
    }

    public var cx: UInt16 {
        get { UInt16(truncatingIfNeeded: rcx) }
        set { rcx = (rcx & ~0xffff) | UInt64(newValue) }
    }

    public var ecx: UInt32 {
        get { UInt32(truncatingIfNeeded: rcx) }
        set { rcx = (rcx & ~0xffff_ffff) | UInt64(newValue) }
    }

    public var dl: UInt8 {
        get { UInt8(truncatingIfNeeded: rdx) }
        set { rdx = (rdx & ~0xff) | UInt64(newValue) }
    }

    public var dh: UInt8 {
        get { UInt8(truncatingIfNeeded: rdx >> 8) }
        set { rdx = (rdx & ~0xff00) | (UInt64(newValue) << 8) }
    }

    public var dx: UInt16 {
        get { UInt16(truncatingIfNeeded: rdx) }
        set { rdx = (rdx & ~0xffff) | UInt64(newValue) }
    }

    public var edx: UInt32 {
        get { UInt32(truncatingIfNeeded: rdx) }
        set { rdx = (rdx & ~0xffff_ffff) | UInt64(newValue) }
    }

}

extension VirtualMachine.VCPU {

    public func setupRealMode() {
        registers.cr0 = CPU.CR0Register(0x60000030).value
        registers.cr2 = 0
        registers.cr3 = CPU.CR3Register(0).value
        registers.cr4 = CPU.CR4Register(0x2000).value

        registers.rip = 0xFFF0
        registers.rflags = CPU.RFLAGS(2)
        registers.rsp = 0x0
        registers.rax = 0x0

        registers.cs.selector = 0xf000
        registers.cs.limit = 0xffff
        registers.cs.accessRights = 0x9b
        registers.cs.base = 0xf0000

        registers.ds.selector = 0
        registers.ds.limit = 0xffff
        registers.ds.accessRights = 0x93
        registers.ds.base = 0

        registers.es.selector = 0
        registers.es.limit = 0xffff
        registers.es.accessRights = 0x93
        registers.es.base = 0

        registers.fs.selector = 0
        registers.fs.limit = 0xffff
        registers.fs.accessRights = 0x93
        registers.fs.base = 0

        registers.gs.selector = 0
        registers.gs.limit = 0xffff
        registers.gs.accessRights = 0x93
        registers.gs.base = 0

        registers.ss.selector = 0
        registers.ss.limit = 0xffff
        registers.ss.accessRights = 0x93
        registers.ds.base = 0

        registers.tr.selector = 0
        registers.tr.limit = 0
        registers.tr.accessRights = 0x83
        registers.tr.base = 0

        registers.ldtr.selector = 0
        registers.ldtr.limit = 0
        registers.ldtr.accessRights = 0x10000
        registers.ldtr.base = 0

        registers.gdtrBase = 0
        registers.gdtrLimit = 0xffff
        registers.idtrBase = 0
        registers.idtrLimit = 0xffff
    }
}
