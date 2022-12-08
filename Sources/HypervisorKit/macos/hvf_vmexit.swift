//
//  hvf_vmexit.swift
//  HypervisorKit
//
//  Created by Simon Evans on 26/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

#if os(macOS)
@_implementationOnly import CHypervisorKit
import BABAB
import Logging

extension VirtualMachine.VCPU {

    // Read from Segment:[{R,E},SI]
    // TODO check for page access/address wrap/crossing any boundaries
    private func readStringUnit(selector: SegmentRegister, addressWidth: Int, data: VMExit.DataRead) throws -> VMExit.DataWrite {
        try registers.registerCacheControl.readRegisters([.rsi, .rflags])
        let ptr: UnsafeRawPointer

        switch addressWidth {
            case 16:
                var rsi = registers.rsi
                var si = UInt16(truncatingIfNeeded: rsi)
                let physicalAddress = PhysicalAddress(selector.base) + UInt(si)
                let bytes = UInt16(data.bytes)
                ptr = UnsafeRawPointer(try vm.memory(at: physicalAddress, count: UInt64(bytes)))
                si = registers.rflags.direction ? si &- bytes : si &+ bytes
                rsi &= ~UInt64(0xffff)
                rsi |= UInt64(si)
                registers.rsi = rsi

            default: fatalError("Cant handle: \(addressWidth)")
        }

        switch data {
            case .byte: return .byte(ptr.load(as: UInt8.self))
            case .word: return .word(ptr.unalignedLoad(as: UInt16.self))
            case .dword: return .dword(ptr.unalignedLoad(as: UInt32.self))
            case .qword: return .qword(ptr.unalignedLoad(as: UInt64.self))
        }
    }

    // Write to Segment:[{R,E},DI]
    private func writeStringUnit(selector: SegmentRegister, addressWidth: Int, data: VMExit.DataWrite) throws {
        try registers.registerCacheControl.readRegisters([.rdi, .rflags])
        let ptr: UnsafeMutableRawPointer

        switch addressWidth {
            case 16:
                var rdi = registers.rdi
                var di = UInt16(truncatingIfNeeded: rdi)
                let physicalAddress = PhysicalAddress(selector.base) + UInt(di)
                let bytes = UInt16(data.bytes)
                ptr = try vm.memory(at: physicalAddress, count: UInt64(bytes))
                di = registers.rflags.direction ? di &- bytes : di &+ bytes
                rdi &= ~UInt64(0xffff)
                rdi |= UInt64(di)
                registers.rdi = rdi

            default: fatalError("Cant handle: \(addressWidth)")
        }

        switch data {
            case .byte(let value):
                ptr.storeBytes(of: value, as: UInt8.self)

            case .word(let value):
                ptr.unalignedStoreBytes(of: value, toByteOffset: 0, as: UInt16.self)

            case .dword(let value):
                ptr.unalignedStoreBytes(of: value, toByteOffset: 0, as: UInt32.self)

            case .qword(let value):
                ptr.unalignedStoreBytes(of: value, toByteOffset: 0, as: UInt64.self)
            }
    }


