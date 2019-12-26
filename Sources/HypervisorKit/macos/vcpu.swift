//
//  vcpu.swift
//  
//
//  Created by Simon Evans on 08/12/2019.
//

#if os(macOS)

import Hypervisor

extension VirtualMachine {
    
    final class VCPU {
        
        struct SegmentRegister {
            var selector: UInt16 = 0
            var base: UInt = 0
            var limit: UInt32 = 0
            var accessRights: UInt32 = 0
        }
        
        struct Registers {
            
            var cs: SegmentRegister = SegmentRegister()
            var ss: SegmentRegister = SegmentRegister()
            var ds: SegmentRegister = SegmentRegister()
            var es: SegmentRegister = SegmentRegister()
            var fs: SegmentRegister = SegmentRegister()
            var gs: SegmentRegister = SegmentRegister()
            var tr: SegmentRegister = SegmentRegister()
            var ldtr: SegmentRegister = SegmentRegister()
            
            var rax: UInt64 = 0
            var rbx: UInt64 = 0
            var rcx: UInt64 = 0
            var rdx: UInt64 = 0
            var rsi: UInt64 = 0
            var rdi: UInt64 = 0
            var rsp: UInt64 = 0
            var rbp: UInt64 = 0
            var r8: UInt64 = 0
            var r9: UInt64 = 0
            var r10: UInt64 = 0
            var r11: UInt64 = 0
            var r12: UInt64 = 0
            var r13: UInt64 = 0
            var r14: UInt64 = 0
            var r15: UInt64 = 0
            var rip: UInt64 = 0
            var rflags: CPU.RFLAGS = CPU.RFLAGS()
            var cr0: UInt64 = 0
            var cr2: UInt64 = 0
            var cr3: UInt64 = 0
            var cr4: UInt64 = 0
            var cr8: UInt64 = 0
            
            var gdtrBase: UInt64 = 0
            var gdtrLimit: UInt64 = 0
            var idtrBase: UInt64 = 0
            var idtrLimit: UInt64 = 0
            
            
            func readRegister(_ vcpuId: hv_vcpuid_t, _ register: hv_x86_reg_t) throws -> UInt64 {
                var value: UInt64 = 0
                try hvError(hv_vcpu_read_register(vcpuId, register, &value))
                return value
            }
            
            func writeRegister(_ vcpuId: hv_vcpuid_t, _ register: hv_x86_reg_t, _ value: UInt64) throws {
                try hvError(hv_vcpu_write_register(vcpuId, register, value))
            }
            
            func setupRegisters(vcpuId: hv_vcpuid_t) throws {
                try writeRegister(vcpuId, HV_X86_RAX, rax)
                try writeRegister(vcpuId, HV_X86_RBX, rbx)
                try writeRegister(vcpuId, HV_X86_RCX, rcx)
                try writeRegister(vcpuId, HV_X86_RDX, rdx)
                try writeRegister(vcpuId, HV_X86_RSI, rsi)
                try writeRegister(vcpuId, HV_X86_RDI, rdi)
                try writeRegister(vcpuId, HV_X86_RSP, rsp)
                try writeRegister(vcpuId, HV_X86_RBP, rbp)
                try writeRegister(vcpuId, HV_X86_R8, r8)
                try writeRegister(vcpuId, HV_X86_R9, r9)
                try writeRegister(vcpuId, HV_X86_R10, r10)
                try writeRegister(vcpuId, HV_X86_R11, r11)
                try writeRegister(vcpuId, HV_X86_R12, r12)
                try writeRegister(vcpuId, HV_X86_R13, r13)
                try writeRegister(vcpuId, HV_X86_R14, r14)
                try writeRegister(vcpuId, HV_X86_R15, r15)
                try writeRegister(vcpuId, HV_X86_RIP, rip)
                try writeRegister(vcpuId, HV_X86_RFLAGS, rflags.rawValue)
                try writeRegister(vcpuId, HV_X86_CR0, cr0)
                try writeRegister(vcpuId, HV_X86_CR2, cr2)
                try writeRegister(vcpuId, HV_X86_CR3, cr3)
                try writeRegister(vcpuId, HV_X86_CR4, cr4)
                try writeRegister(vcpuId, HV_X86_GDT_BASE, gdtrBase)
                try writeRegister(vcpuId, HV_X86_GDT_LIMIT, gdtrLimit)
                try writeRegister(vcpuId, HV_X86_IDT_BASE, idtrBase)
                try writeRegister(vcpuId, HV_X86_IDT_LIMIT, idtrLimit)
            }
            
