//
//  registers.swift
//  VMMKit
//
//  Created by Simon Evans on 01/03/2021.
//  Copyright © 2021 Simon Evans. All rights reserved.
//
//  Cached VCPU registers between VMExits.
//

public struct SegmentRegister {
    public var selector: UInt16
    public var base: UInt64
    public var limit: UInt32
    public var accessRights: UInt32

    public init(selector: UInt16, base: UInt64, limit: UInt32, accessRights: UInt32) {
        self.selector = selector
        self.base = base
        self.limit = limit
        self.accessRights = accessRights
    }
}

public struct DescriptorTable {
    public var base: UInt64
    public var limit: UInt16

    public init(base: UInt64, limit: UInt16) {
        self.base = base
        self.limit = limit
    }
}

public struct RegisterSet: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let rax = RegisterSet(rawValue: 1 << 0)
    public static let rbx = RegisterSet(rawValue: 1 << 1)
    public static let rcx = RegisterSet(rawValue: 1 << 2)
    public static let rdx = RegisterSet(rawValue: 1 << 3)
    public static let rdi = RegisterSet(rawValue: 1 << 4)
    public static let rsi = RegisterSet(rawValue: 1 << 5)
    public static let rbp = RegisterSet(rawValue: 1 << 6)
    public static let rsp = RegisterSet(rawValue: 1 << 7)

    public static let r8  = RegisterSet(rawValue: 1 << 8)
    public static let r9  = RegisterSet(rawValue: 1 << 9)
    public static let r10 = RegisterSet(rawValue: 1 << 10)
    public static let r11 = RegisterSet(rawValue: 1 << 11)
    public static let r12 = RegisterSet(rawValue: 1 << 12)
    public static let r13 = RegisterSet(rawValue: 1 << 13)
    public static let r14 = RegisterSet(rawValue: 1 << 14)
    public static let r15 = RegisterSet(rawValue: 1 << 15)

    public static let rip = RegisterSet(rawValue: 1 << 16)
    public static let rflags = RegisterSet(rawValue: 1 << 17)
    public static let cr0 = RegisterSet(rawValue: 1 << 18)
    public static let cr2 = RegisterSet(rawValue: 1 << 19)
    public static let cr3 = RegisterSet(rawValue: 1 << 20)
    public static let cr4 = RegisterSet(rawValue: 1 << 21)
    public static let efer = RegisterSet(rawValue: 1 << 22)

    public static let cs  = RegisterSet(rawValue: 1 << 24)
    public static let ss  = RegisterSet(rawValue: 1 << 25)
    public static let ds  = RegisterSet(rawValue: 1 << 26)
    public static let es  = RegisterSet(rawValue: 1 << 27)
    public static let fs  = RegisterSet(rawValue: 1 << 28)
    public static let gs  = RegisterSet(rawValue: 1 << 29)
    public static let segmentRegisters: RegisterSet = [.cs, .ss, .ds, .es, .fs, .gs]

    public static let gdt = RegisterSet(rawValue: 1 << 30)
    public static let idt = RegisterSet(rawValue: 1 << 31)
    public static let ldtr = RegisterSet(rawValue: 1 << 32)
    public static let taskRegister = RegisterSet(rawValue: 1 << 33)

    public static let all = RegisterSet(rawValue: Int.max)
}

internal protocol RegisterProtocol: AnyObject {
    var cs: SegmentRegister { get set }
    var ss: SegmentRegister { get set }
    var ds: SegmentRegister { get set }
    var es: SegmentRegister { get set }
    var fs: SegmentRegister { get set }
    var gs: SegmentRegister { get set }

    // The Local Descriptor Table Register and Task Register have the same attributes
    // as Segment Registers including access rights.
    var taskRegister: SegmentRegister { get set }
    var ldtr: SegmentRegister { get set }

    var gdt: DescriptorTable { get set }
    var idt: DescriptorTable { get set }

    var rax: UInt64 { get set }
    var rbx: UInt64 { get set }
    var rcx: UInt64 { get set }
    var rdx: UInt64 { get set }
    var rsi: UInt64 { get set }
    var rdi: UInt64 { get set }
    var rsp: UInt64 { get set }
    var rbp: UInt64 { get set }
    var r8: UInt64 { get set }
    var r9: UInt64 { get set }
    var r10: UInt64 { get set }
    var r11: UInt64 { get set }
    var r12: UInt64 { get set }
    var r13: UInt64 { get set }
    var r14: UInt64 { get set }
    var r15: UInt64 { get set }
    var rip: UInt64 { get set }
    var rflags: CPU.RFLAGS { get set }
    var cr0: UInt64 { get set }
    var cr2: UInt64 { get set }
    var cr3: UInt64 { get set }
    var cr4: UInt64 { get set }
    var efer: UInt64 { get set }

    func readRegisters(_ registerSet: RegisterSet) throws
    func clearCache()
    func makeReadOnly()
    func setupRegisters() throws
}

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

    public var di: UInt16 {
        get { UInt16(truncatingIfNeeded: rdi) }
        set { rdi = (rdi & ~0xffff) | UInt64(newValue) }
    }

    public var edi: UInt32 {
        get { UInt32(truncatingIfNeeded: rdi) }
        set { rdi = (rdi & ~0xffff_ffff) | UInt64(newValue) }
    }

    public var si: UInt16 {
        get { UInt16(truncatingIfNeeded: rsi) }
        set { rsi = (rsi & ~0xffff) | UInt64(newValue) }
    }

    public var esi: UInt32 {
        get { UInt32(truncatingIfNeeded: rsi) }
        set { rsi = (rsi & ~0xffff_ffff) | UInt64(newValue) }
    }

    public var bp: UInt16 {
        get { UInt16(truncatingIfNeeded: rbp) }
        set { rbp = (rbp & ~0xffff) | UInt64(newValue) }
    }

    public var ebp: UInt32 {
        get { UInt32(truncatingIfNeeded: rbp) }
        set { rbp = (rbp & ~0xffff_ffff) | UInt64(newValue) }
    }

    public var sp: UInt16 {
        get { UInt16(truncatingIfNeeded: rsp) }
        set { rsp = (rsp & ~0xffff) | UInt64(newValue) }
    }

    public var esp: UInt32 {
        get { UInt32(truncatingIfNeeded: rsp) }
        set { rsp = (rsp & ~0xffff_ffff) | UInt64(newValue) }
    }

    public var ip: UInt16 {
        get { UInt16(truncatingIfNeeded: rip) }
        set { rip = (rip & ~0xffff) | UInt64(newValue) }
    }

    public var eip: UInt32 {
        get { UInt32(truncatingIfNeeded: rip) }
        set { rip = (rip & ~0xffff_ffff) | UInt64(newValue) }
    }
}
