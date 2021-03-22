//
//  RegisterSet.swift
//  VMMKit
//
//  Created by Simon Evans on 22/03/2021.
//  Copyright © 2021 Simon Evans. All rights reserved.
//

/// A RegisterSet is used to tell the VCPU the registers to read into an internal cache between VMExits.
/// Reading from and writing to registers in the VCPU is an expensive operation and this allows specifiying
/// just the registers that are required to be accessed when processing a VMExit.
public struct RegisterSet: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Passed in an option set to `readRegisters()` to cache the RAX register from the vCPU.
    public static let rax = RegisterSet(rawValue: 1 << 0)

    /// Passed in an option set to `readRegisters()` to cache the RBX register from the vCPU.
    public static let rbx = RegisterSet(rawValue: 1 << 1)

    /// Passed in an option set to `readRegisters()` to cache the RCX register from the vCPU.
    public static let rcx = RegisterSet(rawValue: 1 << 2)

    /// Passed in an option set to `readRegisters()` to cache the RDX register from the vCPU.
    public static let rdx = RegisterSet(rawValue: 1 << 3)

    /// Passed in an option set to `readRegisters()` to cache the RDI register from the vCPU.
    public static let rdi = RegisterSet(rawValue: 1 << 4)

    /// Passed in an option set to `readRegisters()` to cache the RSI register from the vCPU.
    public static let rsi = RegisterSet(rawValue: 1 << 5)

    /// Passed in an option set to `readRegisters()` to cache the RBP register from the vCPU.
    public static let rbp = RegisterSet(rawValue: 1 << 6)

    /// Passed in an option set to `readRegisters()` to cache the RSP register from the vCPU.
    public static let rsp = RegisterSet(rawValue: 1 << 7)

    /// Passed in an option set to `readRegisters()` to cache the R8 register from the vCPU.
    public static let r8  = RegisterSet(rawValue: 1 << 8)

    /// Passed in an option set to `readRegisters()` to cache the R9 register from the vCPU.
    public static let r9  = RegisterSet(rawValue: 1 << 9)

    /// Passed in an option set to `readRegisters()` to cache the R10 register from the vCPU.
    public static let r10 = RegisterSet(rawValue: 1 << 10)

    /// Passed in an option set to `readRegisters()` to cache the R11 register from the vCPU.
    public static let r11 = RegisterSet(rawValue: 1 << 11)

    /// Passed in an option set to `readRegisters()` to cache the R12 register from the vCPU.
    public static let r12 = RegisterSet(rawValue: 1 << 12)

    /// Passed in an option set to `readRegisters()` to cache the R13 register from the vCPU.
    public static let r13 = RegisterSet(rawValue: 1 << 13)

    /// Passed in an option set to `readRegisters()` to cache the R14 register from the vCPU.
    public static let r14 = RegisterSet(rawValue: 1 << 14)

    /// Passed in an option set to `readRegisters()` to cache the R15 register from the vCPU.
    public static let r15 = RegisterSet(rawValue: 1 << 15)

    /// Passed in an option set to `readRegisters()` to cache the RIP register from the vCPU.
    public static let rip = RegisterSet(rawValue: 1 << 16)

    /// Passed in an option set to `readRegisters()` to cache the RFLAGS from the vCPU.
    public static let rflags = RegisterSet(rawValue: 1 << 17)

    /// Passed in an option set to `readRegisters()` to cache the CR0 register from the vCPU.
    public static let cr0 = RegisterSet(rawValue: 1 << 18)

    /// Passed in an option set to `readRegisters()` to cache the CR2 register from the vCPU.
    public static let cr2 = RegisterSet(rawValue: 1 << 19)

    /// Passed in an option set to `readRegisters()` to cache the CR3 register from the vCPU.
    public static let cr3 = RegisterSet(rawValue: 1 << 20)

    /// Passed in an option set to `readRegisters()` to cache the CR4 register from the vCPU.
    public static let cr4 = RegisterSet(rawValue: 1 << 21)

    /// Passed in an option set to `readRegisters()` to cache the EFER value from the vCPU.
    public static let efer = RegisterSet(rawValue: 1 << 22)

    /// Passed in an option set to `readRegisters()` to cache the CS register from the vCPU.
    public static let cs  = RegisterSet(rawValue: 1 << 24)

    /// Passed in an option set to `readRegisters()` to cache the SS register from the vCPU.
    public static let ss  = RegisterSet(rawValue: 1 << 25)

    /// Passed in an option set to `readRegisters()` to cache the DS register from the vCPU.
    public static let ds  = RegisterSet(rawValue: 1 << 26)

    /// Passed in an option set to `readRegisters()` to cache the ES register from the vCPU.
    public static let es  = RegisterSet(rawValue: 1 << 27)

    /// Passed in an option set to `readRegisters()` to cache the FS register from the vCPU.
    public static let fs  = RegisterSet(rawValue: 1 << 28)

    /// Passed in an option set to `readRegisters()` to cache the GS register from the vCPU.
    public static let gs  = RegisterSet(rawValue: 1 << 29)

    /// Passed in an option set to `readRegisters()` to cache all of the segment registers from the vCPU.
    public static let segmentRegisters: RegisterSet = [.cs, .ss, .ds, .es, .fs, .gs]

    /// Passed in an option set to `readRegisters()` to cache the GDT (Global Descriptor Table) from the vCPU.
    public static let gdt = RegisterSet(rawValue: 1 << 30)

    /// Passed in an option set to `readRegisters()` to cache the IDT (Interrup Descriptor Table) from the vCPU.
    public static let idt = RegisterSet(rawValue: 1 << 31)

    /// Passed in an option set to `readRegisters()` to cache the LDTR (Local Descriptor Table Register) from the vCPU.
    public static let ldtr = RegisterSet(rawValue: 1 << 32)

    /// Passed in an option set to `readRegisters()` to cache the TR (Task Register) from the vCPU.
    public static let taskRegister = RegisterSet(rawValue: 1 << 33)

    /// Passed in an option set to `readRegisters()` to cache the all of the registers from the vCPU.
    public static let all = RegisterSet(rawValue: Int.max)
}
