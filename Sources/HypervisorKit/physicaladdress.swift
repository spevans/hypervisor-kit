//
//  PhysicalAddress.swift
//  HypervisorKit
//
//  Created by Simon Evans on 14/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import BABAB

public typealias RawAddress = UInt64
//typealias VirtualAddress = UInt64
public typealias LinearAddress = UInt64


let PAGE_SIZE = 4096
let PAGE_MASK = PAGE_SIZE - 1

public struct PhysicalAddress: Comparable, Hashable, CustomStringConvertible  {
    let rawValue: RawAddress
    var value: UInt64 { rawValue }

    public var description: String {
        return "0x\(String(rawValue, radix: 16))"
    }

    public init(_ rawValue: UInt64) {
        self.rawValue = RawAddress(rawValue)
    }

    public init(_ rawValue: UInt) {
        self.rawValue = RawAddress(rawValue)
    }

    public func isAligned(to size: Int) -> Bool {
        precondition(size.nonzeroBitCount == 1)
        return rawValue & (RawAddress(size) - 1) == 0
    }

    public func advanced(by n: Int) -> PhysicalAddress {
        return PhysicalAddress(rawValue + RawAddress(n))
    }

    public func advanced(by n: UInt) -> PhysicalAddress {
        return PhysicalAddress(rawValue + RawAddress(n))
    }

    public func advanced(by n: UInt64) -> PhysicalAddress {
        return PhysicalAddress(rawValue + RawAddress(n))
    }

    public func distance(to n: PhysicalAddress) -> Int {
        if n.rawValue > rawValue {
            return Int(n.rawValue - rawValue)
        } else {
            return Int(rawValue - n.rawValue)
        }
    }

    public static func +(lhs: PhysicalAddress, rhs: UInt) -> PhysicalAddress {
        return lhs.advanced(by: rhs)
    }

    public static func +(lhs: PhysicalAddress, rhs: Int) -> PhysicalAddress {
        return lhs.advanced(by: rhs)
    }

    public static func +(lhs: PhysicalAddress, rhs: UInt64) -> PhysicalAddress {
        return lhs.advanced(by: rhs)
    }

    public static func -(lhs: PhysicalAddress, rhs: UInt) -> PhysicalAddress {
        return PhysicalAddress(lhs.rawValue - RawAddress(rhs))
    }

    public static func -(lhs: PhysicalAddress, rhs: PhysicalAddress) -> Int {
        return lhs.distance(to: rhs)
    }

    public static func <(lhs: PhysicalAddress, rhs: PhysicalAddress) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    public static func <=(lhs: PhysicalAddress, rhs: PhysicalAddress) -> Bool {
        return lhs.rawValue <= rhs.rawValue
    }
}



struct LogicalMemoryAccess {

    enum SegmentRegister: Int {
        case es = 0
        case cs = 1
        case ss = 2
        case ds = 3
        case fs = 4
        case gs = 5
    }

    enum Register: Int {
        case rax = 0
        case rcx = 1
        case rdx = 2
        case rbx = 3
        case rsp = 4
        case rbp = 5
        case rsi = 6
        case rdi = 7
        case r8 = 8
        case r9 = 9
        case r10 = 10
        case r11 = 11
        case r12 = 12
        case r13 = 13
        case r14 = 14
        case r15 = 15
    }

    // The bit layout is taken from the VM-Exit Instruction Information Field
    private let value: BitField32
    var rawValue: UInt32 { value.rawValue }

    var scaling: Int? { value[22] ? nil : 1 << Int(value[0...1]) }
    var addressSize: Int { 16 << Int(value[7...9]) }    // 16, 32, 64
    var segmentRegister: SegmentRegister { SegmentRegister(rawValue: Int(value[15...17]))! }
    var indexRegister: Register? { value[22] ? nil : Register(rawValue: Int(value[18...21])) }
    var baseRegister: Register? { value[27] ? nil : Register(rawValue: Int(value[23...26])) }

/*
    // FIXME: Take paging and GDT/LDT into account
    func physicalAddress(using registers: VirtualMachine.VCPU.Registers ) -> PhysicalAddress {
        let baseAddress: PhysicalAddress
        switch segmentRegister {
            case .cs: baseAddress = Physical(registers.cs.base)
            case .ss: baseAddress = Physical(registers.cs.base)
            case .ds: baseAddress = Physical(registers.ds.base)
            case .es: baseAddress = Physical(registers.es.base)
            case .fs: baseAddress = Physical(registers.fs.base)
            case .gs: baseAddress = Physical(registers.gs.base)
        }

    }
*/

