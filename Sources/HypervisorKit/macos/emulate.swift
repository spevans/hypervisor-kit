//
//  emulate.swift
//  HypervisorKit
//
//  Created by Simon Evans on 30/07/2022.
//  Copyright © 2022 Simon Evans. All rights reserved.
//
//  Emulate a CPU instruction used for MMIO.
//

#if os(macOS)

import BABAB

extension VirtualMachine.VCPU {
    func emulateInstruction() throws {
        let instrLen = try vmcs.vmExitInstructionLength()
        precondition(instrLen <= 15)
        try registers.registerCacheControl.readRegisters(.rip)
        let gpa = try vmcs.guestPhysicalAddress()

        let cr0 = try vmcs.guestCR0()

        let rip = try vmcs.guestCSBase() + registers.rip
        let ripGpa: UInt64
        if cr0.paging {
            ripGpa = translateAddress(rip)
        } else {
            ripGpa = registers.rip
        }
        vm.logger.debug("RIP: \(registers.rip.hex()) => \(ripGpa.hex())")

        // Read the instruction
        let pointer = try vm.memory(at: PhysicalAddress(ripGpa), count: UInt64(instrLen))
        let buffer = UnsafeRawBufferPointer(start: pointer, count: Int(instrLen))
        let instruction = Array<UInt8>(buffer)
        vm.logger.debug("instruction: \(hexDump(instruction, startAddress: ripGpa))")

        switch instruction[0] {
            case 0xa1 where instrLen == 5: // mov eax, 32bit address
                let addr = UnsafeRawPointer(pointer).unalignedLoad(fromByteOffset: 1, as: UInt32.self)
                precondition(PhysicalAddress(UInt64(addr)) == gpa)
                let result = try self.mmioRead(gpa: gpa, operation: .dword)
                switch result {
                    case .dword(let value):
                        vm.logger.debug("Read value: \(value.hex())")
                        try registers.registerCacheControl.readRegisters(.rax)
                        registers.eax = value
                    default: break
                }

            case 0xa3 where instrLen == 5: //
                let addr = UnsafeRawPointer(pointer).unalignedLoad(fromByteOffset: 1, as: UInt32.self)
                precondition(PhysicalAddress(UInt64(addr)) == gpa)
                try registers.registerCacheControl.readRegisters(.rax)
                try self.mmioWrite(gpa: gpa, operation: .dword(registers.eax))

            case 0xc7 where instruction[1] == 0x5 && instrLen == 10:
                let addr = UnsafeRawPointer(pointer).unalignedLoad(fromByteOffset: 2, as: UInt32.self)
                let value = UnsafeRawPointer(pointer).unalignedLoad(fromByteOffset: 6, as: UInt32.self)
                precondition(PhysicalAddress(UInt64(addr)) == gpa)
                try self.mmioWrite(gpa: gpa, operation: .dword(value))

            default: fatalError("Unimplemented instruction")
        }
        registers.rip += UInt64(instrLen)

        return
    }

    func translateAddress(_ address: UInt64) -> UInt64 {
        fatalError("todo")
    }


    private func mmioRead(gpa: PhysicalAddress, operation: VMExit.DataRead) throws -> VMExit.DataWrite {
        if gpa.value >= 0xfee00000, gpa.value <= 0xfee01000 {
            return apicRead(gpa: gpa, operation: operation)
        }
        let result = try self.vm.mmioInHandler!(gpa, operation)
        guard operation.bitWidth == result.bitWidth else {
            fatalError("MMIOIn GPA: \(gpa) bitWidth mismatch, requested \(operation) result: \(operation))")
        }
        return result
    }

    private func mmioWrite(gpa: PhysicalAddress, operation: VMExit.DataWrite) throws {
        if gpa.value >= 0xfee00000, gpa.value <= 0xfee01000 {
            return apicWrite(gpa: gpa, operation: operation)
        }
        try self.vm.mmioOutHandler!(gpa, operation)
    }


    private func apicRead(gpa: PhysicalAddress, operation: VMExit.DataRead) -> VMExit.DataWrite {
        guard operation == .dword else {
            vm.logger.error("APIC read @ \(gpa) not 32bit: \(operation)")
            return .dword(UInt32.max)
        }
        switch gpa.value {
            case 0xfee000f0: return .dword(apicSVR)
            case 0xfee00300: return .dword(apicLoIcr)
            case 0xfee00310: return .dword(apicHiIcr)
            case 0xfee00350: return .dword(apicLint0)
            case 0xfee00360: return .dword(apicLint1)
            default: fatalError("apicRead unhandled GPA: \(gpa)")
        }
    }


    private func apicWrite(gpa: PhysicalAddress, operation: VMExit.DataWrite) {
        guard case let .dword(value) = operation else {
            self.vm.logger.error("APIC read @ \(gpa) not 32bit: \(operation)")
            return
        }
        switch gpa.value {
            case 0xfee000f0: apicSVR = value
            case 0xfee00300: apicLoIcr = value
            case 0xfee00310: apicHiIcr = value
            case 0xfee00350: apicLint0 = value
            case 0xfee00360: apicLint1 = value
            default: fatalError("apicRead unhandled GPA: \(gpa)")
        }
    }
}

#endif