    internal func vmExit() throws -> VMExit? {
        let exitReason = try vmcs.exitReason()
        if vm.logger.logLevel <= Logger.Level.trace {
            try registers.registerCacheControl.readRegisters(.rip)
            vm.logger.trace("vmExit: \(exitReason.exitReason), rip: 0x\(String(registers.rip, radix: 16))")
        }

        switch exitReason.exitReason {
            case .exceptionOrNMI:
                let interruptInfo = try vmcs.vmExitInterruptionInfo()
                switch interruptInfo.interruptType {
                    case .hardwareException:
                        let errorCode = interruptInfo.errorCodeValid ? try vmcs.vmExitInterruptionErrorCode() : nil
                        guard let eInfo = VMExit.ExceptionInfo(exception: UInt32(interruptInfo.vector), errorCode: errorCode) else {
                            fatalError("Bad exception \(interruptInfo)")
                        }
                        return .exception(eInfo)

                    case .softwareException:
                        if interruptInfo.vector == 0x03 {
                            return nil  // ignore software breakpoint
                        }
                        fallthrough

                    default:
                        fatalError("\(exitReason): \(interruptInfo) not implmented")
                }

            case .externalINT:
                // External interrupts just cause a VMexit but there is nothing to process here
                return nil  // ignore it

            case .cpuid:
                try self.emulateCpuid()
                return nil

            case .tripleFault: fallthrough
            case .initSignal: fallthrough
            case .startupIPI: fallthrough
            case .ioSMI: fallthrough
            case .otherSMI: fallthrough
            case .intWindow: fallthrough
            case .nmiWindow: fallthrough
            case .taskSwitch: fallthrough
            case .getsec: fatalError("VMExit handler for '\(exitReason.exitReason)' not implemented")

            case .hlt:
                hltState = true
                try skipInstruction()
                // Pass the hlt up to the virtual machine manager for further processing.
                return VMExit.hlt

            case .invd: fallthrough
            case .invlpg: fallthrough
            case .rdpmc: fallthrough
            case .rdtsc: fallthrough
            case .rsm: fallthrough
            case .vmcall: fallthrough
            case .vmclear: fallthrough
            case .vmlaunch: fallthrough
            case .vmptrld: fallthrough
            case .vmptrst: fallthrough
            case .vmread: fallthrough
            case .vmresume: fallthrough
            case .vmwrite: fallthrough
            case .vmxoff: fallthrough
            case .vmxon: fallthrough
            case .crAccess: fallthrough
            case .drAccess: fatalError("VMExit handler for '\(exitReason.exitReason)' not implemented")

            case .ioInstruction:
                try self.pioInstruction()
                return nil

            case .vmentryFailInvalidGuestState:
                // This will only occur is there is a bug.
                var reason = ""
                do {
                    try vmcs.checkFieldsAreValid()
                } catch {
                    reason = ": \(error)"
                }
                fatalError("Invalid guest state\(reason)")

            case .rdmsr: fallthrough
            case .wrmsr: fallthrough
            case .vmentryFailMSRLoading: fallthrough
            case .mwait: fallthrough
            case .monitorTrapFlag: fallthrough
            case .monitor: fallthrough
            case .pause: fallthrough
            case .vmentryFailMCE: fallthrough
            case .tprBelowThreshold: fallthrough
            case .apicAccess: fallthrough
            case .virtualisedEOI: fallthrough
            case .accessToGDTRorIDTR: fallthrough
            case .accessToLDTRorTR:
                fatalError("\(exitReason.exitReason) not implemented")

            case .eptViolation:
                // Check for page access / write setting dirty bit
                let exitQ = BitField64(UInt64(try vmcs.exitQualification()))
                let access: VMExit.MemoryViolation.Access
                if exitQ[0] {
                    access = .read
                } else if exitQ[2] {
                    access = .instructionFetch
                } else {
                    access = .write
                }

                let gpa = try vmcs.guestPhysicalAddress()
                if let region = vm.memoryRegion(containing: gpa) {
                    switch access {
                        case .write:
                            // set the dirty bit for the page and ignore this vmexit
                            if !region.isAddressWritable(gpa: gpa) {
                                try skipInstruction()
                            } else {
                                region.setWriteTo(address: gpa)
                            }
                            return nil

                        case .instructionFetch:
                            // ignore
                            return nil

                        case .read:
                            // Read in a valid memory region, just ignore
                            return nil
                    }
                } else {
                    // Non memory region, treat as MMIO
                    switch access {
                        case .write:
                            try emulateInstruction()
                            return nil

                        case .read:
                            try emulateInstruction()
                            return nil

                        case .instructionFetch:
                            let registers = try readRegisters([.cs, .rip])
                            // Instruction fetch to MMIO - TODO - decide how to handle this properly.
                            let linear = registers.cs.base + registers.rip
                            let addr = "CS:RIP: \(registers.cs.selector.hex()):\(registers.rip.hex()): \(linear.hex())"
                            vm.logger.error("EPT violation, instruction fetch on unmapped memory @ \(gpa), \(addr)")
                            try skipInstruction()
                            return nil
                    }
                }

            case .eptMisconfiguration: fallthrough
            case .invept: fallthrough
            case .rdtscp: fallthrough
            case .vmxPreemptionTimerExpired: fallthrough
            case .invvpid: fallthrough
            case .wbinvd: fallthrough
            case .xsetbv: fallthrough
            case .apicWrite: fallthrough
            case .rdrand: fallthrough
            case .invpcid : fallthrough
            case .vmfunc: fallthrough
            case .encls: fallthrough
            case .rdseed: fallthrough
            case .pmlFull: fallthrough
            case .xsaves: fallthrough
            case .xrstors: fallthrough
            case .subPagePermissionEvent: fallthrough
            case .umwait: fallthrough
            case .tpause: fatalError("\(exitReason.exitReason) not implemented")

        }
    }