            mutating func readRegisters(vcpuId: hv_vcpuid_t) throws {
                rax = try readRegister(vcpuId, HV_X86_RAX)
                rbx = try readRegister(vcpuId, HV_X86_RBX)
                rcx = try readRegister(vcpuId, HV_X86_RCX)
                rdx = try readRegister(vcpuId, HV_X86_RDX)
                rsi = try readRegister(vcpuId, HV_X86_RSI)
                rdi = try readRegister(vcpuId, HV_X86_RDI)
                rsp = try readRegister(vcpuId, HV_X86_RSP)
                rbp = try readRegister(vcpuId, HV_X86_RBP)
                r8 = try readRegister(vcpuId, HV_X86_R8)
                r9 = try readRegister(vcpuId, HV_X86_R9)
                r10 = try readRegister(vcpuId, HV_X86_R10)
                r11 = try readRegister(vcpuId, HV_X86_R11)
                r12 = try readRegister(vcpuId, HV_X86_R12)
                r13 = try readRegister(vcpuId, HV_X86_R13)
                r14 = try readRegister(vcpuId, HV_X86_R14)
                r15 = try readRegister(vcpuId, HV_X86_R15)
                rip = try readRegister(vcpuId, HV_X86_RIP)
                rflags = CPU.RFLAGS(try readRegister(vcpuId, HV_X86_RFLAGS))
                cr0 = try readRegister(vcpuId, HV_X86_CR0)
                cr2 = try readRegister(vcpuId, HV_X86_CR2)
                cr3 = try readRegister(vcpuId, HV_X86_CR3)
                cr4 = try readRegister(vcpuId, HV_X86_CR4)
                gdtrBase = try readRegister(vcpuId, HV_X86_GDT_BASE)
                gdtrLimit = try readRegister(vcpuId, HV_X86_GDT_LIMIT)
                idtrBase = try readRegister(vcpuId, HV_X86_IDT_BASE)
                idtrLimit = try readRegister(vcpuId, HV_X86_IDT_LIMIT)
            }


            func setupSegmentRegisters(vmcs: VMCS) throws {
                try vmcs.guestCSSelector(cs.selector)
                try vmcs.guestCSBase(cs.base)
                try vmcs.guestCSLimit(cs.limit)
                try vmcs.guestCSAccessRights(cs.accessRights)
                
                try vmcs.guestSSSelector(ss.selector)
                try vmcs.guestSSBase(ss.base)
                try vmcs.guestSSLimit(ss.limit)
                try vmcs.guestSSAccessRights(ss.accessRights)
                
                try vmcs.guestDSSelector(ds.selector)
                try vmcs.guestDSBase(ds.base)
                try vmcs.guestDSLimit(ds.limit)
                try vmcs.guestDSAccessRights(ds.accessRights)
                
                try vmcs.guestESSelector(es.selector)
                try vmcs.guestESBase(es.base)
                try vmcs.guestESLimit(es.limit)
                try vmcs.guestESAccessRights(es.accessRights)
                
                try vmcs.guestFSSelector(fs.selector)
                try vmcs.guestFSBase(fs.base)
                try vmcs.guestFSLimit(fs.limit)
                try vmcs.guestFSAccessRights(fs.accessRights)
                
                try vmcs.guestGSSelector(gs.selector)
                try vmcs.guestGSBase(gs.base)
                try vmcs.guestGSLimit(gs.limit)
                try vmcs.guestGSAccessRights(gs.accessRights)
                
                try vmcs.guestTRSelector(tr.selector)
                try vmcs.guestTRBase(tr.base)
                try vmcs.guestTRLimit(tr.limit)
                try vmcs.guestTRAccessRights(tr.accessRights)
                
                try vmcs.guestLDTRSelector(ldtr.selector)
                try vmcs.guestLDTRBase(ldtr.base)
                try vmcs.guestLDTRLimit(ldtr.limit)
                try vmcs.guestLDTRAccessRights(ldtr.accessRights)
            }


            mutating func readSegmentRegisters(vmcs: VMCS) throws {
                cs.selector = try vmcs.guestCSSelector()
                cs.base = try vmcs.guestCSBase()
                cs.limit = try vmcs.guestCSLimit()
                cs.accessRights = try vmcs.guestCSAccessRights()

                ss.selector = try vmcs.guestSSSelector()
                ss.base = try vmcs.guestSSBase()
                ss.limit = try vmcs.guestSSLimit()
                ss.accessRights = try vmcs.guestSSAccessRights()

                ds.selector = try vmcs.guestDSSelector()
                ds.base = try vmcs.guestDSBase()
                ds.limit = try vmcs.guestDSLimit()
                ds.accessRights = try vmcs.guestDSAccessRights()

                es.selector = try vmcs.guestESSelector()
                es.base = try vmcs.guestESBase()
                es.limit = try vmcs.guestESLimit()
                es.accessRights = try vmcs.guestESAccessRights()

                fs.selector = try vmcs.guestFSSelector()
                fs.base = try vmcs.guestFSBase()
                fs.limit = try vmcs.guestFSLimit()
                fs.accessRights = try vmcs.guestFSAccessRights()

                gs.selector = try vmcs.guestGSSelector()
                gs.base = try vmcs.guestGSBase()
                gs.limit = try vmcs.guestGSLimit()
                gs.accessRights = try vmcs.guestGSAccessRights()

            }
        }

