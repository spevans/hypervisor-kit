//
//  macos.swift
//  
//
//  Created by Simon Evans on 01/12/2019.
//

#if os(macOS)

import Hypervisor

enum HVError: Error {
    case error(hv_return_t)
    case noMemory
}

func hvError(_ error: hv_return_t) throws {
    guard error == HV_SUCCESS else {
        throw HVError.error(error)
    }
}


class VirtualMachine {


    static private(set) var vmx_cap_pinbased: UInt64 = 0
    static private(set) var vmx_cap_procbased: UInt64 = 0
    static private(set) var vmx_cap_procbased2: UInt64 = 0
    static private(set) var vmx_cap_entry: UInt64 = 0



    struct VCPU {

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
            var rflags: UInt64 = 0
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
                try writeRegister(vcpuId, HV_X86_RFLAGS, rflags)
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
            }


            func setupSegmentRegisters(vmcs: VMCS) {
                vmcs.guestCSSelector = cs.selector
                vmcs.guestCSBase = cs.base
                vmcs.guestCSLimit = cs.limit
                vmcs.guestCSAccessRights = cs.accessRights

                vmcs.guestSSSelector = ss.selector
                vmcs.guestSSBase = ss.base
                vmcs.guestSSLimit = ss.limit
                vmcs.guestSSAccessRights = ss.accessRights

                vmcs.guestDSSelector = ds.selector
                vmcs.guestDSBase = ds.base
                vmcs.guestDSLimit = ds.limit
                vmcs.guestDSAccessRights = ds.accessRights

                vmcs.guestESSelector = es.selector
                vmcs.guestESBase = es.base
                vmcs.guestESLimit = es.limit
                vmcs.guestESAccessRights = es.accessRights

                vmcs.guestFSSelector = fs.selector
                vmcs.guestFSBase = fs.base
                vmcs.guestFSLimit = fs.limit
                vmcs.guestFSAccessRights = fs.accessRights

                vmcs.guestGSSelector = gs.selector
                vmcs.guestGSBase = gs.base
                vmcs.guestGSLimit = gs.limit
                vmcs.guestGSAccessRights = gs.accessRights

                vmcs.guestTRSelector = tr.selector
                vmcs.guestTRBase = tr.base
                vmcs.guestTRLimit = tr.limit
                vmcs.guestTRAccessRights = tr.accessRights

                vmcs.guestLDTRSelector = ldtr.selector
                vmcs.guestLDTRBase = ldtr.base
                vmcs.guestLDTRLimit = ldtr.limit
                vmcs.guestLDTRAccessRights = ldtr.accessRights
            }
        }

        var registers = Registers()

        let vcpuId: hv_vcpuid_t
        let vmcs: VMCS

        init() throws {
            var _vcpuId: hv_vcpuid_t = 0
            try hvError(hv_vcpu_create(&_vcpuId, UInt64(HV_VCPU_DEFAULT)))
            self.vcpuId = _vcpuId
            print("vcpuID:", vcpuId)
            vmcs = VMCS(vcpu: vcpuId)

            let VMCS_PRI_PROC_BASED_CTLS_HLT       = UInt64(1 << 7)
            let VMCS_PRI_PROC_BASED_CTLS_CR8_LOAD  = UInt64(1 << 19)
            let VMCS_PRI_PROC_BASED_CTLS_CR8_STORE = UInt64(1 << 20)

            func cap2ctrl(_ cap: UInt64, _ ctrl: UInt64) -> UInt64 {
                return (ctrl | (cap & 0xffffffff)) & (cap >> 32)
            }
            vmcs.pinBasedVMExecControls = UInt32(truncatingIfNeeded: cap2ctrl(VirtualMachine.vmx_cap_pinbased, 0))
            vmcs.primaryProcVMExecControls = UInt32(truncatingIfNeeded: cap2ctrl(VirtualMachine.vmx_cap_procbased,
                                                                                 VMCS_PRI_PROC_BASED_CTLS_HLT |
                                                                                    VMCS_PRI_PROC_BASED_CTLS_CR8_LOAD |
                VMCS_PRI_PROC_BASED_CTLS_CR8_STORE))
            vmcs.secondaryProcVMExecControls = UInt32(truncatingIfNeeded: cap2ctrl(VirtualMachine.vmx_cap_procbased2, 0))
            vmcs.vmEntryControls = UInt32(truncatingIfNeeded: cap2ctrl(VirtualMachine.vmx_cap_entry, 0))

            vmcs.exceptionBitmap = 0xffffffff
            vmcs.cr0mask = 0x60000000
            vmcs.cr0ReadShadow = CPU.CR0Register(0)
            vmcs.cr4mask = 0
            vmcs.cr4ReadShadow = CPU.CR4Register(0)
        }

        mutating func run() throws -> VMXExit {
            try registers.setupRegisters(vcpuId: vcpuId)
            registers.setupSegmentRegisters(vmcs: vmcs)
            try hvError(hv_vcpu_run(vcpuId))
            try registers.readRegisters(vcpuId: vcpuId)
            return vmcs.exitReason!
        }

        func shutdown() throws {
            try hvError(hv_vcpu_destroy(vcpuId))
            print("vcpu destroyed")
        }
    }


    class MemRegion {
        private let pointer: UnsafeMutableRawPointer

        let guestAddress: UInt64
        let size: Int
        var rawBuffer: UnsafeMutableRawBufferPointer { UnsafeMutableRawBufferPointer(start: pointer, count: Int(size)) }

        init?(size: Int, at address: UInt64) {
            // 4KB Aligned memory
            guard let ram = valloc(Int(size)) else { return nil }
            ram.initializeMemory(as: UInt8.self, repeating: 0, count: size)
            pointer = ram
            let flags = hv_memory_flags_t(HV_MEMORY_READ | HV_MEMORY_WRITE | HV_MEMORY_EXEC)
            do {
                try hvError(hv_vm_map(ram, address, size, flags))
            } catch {
                return nil
            }
            guestAddress = address
            self.size = size

        }

        deinit {
            free(pointer)
        }
    }


    private var vcpus: [VCPU] = []
    private var mappedMemory: [MemRegion] = []


    init() {
        func printCap(_ name: String, _ value: UInt64) {
            let hi = String(UInt32(value >> 32), radix: 16)
            let lo = String(UInt32(value & 0xffff_ffff), radix: 16)
            print("\(name): \(hi)\t\(lo)")
        }

        do {
            try hvError(hv_vm_create(hv_vm_options_t(HV_VM_DEFAULT)))
            print("VM Created")
            /* get hypervisor enforced capabilities of the machine, (see Intel docs) */
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_PINBASED, &VirtualMachine.vmx_cap_pinbased))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_PROCBASED, &VirtualMachine.vmx_cap_procbased))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_PROCBASED2, &VirtualMachine.vmx_cap_procbased2))
            try hvError(hv_vmx_read_capability(HV_VMX_CAP_ENTRY, &VirtualMachine.vmx_cap_entry))
        } catch {
            fatalError("Cant alloc memory")

        }
    }

    func addMemory(at guestAddress: UInt64, size: Int) -> MemRegion? {
        let memRegion = MemRegion(size: size, at: guestAddress)!
        mappedMemory.append(memRegion)
        return memRegion
    }

    func unmapMemory(ofSize size: Int, at address: UInt64) throws {
        for idx in mappedMemory.startIndex..<mappedMemory.endIndex {
            let memory = mappedMemory[idx]
            if memory.size == size && memory.guestAddress == address {
                try hvError(hv_vm_unmap(address, size))
                print("memory unmmaped")
                mappedMemory.remove(at: idx)
                return
            }
        }
    }

    func createVCPU() throws -> VCPU {
        let vcpu = try VCPU.init()
        vcpus.append(vcpu)
        return vcpu
    }

    deinit {
        do {
            while let vcpu = vcpus.first {
                try vcpu.shutdown()
                vcpus.remove(at: 0)
            }

            while let memory = mappedMemory.first {
                try hvError(hv_vm_unmap(memory.guestAddress, memory.size))
                mappedMemory.remove(at: 0)
            }

            try hvError(hv_vm_destroy())
            print("VM Destroyed")
        } catch {
            fatalError("Error shutting down \(error)")
        }
    }
}

#endif
