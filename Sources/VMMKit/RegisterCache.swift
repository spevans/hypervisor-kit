//
//  RegisterCache.swift
//  VMMKit
//
//  Created by Simon Evans on 22/03/2021.
//  Copyright © 2021 Simon Evans. All rights reserved.
//
//  Internal data for caching vCPU register values.


// For per OS implementation.
internal protocol RegisterCacheControlProtocol {
    mutating func readRegisters(_ registerSet: RegisterSet) throws
    mutating func setupRegisters() throws
    mutating func clearCache()
    mutating func makeReadOnly()
}


// Underlying cache of registers initially set to nil until read from the
// vCPU or set.
internal struct RegisterCache {
    internal var updatedRegisters = RegisterSet()

    internal var _cs: SegmentRegister?
    internal var _ds: SegmentRegister?
    internal var _es: SegmentRegister?
    internal var _fs: SegmentRegister?
    internal var _gs: SegmentRegister?
    internal var _ss: SegmentRegister?
    internal var _taskRegister: SegmentRegister?
    internal var _ldtr: SegmentRegister?
    internal var _gdt: DescriptorTable?
    internal var _idt: DescriptorTable?
    internal var _rflags: CPU.RFLAGS?

    internal var _rax: UInt64?
    internal var _rbx: UInt64?
    internal var _rcx: UInt64?
    internal var _rdx: UInt64?
    internal var _rsi: UInt64?
    internal var _rdi: UInt64?
    internal var _rsp: UInt64?
    internal var _rbp: UInt64?
    internal var _r8: UInt64?
    internal var _r9: UInt64?
    internal var _r10: UInt64?
    internal var _r11: UInt64?
    internal var _r12: UInt64?
    internal var _r13: UInt64?
    internal var _r14: UInt64?
    internal var _r15: UInt64?
    internal var _rip: UInt64?
    internal var _cr0: UInt64?
    internal var _cr2: UInt64?
    internal var _cr3: UInt64?
    internal var _cr4: UInt64?
    internal var _efer: UInt64?
}