    init(addressSize: Int, segmentRegister: SegmentRegister, register: Register) {
        precondition([16, 32, 64].contains(addressSize))

        var tmp = BitField32()
        tmp[7...9] = UInt32(addressSize >> 5)
        tmp[15...17] = UInt32(segmentRegister.rawValue)

        // No Index register
        tmp[22] = true

        // Base Register
        tmp[23...26] = UInt32(register.rawValue)
        tmp[27] = false
        value = tmp
    }

    init(rawValue: UInt32) {
        value = BitField32(rawValue)
    }
}

// Addresses Logical => Linear => Physical

extension VirtualMachine.VCPU {

    func linearAddress(_ memory: LogicalMemoryAccess) throws -> LinearAddress? {
        // FIXME: Asssumes real mode for now
        // FIXME: Check for overflow / wraparound/ unrealmode
        // FIXME: Check segment access rights / limits

        try registers.registerCacheControl.readRegisters(.all)
        let segmentRegister: SegmentRegister
        switch memory.segmentRegister {
            case .cs: segmentRegister = registers.cs
            case .ds: segmentRegister = registers.ds
            case .es: segmentRegister = registers.es
            case .fs: segmentRegister = registers.fs
            case .gs: segmentRegister = registers.gs
            case .ss: segmentRegister = registers.ss
        }


        var offset = LinearAddress(0)
        if let baseReg = memory.baseRegister {
            switch baseReg {
                case .rax:  offset = registers.rax
                case .rbx:  offset = registers.rbx
                case .rcx:  offset = registers.rcx
                case .rdx:  offset = registers.rdx
                case .rsi:  offset = registers.rsi
                case .rdi:  offset = registers.rdi
                case .rbp:  offset = registers.rbp
                case .rsp:  offset = registers.rsp
                case .r8:   offset = registers.r8
                case .r9:   offset = registers.r9
                case .r10:  offset = registers.r10
                case .r11:  offset = registers.r11
                case .r12:  offset = registers.r12
                case .r13:  offset = registers.r13
                case .r14:  offset = registers.r14
                case .r15:  offset = registers.r15
            }
        }

        if let scaling = memory.scaling, let indexReg = memory.indexRegister {
            let scaling = UInt64(scaling)
            switch indexReg {
                case .rax:  offset += (registers.rax * scaling)
                case .rbx:  offset += (registers.rbx * scaling)
                case .rcx:  offset += (registers.rcx * scaling)
                case .rdx:  offset += (registers.rdx * scaling)
                case .rsi:  offset += (registers.rsi * scaling)
                case .rdi:  offset += (registers.rdi * scaling)
                case .rbp:  offset += (registers.rbp * scaling)
                case .rsp:  offset += (registers.rsp * scaling)
                case .r8:   offset += (registers.r8  * scaling)
                case .r9:   offset += (registers.r9  * scaling)
                case .r10:  offset += (registers.r10 * scaling)
                case .r11:  offset += (registers.r11 * scaling)
                case .r12:  offset += (registers.r12 * scaling)
                case .r13:  offset += (registers.r13 * scaling)
                case .r14:  offset += (registers.r14 * scaling)
                case .r15:  offset += (registers.r15 * scaling)
            }
        }
        let cr0 = CPU.CR0Register(registers.cr0)
        if cr0.protectionEnable {
            fatalError("Logical To Linear not impleneted for Protected mode")
        }
        // Realmode lookup
        return LinearAddress(segmentRegister.base) + offset
    }


    func physicalAddress(for laddr: LinearAddress) throws -> PhysicalAddress? {
        try registers.registerCacheControl.readRegisters(.cr0)
        let cr0 = CPU.CR0Register(registers.cr0)
        if !cr0.paging {
            // No paging, Physical Address = Linear Address
            return PhysicalAddress(laddr)
        }
        fatalError("Page table lookup not implemented")
    }
}