    private func pioInstruction() throws {
        let exitQ = BitField64(UInt64(try vmcs.exitQualification()))

        let bitWidth = 8 * (UInt8(exitQ[0...2]) + 1)
        let isIn = Bool(exitQ[3])
        let isString = Bool(exitQ[4])
        let port = UInt16(exitQ[16...31])

        if isString {
            let isRep = Bool(exitQ[5])

            let exitInfo = BitField32(try vmcs.vmExitInstructionInfo())
            let addressSize = 16 << exitInfo[7...9]
            let segmentOverride = isIn ? .ds : LogicalMemoryAccess.SegmentRegister(rawValue: Int(exitInfo[15...17]))!
            try registers.registerCacheControl.readRegisters([.segmentRegisters, .rcx, .rflags])

            let segReg: SegmentRegister = {
                switch segmentOverride {
                    case .es: return registers.es
                    case .cs: return registers.cs
                    case .ss: return registers.ss
                    case .ds: return registers.ds
                    case .fs: return registers.fs
                    case .gs: return registers.gs
                }
            }()

            let rcx = registers.rcx
            var count: UInt64 = {
                guard isRep else { return 1 }
                if addressSize == 16 { return rcx & 0xffff }
                if addressSize == 32 { return rcx & 0xffff_fffff }
                return rcx
            }()

            if isRep && count == 0 {
                try skipInstruction()
                return
            }

            let counterChange: UInt64 = {
                guard isRep else { return 0 }
                if self.registers.rflags.direction {
                    return 1
                } else {
                    return UInt64.max   // Will use unchecked &+ to simulate -1
                }
            }()

            let dataRead = VMExit.DataRead(bitWidth: bitWidth)!

            if isIn {
                var a: [VMExit.DataWrite] = []
                a.reserveCapacity(Int(count))
                while count > 0 {
                    let write = try self.vm.pioInHandler!(port, dataRead)
                    a.append(write)
                    try writeStringUnit(selector: segReg, addressWidth: 16, data: write)
                    count -= 1
                    registers.rcx &+= counterChange
                }
            } else {
                while count > 0 {
                    let dataWrite = try readStringUnit(selector: segReg, addressWidth: 16, data: dataRead)
                    try self.vm.pioOutHandler!(port, dataWrite)
                    count -= 1
                    registers.rcx &+= counterChange
                }
            }
            try skipInstruction()
            return
        }

        if isIn {
            if let dataRead = VMExit.DataRead(bitWidth: bitWidth) {
                let write = try self.vm.pioInHandler!(port, dataRead)
                try registers.registerCacheControl.readRegisters(.rax)
                switch write {
                    case .byte(let value): registers.al = value
                    case .word(let value): registers.ax = value
                    case .dword(let value): registers.eax = value
                    case .qword(_): fatalError("Invalid PIO width")
                }
                try skipInstruction()
            }
        } else {
            try registers.registerCacheControl.readRegisters(.rax)
            if let dataWrite = VMExit.DataWrite(bitWidth: bitWidth, value: registers.rax) {
                try self.vm.pioOutHandler!(port, dataWrite)
                try skipInstruction()
            }
        }
    }

    func emulateCpuid() throws {
        let registers = try readRegisters([.rax, .rbx, .rcx, .rdx])
        let eax = registers.eax
        let ecx = registers.ecx
        var result = cpuid_result()
        cpuid2(eax, ecx, &result)
        registers.eax = result.regs.eax
        registers.ebx = result.regs.ebx
        registers.ecx = result.regs.ecx
        registers.edx = result.regs.edx
        try skipInstruction()
    }
}

#endif
