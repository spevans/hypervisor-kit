//
//  vcpu.swift
//  VMMKit
//
//  Created by Simon Evans on 27/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import Foundation

public typealias VMExitHandler = ((VirtualMachine.VCPU, VMExit) throws -> Bool)

internal protocol VCPUProtocol: AnyObject {
    var vm: VirtualMachine { get }
    var registers: VirtualMachine.VCPU.Registers { get }
    var vmExitHandler: VMExitHandler { get set }
    var completionHandler: (() -> ())? { get set }

    func readRegisters(_: RegisterSet) throws -> VirtualMachine.VCPU.Registers
    func start() throws
    func shutdown() -> Bool
    func skipInstruction() throws
    func setIn(data: VMExit.DataWrite)
    func queue(irq: UInt8)
    func clearPendingIRQ()
}

enum VCPUStatus {
    case setup
    case waitingToStart
    case running
    case vmExit
    case shuttingDown
    case shutdown
}


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

    public func setupRealMode() {
        vm.logger.debug("setupRealMode()")
        vm.logger.debug("setupRealMode(), registers: \(registers)")
        registers.cr0 = CPU.CR0Register(0x60000030).value
        registers.cr2 = 0
        registers.cr3 = CPU.CR3Register(0).value
        registers.cr4 = CPU.CR4Register(0x2000).value

        registers.rip = 0xFFF0
        registers.rflags = CPU.RFLAGS(2)
        registers.rsp = 0x0
        registers.rax = 0x0

        registers.cs = SegmentRegister(selector: 0xf000, base: 0xf0000, limit: 0xffff, accessRights: 0x9b)
        registers.ds = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0xffff, accessRights: 0x93)

        registers.es = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0xffff, accessRights: 0x93)
        registers.fs = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0xffff, accessRights: 0x93)
        registers.gs = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0xffff, accessRights: 0x93)
        registers.ss = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0xffff, accessRights: 0x93)

        registers.taskRegister = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0x0000, accessRights: 0x83)
        registers.ldtr = SegmentRegister(selector: 0x0000, base: 0x00000, limit: 0x0000, accessRights: 0x10000)

        registers.gdt = DescriptorTable(base: 0, limit: 0xffff)
        registers.idt = DescriptorTable(base: 0, limit: 0xffff)
    }


    func dumpRegisters() throws -> String {

        var outputString = ""
        func showReg(_ name: String, _ value: UInt16) {
            let w = hexNum(value, width: 4)
            outputString += "\(name): \(w) "
        }

        try registers.readRegisters(.all)
        showReg("CS", registers.cs.selector)
        showReg("SS", registers.ss.selector)
        showReg("DS", registers.ds.selector)
        showReg("ES", registers.es.selector)
        showReg("FS", registers.fs.selector)
        showReg("GS", registers.gs.selector)
        outputString += "FLAGS \(registers.rflags)\n"

        showReg("IP", registers.ip)
        showReg("AX", registers.ax)
        showReg("BX", registers.bx)
        showReg("CX", registers.cx)
        showReg("DX", registers.dx)
        showReg("DI", registers.di)
        showReg("SI", registers.si)
        showReg("BP", registers.bp)
        showReg("SP", registers.sp)
        outputString += "\n"

        return outputString
    }
}