        unowned private let vm: VirtualMachine
        var registers = Registers()
        let vcpuId: hv_vcpuid_t
        let vmcs: VMCS
        var exitCount: UInt64 = 0
        
        
        init(vm: VirtualMachine) throws {
            self.vm = vm
            var _vcpuId: hv_vcpuid_t = 0
            try hvError(hv_vcpu_create(&_vcpuId, UInt64(HV_VCPU_DEFAULT)))
            self.vcpuId = _vcpuId
            vmcs = VMCS(vcpu: vcpuId)
            
            let VMCS_PRI_PROC_BASED_CTLS_HLT       = UInt64(1 << 7)
            let VMCS_PRI_PROC_BASED_CTLS_CR8_LOAD  = UInt64(1 << 19)
            let VMCS_PRI_PROC_BASED_CTLS_CR8_STORE = UInt64(1 << 20)
            
            func cap2ctrl(_ cap: UInt64, _ ctrl: UInt64) -> UInt64 {
                return (ctrl | (cap & 0xffffffff)) & (cap >> 32)
            }
            try vmcs.pinBasedVMExecControls(UInt32(truncatingIfNeeded: cap2ctrl(VirtualMachine.vmx_cap_pinbased, 0)))
            try vmcs.primaryProcVMExecControls(UInt32(truncatingIfNeeded: cap2ctrl(VirtualMachine.vmx_cap_procbased,
                                                                                   VMCS_PRI_PROC_BASED_CTLS_HLT |
                                                                                    VMCS_PRI_PROC_BASED_CTLS_CR8_LOAD |
                VMCS_PRI_PROC_BASED_CTLS_CR8_STORE)))
            try vmcs.secondaryProcVMExecControls(UInt32(truncatingIfNeeded: cap2ctrl(VirtualMachine.vmx_cap_procbased2, 0)))
            try vmcs.vmEntryControls(UInt32(truncatingIfNeeded: cap2ctrl(VirtualMachine.vmx_cap_entry, 0)))

            
            try vmcs.exceptionBitmap(0xffffffff)
            try vmcs.cr0mask(0x60000000)
            try vmcs.cr0ReadShadow(CPU.CR0Register(0))
            try vmcs.cr4mask(0)
            try vmcs.cr4ReadShadow(CPU.CR4Register(0))
        }
        
        func run() throws -> VMExit {
            print("About to eun with RIP:", String(registers.rip, radix: 16), "RAX:", String(registers.rax, radix: 16))
            print("VMCS RIP:", String(try vmcs.guestRIP(), radix: 16))

            while true {
                try registers.setupRegisters(vcpuId: vcpuId)
                try registers.setupSegmentRegisters(vmcs: vmcs)
                try hvError(hv_vcpu_run(vcpuId))
                try registers.readRegisters(vcpuId: vcpuId)
                try registers.readSegmentRegisters(vmcs: vmcs)

                exitCount += 1
                guard let exitReason = try vmExit() else { continue }

                // FIXME: Determine why first vmexit is an EPT violation
                if exitCount == 1,
                    case let .memoryViolation(violation) = exitReason {
                    if violation.access == .instructionFetch && !violation.executable {
                        // Ignore instructionFetch on exectable memory, EPT cold start
                        // skip
                        continue
                    }
                }
                return exitReason
            }
        }
        
        func skipInstruction() throws {
            let instrLen = try vmcs.vmExitInstructionLength()
            print("instrLen:", instrLen)
            registers.rip += UInt64(instrLen)
        }
/*
        func readInstructionBytes() throws -> X86Instruction {

            let length = try vmcs.vmExitInstructionLength()
            let physicalAddr = UInt64(registers.cs.base) + registers.rip
            print("Reading \(length) bytes @ \(String(physicalAddr, radix: 16))")
            let instruction = try vm.readMemory(at: physicalAddr, count: Int(length))
            var decoder = Decoder(cpuMode: .realMode, bytes: instruction)
            return try decoder.decode()
        }
        */
        func shutdown() throws {
            try hvError(hv_vcpu_destroy(vcpuId))
        }


