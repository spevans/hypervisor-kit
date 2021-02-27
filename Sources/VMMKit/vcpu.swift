//
//  vcpu.swift
//  VMMKit
//
//  Created by Simon Evans on 27/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import Foundation

enum VCPUStatus {
    case setup
    case waitingToStart
    case running
    case vmExit
    case shuttingDown
    case shutdown
}


public typealias VMExitHandler = ((VirtualMachine.VCPU, VMExit) throws -> Bool)

extension VirtualMachine.VCPU {

    public func shutdown() -> Bool {
        if status == .shutdown { return true }
        shutdownRequested = true
        let currentStatus = self.status
        if currentStatus == .setup || currentStatus == .waitingToStart {
            // Tell the thread to wakeup so that it can immediately exit.
            self.semaphore.signal()
        }
        for _ in 1...100 {
            if status == .shutdown { return true }
            Thread.sleep(forTimeInterval: 0.001) // 1ms
        }
        return status == .shutdown
    }
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
        registers.ss.base = 0

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


    func dumpRegisters() -> String {

        var outputString = ""
        func showReg(_ name: String, _ value: UInt16) {
            let w = hexNum(value, width: 4)
            outputString += "\(name): \(w) "
        }

        showReg("CS", self.registers.cs.selector)
        showReg("SS", self.registers.ss.selector)
        showReg("DS", self.registers.ds.selector)
        showReg("ES", self.registers.es.selector)
        showReg("FS", self.registers.fs.selector)
        showReg("GS", self.registers.gs.selector)
        outputString += "FLAGS \(self.registers.rflags)\n"

        showReg("IP", self.registers.ip)
        showReg("AX", self.registers.ax)
        showReg("BX", self.registers.bx)
        showReg("CX", self.registers.cx)
        showReg("DX", self.registers.dx)
        showReg("DI", self.registers.di)
        showReg("SI", self.registers.si)
        showReg("BP", self.registers.bp)
        showReg("SP", self.registers.sp)
        outputString += "\n"

        return outputString
    }
}
