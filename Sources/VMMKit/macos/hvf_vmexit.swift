//
//  hvf_vmexit.swift
//  VMMKit
//
//  Created by Simon Evans on 26/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

#if os(macOS)
import CBits
import Logging

extension VirtualMachine.VCPU {

    // Read from Segment:[{R,E},SI]
    private func readStringUnit(selector: SegmentRegister, addressWidth: Int, dataWidth: Int) throws -> VMExit.DataWrite {
        switch addressWidth {
            case 16:
                try registers.readRegisters([.rsi, .rflags])
                var rsi = registers.rsi
                var si = UInt16(truncatingIfNeeded: rsi)
                let physicalAddress = PhysicalAddress(selector.base) + UInt(si)
                let ptr = try vm.memory(at: physicalAddress, count: UInt64(dataWidth))
                let bytes = UInt16(dataWidth / 8)
                si = registers.rflags.direction ? si &- bytes : si &+ bytes
                rsi &= ~UInt64(0xffff)
                rsi |= UInt64(si)
                registers.rsi = rsi

                switch dataWidth {
                    case 8: return .byte(ptr.load(as: UInt8.self))
                    case 16:
                        // Check for alignment
                        if physicalAddress.isAligned(to: MemoryLayout<UInt16>.size) {
                            return .word(ptr.load(as: UInt16.self))
                        } else {
                            return .word(unaligned_load16(ptr))
                        }
                    case 32:
                        if physicalAddress.isAligned(to: MemoryLayout<UInt32>.size) {
                            return .dword(ptr.load(as: UInt32.self))
                        } else {
                            return .dword(unaligned_load32(ptr))
                        }
                    default: fatalError("bad width")
            }
            default: fatalError("Cant handle: \(addressWidth)")
        }
    }


    internal func vmExit() throws -> VMExit? {
        let exitReason = try vmcs.exitReason()
        if vm.logger.logLevel <= Logger.Level.trace {
            try registers.readRegisters(.rip)
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

            case .tripleFault: fallthrough
            case .initSignal: fallthrough
            case .startupIPI: fallthrough
            case .ioSMI: fallthrough
            case .otherSMI: fallthrough
            case .intWindow: fallthrough
            case .nmiWindow: fallthrough
            case .taskSwitch: fallthrough
            case .cpuid: fallthrough
            case .getsec: fatalError("VMExit handler for '\(exitReason.exitReason)' not implemented")

            case .hlt:
                try skipInstruction()
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
                let exitQ = BitArray64(UInt64(try vmcs.exitQualification()))

                let bitWidth = 8 * (UInt8(exitQ[0...2]) + 1)
                let isIn = Bool(exitQ[3])
                let isString = Bool(exitQ[4])
                let port = UInt16(exitQ[16...31])

                if isString {
                    let isRep = Bool(exitQ[5])

                    let exitInfo = BitArray32(try vmcs.vmExitInstructionInfo())
                    let addressSize = 16 << exitInfo[7...9]
                    let segmentOverride = isIn ? .ds : LogicalMemoryAccess.SegmentRegister(rawValue: Int(exitInfo[15...17]))!
                    try registers.readRegisters([.segmentRegisters, .rcx])

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
                        return nil
                    }

                    if isIn {
                        if let dataRead = VMExit.DataRead(bitWidth: bitWidth) {
                            if !isRep { try skipInstruction() }
                            return .ioInOperation(port, dataRead)
                        }
                    } else {
                        let data = try readStringUnit(selector: segReg, addressWidth: 16, dataWidth: Int(bitWidth))

                        if isRep {
                            count -= 1
                            if addressSize == 16 {
                                registers.rcx = (rcx & ~0xffff) | count
                            } else if addressSize == 32 {
                                registers.rcx = (rcx & ~0xffff_ffff) | count
                            } else {
                                registers.rcx = count
                            }
                        } else {
                            try skipInstruction()
                        }
                        return .ioOutOperation(port, data)
                    }
                }

                if isIn {
                    if let dataRead = VMExit.DataRead(bitWidth: bitWidth) {
                        self.dataRead = dataRead
                        try skipInstruction()
                        return .ioInOperation(port, dataRead)
                    }
                } else {
                    try registers.readRegisters(.rax)
                    if let dataWrite = VMExit.DataWrite(bitWidth: bitWidth, value: registers.rax) {
                        try skipInstruction()
                        return .ioOutOperation(port, dataWrite)
                    }
                }
                fatalError("Cant process .ioInstruction")


            case .rdmsr: fallthrough
            case .wrmsr: fallthrough
            case .vmentryFailInvalidGuestState: fallthrough
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
                let exitQ = BitArray64(UInt64(try vmcs.exitQualification()))
                let access: VMExit.MemoryViolation.Access
                if exitQ[0] == 1 {
                    access = .read
                } else if exitQ[2] == 1 {
                    access = .instructionFetch
                } else {
                    access = .write
                }

                let gpa = try vmcs.guestPhysicalAddress()
                if let region = vm.memoryRegion(containing: gpa) {
                    switch access {
                        case .write:
                            // set the dirty bit for the page and ignore this vmexit
                            region.setWriteTo(address: gpa)
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
                            let write = VMExit.DataWrite(bitWidth: 8, value: 0)!
                            return .mmioWriteOperation(gpa, write)

                        case .read:
                            let read = VMExit.DataRead(bitWidth: 8)!
                            return .mmioReadOperation(gpa, read)

                        case .instructionFetch:
                            // Instruction fetch to MMIO
                            let violation = VMExit.MemoryViolation(
                                access: access,
                                readable: exitQ[3] == 1,
                                writeable: exitQ[4] == 1,
                                executable: exitQ[5] == 1,
                                guestPhysicalAddress: gpa,
                                guestLinearAddress: (exitQ[7] == 1) ? try vmcs.guestLinearAddress() : nil
                            )
                            return .memoryViolation(violation)
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
}

#endif