        // Read from Segment:[{R,E},SI]
        private func readStringUnit(selector: SegmentRegister, addressWidth: Int, dataWidth: Int) throws -> VMExit.DataWrite {
            switch addressWidth {
                case 16:
                    var rsi = registers.rsi
                    var si = UInt16(truncatingIfNeeded: rsi)
                    let physicalAddress = PhysicalAddress(selector.base) + UInt(si)
                    let ptr = try vm.memory(at: physicalAddress, count: dataWidth)
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
        
        
        private func vmExit() throws -> VMExit? {
            let exitReason = try vmcs.exitReason()
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

                        default:
                            fatalError("\(exitReason): \(interruptInfo) not implmented")
                }

                case .externalINT:
                    let interruptInfo = try vmcs.vmExitInterruptionInfo()
                    switch interruptInfo.interruptType {
                        case .external:
                            let errorCode = interruptInfo.errorCodeValid ? try vmcs.vmExitInterruptionErrorCode() : nil
                            guard let eInfo = VMExit.ExceptionInfo(exception: UInt32(interruptInfo.vector), errorCode: errorCode) else {
                                fatalError("Bad exception \(interruptInfo)")
                            }
                            return .exception(eInfo)

                        default:
                            fatalError("\(exitReason): \(interruptInfo) not implmented")
                }

                case .tripleFault: fallthrough
                case .initSignal: fallthrough
                case .startupIPI: fallthrough
                case .ioSMI: fallthrough
                case .otherSMI: fallthrough
                case .intWindow: fallthrough
                case .nmiWindow: fallthrough
                case .taskSwitch: fallthrough
                case .cpuid: fallthrough
                case .getsec: fatalError("\(exitReason) not implemented")
                
                case .hlt:
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
                case .drAccess: fatalError("\(exitReason) not implemented")
                
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

                        print("bitWidth:", bitWidth, "isIn:", isIn, "port:", port)
                        print("INS/OUTS: addressSize:", addressSize, "segmentRegister:", segmentOverride)


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


                        //  let lma = LogicalMemoryAccess(addressSize: addressSize, segmentRegister: seg, register: .rsi)
                        //  let linearAddress = self.linearAddress(lma)!
                        //  let physicalAddress = self.physicalAddress(for: linearAddress)!
                        //  print("Physical Address:", physicalAddress)

                        let rcx = registers.rcx
                        var count: UInt64 = {
                            guard isRep else { return 1 }
                            if addressSize == 16 { return rcx & 0xffff }
                            if addressSize == 32 { return rcx & 0xffff_fffff }
                            return rcx
                        }()
                        print("Count:", count)

                        if isRep && count == 0 {
                            try skipInstruction()
                            return nil
                        }

                        if isIn {
                            if let dataRead = VMExit.DataRead(bitWidth: bitWidth) {
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
                            }
                            return .ioOutOperation(port, data)
                        }
                    }

                    if isIn {
                        if let dataRead = VMExit.DataRead(bitWidth: bitWidth) {
                            return .ioInOperation(port, dataRead)
                        }
                    } else {
                        if let dataWrite = VMExit.DataWrite(bitWidth: bitWidth, value: registers.rax) {
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
                case .vmentryFaileMCE: fallthrough
                case .tprBelowThreshold: fallthrough
                case .apicAccess: fallthrough
                case .virtualisedEOI: fallthrough
                case .accessToGDTRorIDTR: fallthrough
                case .accessToLDTRorTR: fatalError("\(exitReason) not implemented")

                case .eptViolation:
                    let exitQ = BitArray64(UInt64(try vmcs.exitQualification()))
                    print("RIP:", String(registers.rip, radix: 16))
                    print("exitQ:", String(exitQ.rawValue, radix: 2))
                    let access: VMExit.MemoryViolation.Access
                    if exitQ[0] == 1 {
                        access = .read
                    } else if exitQ[2] == 1 {
                        access = .instructionFetch
                    } else {
                        access = .write
                    }

                    let violation = VMExit.MemoryViolation(
                        access: access,
                        readable: exitQ[3] == 1,
                        writeable: exitQ[4] == 1,
                        executable: exitQ[5] == 1,
                        guestPhysicalAddress: try vmcs.guestPhysicalAddress(),
                        guestLinearAddress: (exitQ[7] == 1) ? try vmcs.guestLinearAddress() : nil
                    )

                    return .memoryViolation(violation)


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
                case .envls: fallthrough
                case .rdseed: fallthrough
                case .pmlFull: fallthrough
                case .xsaves: fallthrough
                case .xrstors: fallthrough
                case .subPagePermissionEvent: fallthrough
                case .umwait: fallthrough
                case .tpause: fatalError("\(exitReason) not implemented")

            }
        }
    }
}


#endif
