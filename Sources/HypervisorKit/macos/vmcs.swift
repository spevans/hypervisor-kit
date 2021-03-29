//
//  vmcs.swift
//  HypervisorKit
//
//  Created by Simon Evans on 05/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

#if os(macOS)

import Hypervisor
import BABAB

final class VMCS {

    let vcpu: hv_vcpuid_t

    init(vcpu: hv_vcpuid_t) {
        self.vcpu = vcpu
    }


    /* read VMCS field */
    private func vmread( _ field: UInt32) throws -> UInt64 {
        var value: UInt64 = 0
        try hvError(hv_vmx_vcpu_read_vmcs(vcpu, field, &value))
        return value
    }

    /* write VMCS field */
    private func vmwrite(_ field: UInt32, _ value: UInt64) throws {
        try hvError(hv_vmx_vcpu_write_vmcs(vcpu, field, value))
    }

    private func vmread16(_ index: UInt32) throws -> UInt16 {
        return UInt16(try vmread(index))
    }

    private func vmread32(_ index: UInt32) throws -> UInt32 {
        return UInt32(try vmread(index))
    }

    private func vmread64(_ index: UInt32) throws -> UInt64 {
        return try vmread(index)
    }

    // FIXME, This should probably check the current processor mode
    private func vmreadNatural(_ index: UInt32) throws -> UInt64 {
        return try vmread64(index)
    }

    private func vmwrite16(_ index: UInt32, _ data: UInt16) throws {
        try vmwrite(index, UInt64(data))
    }


    private func vmwrite32(_ index: UInt32, _ data: UInt32) throws {
        try vmwrite(index, UInt64(data))
    }

    private func vmwrite64(_ index: UInt32, _ data: UInt64) throws {
        try vmwrite(index, data)
    }

    // FIXME, This should probably check the current processor mode
    private func vmwriteNatural(_ index: UInt32, _ data: UInt64) throws {
        try vmwrite64(index, UInt64(data))
    }


    /*
     func vmClear() -> VMXError {
     let error = vmclear(physicalAddress)
     return VMXError(error)
     }


     func vmPtrLoad() -> VMXError {
     let error = vmptrld(physicalAddress)
     return VMXError(error)
     }
     */

    func vpid() throws -> UInt16 {
        try vmread16(0x0)
    }

    func vpid(_ data: UInt16) throws {
        try vmwrite16(0x0, data)
    }

    func postedInterruptNotificationVector() throws-> UInt16 {
        try vmread16(0x2)
    }

    func postedInterruptNotificationVector(_ data: UInt16) throws {
        try vmwrite16(0x2, data)
    }

    func eptpIndex() throws -> UInt16 {
        try vmread16(0x4)
    }

    func eptpIndex(_ data: UInt16) throws {
        try vmwrite16(0x4, data)
    }


    // Guest Selectors
    func guestESSelector() throws -> UInt16 {
        try vmread16(0x800)
    }

    func guestESSelector(_ data: UInt16) throws {
        try vmwrite16(0x800, data)
    }

    func guestCSSelector() throws -> UInt16 {
        try vmread16(0x802)
    }

    func guestCSSelector(_ data: UInt16) throws {
        try vmwrite16(0x802, data)
    }

    func guestSSSelector() throws -> UInt16 {
        try vmread16(0x804)
    }

    func guestSSSelector(_ data: UInt16) throws {
        try vmwrite16(0x804, data)
    }

    func guestDSSelector() throws -> UInt16 {
        try vmread16(0x806)
    }

    func guestDSSelector(_ data: UInt16) throws {
        try vmwrite16(0x806, data)
    }

    func guestFSSelector() throws -> UInt16 {
        try vmread16(0x808)
    }

    func guestFSSelector(_ data: UInt16) throws {
        try vmwrite16(0x808, data)
    }

    func guestGSSelector() throws -> UInt16 {
        try vmread16(0x80A)
    }

    func guestGSSelector(_ data: UInt16) throws {
        try vmwrite16(0x80A, data)
    }

    func guestLDTRSelector() throws -> UInt16 {
        try vmread16(0x80C)
    }

    func guestLDTRSelector(_ data: UInt16) throws {
        try vmwrite16(0x80C, data)
    }

    func guestTRSelector() throws -> UInt16 {
        try vmread16(0x80E)
    }

    func guestTRSelector(_ data: UInt16) throws {
        try vmwrite16(0x80E, data)
    }

    func guestInterruptStatus() throws -> UInt16 {
        try vmread16(0x810)
    }

    func guestInterruptStatus(_ data: UInt16) throws {
        try vmwrite16(0x810, data)
    }

    func pmlIndex() throws -> UInt16 {
        try vmread16(0x812)
    }

    func pmlIndex(_ data: UInt16) throws {
        try vmwrite16(0x812, data)
    }


    // Host Selectors
    func hostESSelector() throws -> UInt16 {
        try vmread16(0xC00)
    }

    func hostESSelector(_ data: UInt16) throws {
        try vmwrite16(0xC00, data)
    }

    func hostCSSelector() throws -> UInt16 {
        try vmread16(0xC02)
    }

    func hostCSSelector(_ data: UInt16) throws {
        try vmwrite16(0xC02, data)
    }

    func hostSSSelector() throws -> UInt16 {
        try vmread16(0xC04)
    }

    func hostSSSelector(_ data: UInt16) throws {
        try vmwrite16(0xC04, data)
    }

    func hostDSSelector() throws -> UInt16 {
        try vmread16(0xC06)
    }

    func hostDSSelector(_ data: UInt16) throws {
        try vmwrite16(0xC06, data)
    }

    func hostFSSelector() throws -> UInt16 {
        try vmread16(0xC08)
    }

    func hostFSSelector(_ data: UInt16) throws {
        try vmwrite16(0xC08, data)
    }

    func hostGSSelector() throws -> UInt16 {
        try vmread16(0xC0A)
    }

    func hostGSSelector(_ data: UInt16) throws {
        try vmwrite16(0xC0A, data)
    }

    func hostTRSelector() throws -> UInt16 {
        try vmread16(0xC0C)
    }

    func hostTRSelector(_ data: UInt16) throws {
        try vmwrite16(0xC0C, data)
    }

    // 64Bit Control Fields
    func ioBitmapAAddress() throws -> UInt64 {
        try vmread64(0x2000)
    }

    func ioBitmapAAddress(_ data: UInt64) throws {
        try vmwrite64(0x2000, data)
    }

    func ioBitmapBAddress() throws -> UInt64 {
        try vmread64(0x2002)
    }

    func ioBitmapBAddress(_ data: UInt64) throws {
        try vmwrite64(0x2002, data)
    }

    func msrBitmapAddress() throws -> UInt64 {
        try vmread64(0x2004)
    }

    func msrBitmapAddress(_ data: UInt64) throws {
        try vmwrite64(0x2004, data)
    }

    func vmExitMSRStoreAddress() throws -> PhysicalAddress {
        let addr = try vmread64(0x2006)
        return PhysicalAddress(RawAddress(addr))
    }

    func vmExitMSRStoreAddress(_ data: PhysicalAddress) throws {
        try vmwrite64(0x2006, UInt64(data.rawValue))
    }

    func vmExitMSRLoadAddress() throws -> PhysicalAddress {
        let addr = try vmread64(0x2008)
        return PhysicalAddress(RawAddress(addr))
    }

    func vmExitMSRLoadAddress(_ data: PhysicalAddress) throws {
        try vmwrite64(0x2008, UInt64(data.rawValue))
    }

    func vmEntryMSRLoadAddress() throws -> PhysicalAddress {
        let addr = try vmread64(0x200A)
        return PhysicalAddress(RawAddress(addr))
    }

    func vmEntryMSRLoadAddress(_ data: PhysicalAddress) throws {
        try vmwrite64(0x200A, UInt64(data.rawValue))
    }

    /*
     func executiveVMCSPtr() throws -> UInt64 {
     try vmread64(0x200C) }
     try vmwrite64(0x200C, data)
     }
     **/
    func pmlAddress() throws -> PhysicalAddress{
        let addr = try vmread64(0x200E)
        return PhysicalAddress(RawAddress(addr))
    }

    func pmlAddress(_ data: PhysicalAddress) throws {
        try vmwrite64(0x200E, UInt64(data.rawValue))
    }

    /*    func tscOffset() throws -> UInt64 {
     try vmread64(0x2010) }
     try vmwrite64(0x2010, data)
     }
     **/

    func virtualAPICAddress() throws -> PhysicalAddress {
        let addr = try vmread64(0x2012)
        return PhysicalAddress(RawAddress(addr))
    }

    func virtualAPICAddress(_ data: PhysicalAddress) throws{
        try vmwrite64(0x2012, data.rawValue)
    }

    func apicAccessAddress() throws -> PhysicalAddress {
        let addr = try vmread64(0x2014)
        return PhysicalAddress(RawAddress(addr))
    }

    func apicAccessAddress(_ data: PhysicalAddress) throws {
        try vmwrite64(0x2014, data.rawValue)
    }

    func postedInterruptDescAddress() throws -> PhysicalAddress {
        let addr = try vmread64(0x2016)
        return PhysicalAddress(RawAddress(addr))
    }

    func postedInterruptDescAddress(_ data: PhysicalAddress) throws {
        try vmwrite64(0x2016, data.rawValue)
    }

    func vmFunctionControls() throws -> UInt64 {
        try vmread64(0x2018)
    }

    func vmFunctionControl(_ data: UInt64) throws {
        try vmwrite64(0x2018, data)
    }

    func eptp() throws -> UInt64 {
        try vmread64(0x201A)
    }

    func eptp(_ data: UInt64) throws {
        try vmwrite64(0x201A, data)
    }

    func eoiExitBitmap0() throws -> UInt64 {
        try vmread64(0x201C)
    }

    func eoiExitBitmap0(_ data: UInt64) throws {
        try vmwrite64(0x201C, data)
    }

    func eoiExitBitmap1() throws -> UInt64 {
        try vmread64(0x201E)
    }

    func eoiExitBitmap1(_ data: UInt64) throws {
        try vmwrite64(0x201E, data)
    }

    func eoiExitBitmap2() throws -> UInt64 {
        try vmread64(0x2020)
    }

    func eoiExitBitmap2(_ data: UInt64) throws {
        try vmwrite64(0x2020, data)
    }

    func eoiExitBitmap3() throws -> UInt64 {
        try vmread64(0x2022)
    }

    func eoiExitBitmap3(_ data: UInt64) throws {
        try vmwrite64(0x2022, data)
    }

    func eptpListAddress() throws -> PhysicalAddress {
        PhysicalAddress(try vmread64(0x2024))
    }

    func eptpListAddress(_ data: PhysicalAddress) throws {
        try vmwrite64(0x2024, UInt64(data.rawValue))
    }


    func vmreadBitmapAddress() throws -> PhysicalAddress {
        let addr = try vmread64(0x2026)
        return PhysicalAddress(RawAddress(addr))
    }

    func vmreadBitmapAddress(_ data: PhysicalAddress) throws {
        try vmwrite64(0x2026, UInt64(data.rawValue))
    }

    func vmwriteBitmapAddress() throws -> PhysicalAddress {
        let addr = try vmread64(0x2028)
        return PhysicalAddress(RawAddress(addr))
    }

    func vmwriteBitmapAddress(_ data: PhysicalAddress) throws {
        try vmwrite64(0x2028, UInt64(data.rawValue))
    }

    func vExceptionInfoAddress() throws -> PhysicalAddress {
        let addr = try vmread64(0x202A)
        return PhysicalAddress(RawAddress(addr))
    }

    func vExceptionInfoAddress(_ data: PhysicalAddress) throws {
        try vmwrite64(0x202A, UInt64(data.rawValue))
    }

    /*
     func xssExitingBitmap() throws -> UInt64 {
     try vmread64(0x202C) }
     try vmwrite64(0x202C, data)
     }

     func enclsExitingBitmap() throws -> UInt64 {
     try vmread64(0x202E) }
     try vmwrite64(0x202E, data)
     }
     */

    func subPagePermissionTablePtr() throws -> PhysicalAddress {
        let addr = try vmread64(0x2030)
        return PhysicalAddress(RawAddress(addr))
    }

    func subPagePermissionTablePtr(_ data: PhysicalAddress) throws {
        try vmwrite64(0x2030, UInt64(data.rawValue))
    }

    func tscMultiplier() throws -> UInt64 {
        try vmread64(0x2032)
    }

    func tscMultiplier(_ data: UInt64) throws {
        try vmwrite64(0x2032, data)
    }

    // 64-Bit Read-Only Data Field
    func guestPhysicalAddress() throws -> PhysicalAddress { try PhysicalAddress(vmread64(0x2400)) }

    // 64-Bit Guest-State Fields
    func vmcsLinkPointer() throws -> UInt64 {
        try vmread64(0x2800)
    }

    func vmcsLinkPointer(_ data: UInt64) throws {
        try vmwrite64(0x2800, data)
    }

    func guestIA32DebugCtl() throws -> UInt64 {
        try vmread64(0x2802)
    }

    func guestIA32DebugCtl(_ data: UInt64) throws {
        try vmwrite64(0x2802, data)
    }

    func guestIA32PAT() throws -> UInt64 {
        try vmread64(0x2804)
    }

    func guestIA32PAT(_ data: UInt64) throws {
        try vmwrite64(0x2804, data)
    }

    func guestIA32EFER() throws -> UInt64 {
        try vmread64(0x2806)
    }

    func guestIA32EFER(_ data: UInt64) throws {
        try vmwrite64(0x2806, data)
    }

    func guestIA32PerfGlobalCtrl() throws -> UInt64 {
        try vmread64(0x2808)
    }

    func guestIA32PerGlobalCtrl(_ data: UInt64) throws {
        try vmwrite64(0x2808, data)
    }

    func guestPDPTE0() throws -> UInt64 {
        try vmread64(0x280A)
    }

    func guestPDPTE0(_ data: UInt64) throws {
        try vmwrite64(0x280A, data)
    }

    func guestPDPTE1() throws -> UInt64 {
        try vmread64(0x280C)
    }

    func guestPDPTE1(_ data: UInt64) throws {
        try vmwrite64(0x280C, data)
    }

    func guestPDPTE2() throws -> UInt64 {
        try vmread64(0x280E)
    }

    func guestPDPTE2(_ data: UInt64) throws {
        try vmwrite64(0x280E, data)
    }

    func guestPDPTE3() throws -> UInt64 {
        try vmread64(0x2810)
    }

    func guestPDPTE3(_ data: UInt64) throws {
        try vmwrite64(0x2810, data)
    }

    func guestIA32bndcfgs() throws -> UInt64 {
        try vmread64(0x2812)
    }

    func guestIA32bndcfgs(_ data: UInt64) throws {
        try vmwrite64(0x2812, data)
    }

    func guestIA32RtitCtl() throws -> UInt64 {
        try vmread64(0x2814)
    }

    func guestIS32RtitCtl(_ data: UInt64) throws {
        try vmwrite64(0x2814, data)
    }

    // 64-Bit Host-State Fields
    func hostIA32PAT() throws -> UInt64 {
        try vmread64(0x2C00)
    }

    func hostIS32PAT(_ data: UInt64) throws {
        try vmwrite64(0x2C00, data)
    }

    func hostIA32EFER() throws -> UInt64 {
        try vmread64(0x2C02)
    }

    func hostIA32EFER(_ data: UInt64) throws {
        try vmwrite64(0x2C02, data)
    }

    func hostIA32PerfGlobalCtrl() throws -> UInt64 {
        try vmread64(0x2C04)
    }

    func hostIS32PerfGlobalCtrl(_ data: UInt64) throws {
        try vmwrite64(0x2C04, data)
    }

    // 32Bit Control Fields
    func pinBasedVMExecControls() throws -> UInt32 {
        try vmread32(0x4000)
    }

    func pinBasedVMExecControls(_ data: UInt32) throws {
        try vmwrite32(0x4000, data)
    }

    func primaryProcVMExecControls() throws -> UInt32 {
        try vmread32(0x4002)
    }

    func primaryProcVMExecControls(_ data: UInt32) throws {
        try vmwrite32(0x4002, data)
    }

    func exceptionBitmap() throws -> UInt32 {
        try vmread32(0x4004)
    }

    func exceptionBitmap(_ data: UInt32) throws {
        try vmwrite32(0x4004, data)
    }

    func pagefaultErrorCodeMask() throws -> UInt32 {
        try vmread32(0x4006)
    }

    func pagefaultErrorCodeMask(_ data: UInt32) throws {
        try vmwrite32(0x4006, data)
    }

    func pagefaultErrorCodeMatch() throws -> UInt32 {
        try vmread32(0x4008)
    }

    func pagefaultErrorCodeMatch(_ data: UInt32) throws {
        try vmwrite32(0x4008, data)
    }

    func cr3TargetCount() throws -> UInt32 {
        try vmread32(0x400A)
    }

    func cr3TargetCount(_ data: UInt32) throws {
        try vmwrite32(0x400A, data)
    }

    func vmExitControls() throws -> UInt32 {
        try vmread32(0x400C)
    }

    func vmExitControls(_ data: UInt32) throws {
        try vmwrite32(0x400C, data)
    }

    func vmExitMSRStoreCount() throws -> UInt32 {
        try vmread32(0x400E)
    }

    func vmExitMSRStoreCount(_ data: UInt32) throws {
        try vmwrite32(0x400E, data)
    }

    func vmExitMSRLoadCount() throws -> UInt32 {
        try vmread32(0x4010)
    }

    func vmExitMSRLoadCount(_ data: UInt32) throws {
        try vmwrite32(0x4010, data)
    }

    func vmEntryControls() throws -> UInt32 {
        try vmread32(0x4012)
    }

    func vmEntryControls(_ data: UInt32) throws {
        try vmwrite32(0x4012, data)
    }

    func vmEntryMSRLoadCount() throws -> UInt32 {
        try vmread32(0x4014)
    }

    func vmEntryMSRLoadCount(_ data: UInt32) throws {
        try vmwrite32(0x4014, data)
    }


    struct VMEntryInterruptionInfoField {

        enum InterruptType: Int {
            case external = 0
            case reserved = 1
            case nmi = 2
            case hardwareException = 3
            case softwareInterrupt = 4
            case privilegedSoftwareException = 5
            case softwareException = 6
            case otherEvent = 7
        }

        private let bits: BitArray32
        var rawValue: UInt32 { bits.rawValue }

        var vector: UInt8 { UInt8(bits[0...7]) }
        var interruptType: InterruptType { InterruptType(rawValue: Int(bits[8...10]))! }
        var deliverErrorCode: Bool { bits[11] == 1 }
        var reserved: Int { Int(bits[12...30]) }
        var valid: Bool { bits[31] == 1 }


        init(_ rawValue: UInt32) {
            bits = BitArray32(rawValue)
        }

        init(vector: UInt8, type: InterruptType, deliverErrorCode: Bool, valid: Bool = true) {
            var _bits = BitArray32(0)
            _bits[0...7] = UInt32(vector)
            _bits[8...10] = UInt32(type.rawValue)
            _bits[11] = deliverErrorCode ? 1 : 0
            _bits[31] = valid ? 1 : 0
            bits = _bits
        }
    }


    func vmEntryInterruptInfo() throws -> VMEntryInterruptionInfoField {
        VMEntryInterruptionInfoField(try vmread32(0x4016))
    }

    func vmEntryInterruptInfo(_ data: VMEntryInterruptionInfoField) throws {
        try vmwrite32(0x4016, data.rawValue)
    }

    func vmEntryExceptionErrorCode() throws -> UInt32 {
        try vmread32(0x4018)
    }

    func vmEntryExceptionErrorCode(_ data: UInt32) throws {
        try vmwrite32(0x4018, data)
    }

    func vmEntryInstructionLength() throws -> UInt32 {
        try vmread32(0x401A)
    }

    func vmEntryInstructionLength(_ data: UInt32) throws {
        try vmwrite32(0x401A, data)
    }

    func tprThreshold() throws -> UInt32 {
        try vmread32(0x401C)
    }

    func tprThreshold(_ data: UInt32) throws {
        try vmwrite32(0x401C, data)
    }

    func secondaryProcVMExecControls() throws -> UInt32 {
        try vmread32(0x401E)
    }

    func secondaryProcVMExecControls(_ data: UInt32) throws {
        try vmwrite32(0x401E, data)
    }

    /*
     private var supportsPLE: Bool {
     if let flag = vmExecSecondary?.pauseLoopExiting.allowedToBeOne {
     return flag
     }
     return false
     }

     func pleGap() throws -> UInt32 {
     get { return supportsPLE ? _vmread32(0x4020) : nil }
     set {
     if supportsPLE {
     _vmwrite32(0x4020, newValue)
     }
     }
     }

     func pleWindow() throws -> UInt32 {
     get { return supportsPLE ? _vmread32(0x4022) : nil }
     set {
     if supportsPLE {
     _vmwrite32(0x4022, newValue)
     }
     }
     }
     */

    // Read only Data fields
    func vmInstructionError() throws -> UInt32 {
        try vmread32(0x4400)
    }

    func exitReason() throws -> VMXExit {
        VMXExit(try vmread32(0x4402))
    }

    struct VMExitInterruptionInfoField {

        enum InterruptType: Int {
            case external = 0
            case reserved = 1
            case nmi = 2
            case hardwareException = 3
            case softwareInterrupt = 4
            case privilegedSoftwareException = 5
            case softwareException = 6
            case otherEvent = 7
        }

        private let bits: BitArray32
        var rawValue: UInt32 { bits.rawValue }

        var vector: UInt8 { UInt8(bits[0...7]) }
        var interruptType: InterruptType { InterruptType(rawValue: Int(bits[8...10]))! }
        var errorCodeValid: Bool { bits[11] == 1}
        var nmiUnblockingDueToIRET: Bool { bits[12] == 1 }
        var reserved: Int { Int(bits[13...30]) }
        var valid: Bool { bits[31] == 1 }

        init(_ rawValue: UInt32) {
            bits = BitArray32(rawValue)
        }
    }

    func vmExitInterruptionInfo() throws -> VMExitInterruptionInfoField {
        VMExitInterruptionInfoField(try vmread32(0x4404))
    }

    func vmExitInterruptionErrorCode() throws -> UInt32 {
        try vmread32(0x4406)
    }

    func idtVectorInfoField() throws -> UInt32 {
        try vmread32(0x4408)
    }

    func idtVectorErrorCode() throws -> UInt32 {
        try vmread32(0x440A)
    }

    func vmExitInstructionLength() throws -> UInt32 {
        try vmread32(0x440C)
    }

    func vmExitInstructionInfo() throws -> UInt32 {
        try vmread32(0x440E)
    }

    // 32bit Guest State Fields
    func guestESLimit() throws -> UInt32 {
        try vmread32(0x4800)
    }

    func guestESLimit(_ data: UInt32) throws {
        try vmwrite32(0x4800, data)
    }

    func guestCSLimit() throws -> UInt32 {
        try vmread32(0x4802)
    }

    func guestCSLimit(_ data: UInt32) throws {
        try vmwrite32(0x4802, data)
    }

    func guestSSLimit() throws -> UInt32 {
        try vmread32(0x4804)
    }

    func guestSSLimit(_ data: UInt32) throws {
        try vmwrite32(0x4804, data)
    }

    func guestDSLimit() throws -> UInt32 {
        try vmread32(0x4806)
    }

    func guestDSLimit(_ data: UInt32) throws {
        try vmwrite32(0x4806, data)
    }

    func guestFSLimit() throws -> UInt32 {
        try vmread32(0x4808)
    }

    func guestFSLimit(_ data: UInt32) throws {
        try vmwrite32(0x4808, data)
    }

    func guestGSLimit() throws -> UInt32 {
        try vmread32(0x480A)
    }

    func guestGSLimit(_ data: UInt32) throws {
        try vmwrite32(0x480A, data)
    }

    func guestLDTRLimit() throws -> UInt32 {
        try vmread32(0x480C)
    }

    func guestLDTRLimit(_ data: UInt32) throws {
        try vmwrite32(0x480C, data)
    }

    func guestTRLimit() throws -> UInt32 {
        try vmread32(0x480E)
    }

    func guestTRLimit(_ data: UInt32) throws {
        try vmwrite32(0x480E, data)
    }

    func guestGDTRLimit() throws -> UInt32 {
        try vmread32(0x4810)
    }

    func guestGDTRLimit(_ data: UInt32) throws {
        try vmwrite32(0x4810, data)
    }

    func guestIDTRLimit() throws -> UInt32 {
        try vmread32(0x4812)
    }

    func guestIDTRLimit(_ data: UInt32) throws {
        try vmwrite32(0x4812, data)
    }

    func guestESAccessRights() throws -> UInt32 {
        try vmread32(0x4814)
    }

    func guestESAccessRights(_ data: UInt32) throws {
        try vmwrite32(0x4814, data)
    }

    func guestCSAccessRights() throws -> UInt32 {
        try vmread32(0x4816)
    }

    func guestCSAccessRights(_ data: UInt32) throws {
        try vmwrite32(0x4816, data)
    }

    func guestSSAccessRights() throws -> UInt32 {
        try vmread32(0x4818)
    }

    func guestSSAccessRights(_ data: UInt32) throws {
        try vmwrite32(0x4818, data)
    }

    func guestDSAccessRights() throws -> UInt32 {
        try vmread32(0x481A)
    }

    func guestDSAccessRights(_ data: UInt32) throws {
        try vmwrite32(0x481A, data)
    }

    func guestFSAccessRights() throws -> UInt32 {
        try vmread32(0x481C)
    }

    func guestFSAccessRights(_ data: UInt32) throws {
        try vmwrite32(0x481C, data)
    }

    func guestGSAccessRights() throws -> UInt32 {
        try vmread32(0x481E)
    }

    func guestGSAccessRights(_ data: UInt32) throws {
        try vmwrite32(0x481E, data)
    }

    func guestLDTRAccessRights() throws -> UInt32 {
        try vmread32(0x4820)
    }

    func guestLDTRAccessRights(_ data: UInt32) throws {
        try vmwrite32(0x4820, data)
    }

    func guestTRAccessRights() throws -> UInt32 {
        try vmread32(0x4822)
    }

    func guestTRAccessRights(_ data: UInt32) throws {
        try vmwrite32(0x4822, data)
    }

    struct InterruptibilityState {
        private var bits: BitArray32
        var rawValue: UInt32 { bits.rawValue }

        var blockingBySTI: Bool {
            get { bits[0] == 1 }
            set { bits[0] = newValue ? 1 : 0 }
        }

        var blockingByMovSS: Bool {
            get { bits[1] == 1 }
            set { bits[1] = newValue ? 1 : 0 }
        }

        var blockingBySMI: Bool  {
            get { bits[2] == 1 }
            set { bits[2] = newValue ? 1 : 0 }
        }

        var blockingByNMI: Bool {
            get { bits[3] == 1 }
            set { bits[3] = newValue ? 1 : 0 }
        }

        var enclaveInterruption: Bool {
            get { bits[4] == 1 }
            set { bits[4] = newValue ? 1 : 0 }
        }

        var reserved: Int  { Int(bits[5...31]) }

        init(_ rawValue: UInt32) {
            bits = BitArray32(rawValue)
        }
    }


    func guestInterruptibilityState() throws -> InterruptibilityState {
        InterruptibilityState(try vmread32(0x4824))
    }

    func guestInterruptibilityState(_ data: InterruptibilityState) throws {
        try vmwrite32(0x4824, data.rawValue)
    }

    enum GuestActivityState: Equatable {
        case active
        case hlt
        case shutdown
        case waitForSIPI
        case unknown(UInt32)

        init(_ rawValue: UInt32) {
            switch rawValue {
                case 0: self = .active
                case 1: self = .hlt
                case 2: self = .shutdown
                case 3: self = .waitForSIPI
                default: self = .unknown(rawValue)
            }
        }

        var rawValue: UInt32 {
            switch self {
                case .active:               return 0
                case .hlt:                  return 1
                case .shutdown:             return 2
                case .waitForSIPI:          return 3
                case .unknown(let value):   return value
            }
        }
    }


    func guestActivityState() throws -> GuestActivityState {
        GuestActivityState(try vmread32(0x4826))
    }

    func guestActivityState(_ data: GuestActivityState) throws {
        try vmwrite32(0x4826, data.rawValue)
    }

    func guestSMBASE() throws -> UInt32 {
        try vmread32(0x4828)
    }

    func guestSMBASE(_ data: UInt32) throws {
        try vmwrite32(0x4828, data)
    }

    func guestIA32SysenterCS() throws -> UInt32 {
        try vmread32(0x482A)
    }

    func guestIA32SysencterCS(_ data: UInt32) throws {
        try vmwrite32(0x482A, data)
    }

    func vmxPreemptionTimerValue() throws -> UInt32 {
        try vmread32(0x482E)
    }

    func vmxPremptionTimerValue(_ data: UInt32) throws {
        try vmwrite32(0x482E, data)
    }

    func hostIA32SysenterCS() throws -> UInt32 {
        try vmread32(0x4C00)
    }

    func hostIA32SysenterCS(_ data: UInt32) throws {
        try vmwrite32(0x4C00, data)
    }

    func cr0mask() throws -> UInt64 {
        try vmreadNatural(0x6000)
    }

    func cr0mask(_ data: UInt64) throws {
        try vmwriteNatural(0x6000, data)
    }

    func cr4mask() throws -> UInt64 {
        try vmreadNatural(0x6002)
    }

    func cr4mask(_ data: UInt64) throws {
        try vmwriteNatural(0x6002, data)
    }

    func cr0ReadShadow() throws -> CPU.CR0Register {
        CPU.CR0Register(try vmread64(0x6004))
    }

    func cr0ReadShadow(_ data: CPU.CR0Register) throws {
        try vmwrite64(0x6004, data.value)
    }

    func cr4ReadShadow() throws -> CPU.CR4Register {
        CPU.CR4Register(try vmread64(0x6006))
    }

    func cr4ReadShadow(_ data: CPU.CR4Register) throws {
        try vmwrite64(0x6006, data.value)
    }

    func cr3TargetValue0() throws -> UInt64 {
        try vmreadNatural(0x6008)
    }

    func cr3TargetValue0(_ data: UInt64) throws {
        try vmwriteNatural(0x6008, data)
    }

    func cr3TargetValue1() throws -> UInt64 {
        try vmreadNatural(0x600A)
    }

    func cr3TargetValue1(_ data: UInt64) throws {
        try vmwriteNatural(0x600A, data)
    }

    func cr3TargetValue2() throws -> UInt64 {
        try vmreadNatural(0x600C)
    }

    func cr3TargetValue2(_ data: UInt64) throws {
        try vmwriteNatural(0x600C, data)
    }

    func cr3TargetValue3() throws -> UInt64 {
        try vmreadNatural(0x600E)
    }

    func cr3TargetValue3(_ data: UInt64) throws {
        try vmwriteNatural(0x600E, data)
    }

    // Natural width Read-Only data fields
    func exitQualification() throws -> UInt64 {
        try vmreadNatural(0x6400)
    }

    func ioRCX() throws -> UInt64 {
        try vmreadNatural(0x6402)
    }

    func ioRSI() throws -> UInt64 {
        try vmreadNatural(0x6404)
    }

    func ioRDI() throws -> UInt64 {
        try vmreadNatural(0x6406)
    }

    func ioRIP() throws -> UInt64 {
        try vmreadNatural(0x6408)
    }

    func guestLinearAddress() throws -> UInt64 {
        try vmreadNatural(0x640A)
    }

    // Natural width Guest state fields
    func guestCR0() throws -> CPU.CR0Register {
        CPU.CR0Register(try vmread64(0x6800))
    }

    func guestCR0(_ data: CPU.CR0Register) throws {
        try vmwrite64(0x6800, data.value)
    }

    func guestCR3() throws -> CPU.CR3Register {
        CPU.CR3Register(try vmread64(0x6802))
    }

    func guestCR3(_ data: CPU.CR3Register) throws {
        try vmwrite64(0x6802, data.value)
    }

    func guestCR4() throws -> CPU.CR4Register {
        CPU.CR4Register(try vmread64(0x6804))
    }

    func guestCR4(_ data: CPU.CR4Register) throws {
        try vmwrite64(0x6804, data.value)
    }

    func guestESBase() throws -> UInt64 {
        try vmreadNatural(0x6806)
    }

    func guestESBase(_ data: UInt64) throws {
        try vmwriteNatural(0x6806, data)
    }

    func guestCSBase() throws -> UInt64 {
        try vmreadNatural(0x6808)
    }

    func guestCSBase(_ data: UInt64) throws {
        try vmwriteNatural(0x6808, data)
    }

    func guestSSBase() throws -> UInt64 {
        try vmreadNatural(0x680A)
    }

    func guestSSBase(_ data: UInt64) throws {
        try vmwriteNatural(0x680A, data)
    }

    func guestDSBase() throws -> UInt64 {
        try vmreadNatural(0x680C)
    }

    func guestDSBase(_ data: UInt64) throws {
        try vmwriteNatural(0x680C, data)
    }

    func guestFSBase() throws -> UInt64 {
        try vmreadNatural(0x680E)
    }

    func guestFSBase(_ data: UInt64) throws {
        try vmwriteNatural(0x680E, data)
    }

    func guestGSBase() throws -> UInt64 {
        try vmreadNatural(0x6810)
    }

    func guestGSBase(_ data: UInt64) throws {
        try vmwriteNatural(0x6810, data)
    }

    func guestLDTRBase() throws -> UInt64 {
        try vmreadNatural(0x6812)
    }

    func guestLDTRBase(_ data: UInt64) throws {
        try vmwriteNatural(0x6812, data)
    }

    func guestTRBase() throws -> UInt64 {
        try vmreadNatural(0x6814)
    }

    func guestTRBase(_ data: UInt64) throws {
        try vmwriteNatural(0x6814, data)
    }

    func guestGDTRBase() throws -> UInt64 {
        try vmreadNatural(0x6816)
    }

    func guestGDTRBase(_ data: UInt64) throws {
        try vmwriteNatural(0x6816, data)
    }

    func guestIDTRBase() throws -> UInt64 {
        try vmreadNatural(0x6818)
    }

    func guestIDTRBase(_ data: UInt64) throws {
        try vmwriteNatural(0x6818, data)
    }

    func guestDR7() throws -> UInt64 {
        try vmreadNatural(0x681A)
    }

    func guestDR7(_ data: UInt64) throws {
        try vmwriteNatural(0x681A, data)
    }

    func guestRSP() throws -> UInt64 {
        try vmreadNatural(0x681C)
    }

    func guestRSP(_ data: UInt64) throws {
        try vmwriteNatural(0x681C, data)
    }

    func guestRIP() throws -> UInt64 {
        try vmreadNatural(0x681E)
    }

    func guestRIP(_ data: UInt64) throws {
        try vmwriteNatural(0x681E, data)
    }

    func guestRFlags() throws -> CPU.RFLAGS {
        CPU.RFLAGS(UInt64(try vmreadNatural(0x6820)))
    }

    func guestRFlags(_ data: CPU.RFLAGS) throws {
        try vmwriteNatural(0x6820, data.rawValue)
    }

    struct PendingDebugExceptions {
        let bits: BitArray64
        var rawValue: UInt64 { bits.rawValue }

        var b0: Bool { bits[0] == 1 }
        var b1: Bool { bits[1] == 1 }
        var b2: Bool { bits[2] == 1 }
        var b3: Bool { bits[3] == 1 }
        var reserved1: Int { Int(bits[4...11]) }
        var enabledBreakpoint: Bool { bits[12] == 1 }
        var reserved2: Int { Int(bits[13]) }
        var bs: Bool { bits[14] == 1 }
        var reserved3: Int { Int(bits[15]) }
        var rtm: Bool { bits[16] == 1 }
        var reserved4: Int { Int(bits[17...63]) }
        var reserved: Int { reserved1 + reserved2 + reserved3 + reserved4 }

        init(_ rawValue: UInt64) {
            bits = BitArray64(rawValue)
        }
    }

    func guestPendingDebugExceptions() throws -> PendingDebugExceptions {
        PendingDebugExceptions(try vmreadNatural(0x6822))
    }

    func guestPendingDebugException(_ data: PendingDebugExceptions) throws {
        try vmwriteNatural(0x6822, data.rawValue)
    }

    func guestIA32SysenterESP() throws -> UInt64 {
        try vmreadNatural(0x6824)
    }

    func guestIA32SysenterESP(_ data: UInt64) throws {
        try vmwriteNatural(0x6824, data)
    }

    func guestIA32SysenterEIP() throws -> UInt64 {
        try vmreadNatural(0x6826)
    }

    func guestIA32SysenterEIP(_ data: UInt64) throws {
        try vmwriteNatural(0x6826, data)
    }

    // Natural-Width Host-State Fields
    func hostCR0() throws -> CPU.CR0Register {
        CPU.CR0Register(try vmread64(0x6C00))
    }

    func hostCR0(_ data: CPU.CR0Register) throws {
        try vmwrite64(0x6C00, data.value)
    }

    func hostCR3() throws -> CPU.CR3Register {
        CPU.CR3Register(try vmread64(0x6C02))
    }

    func hostCR3(_ data: CPU.CR3Register) throws {
        try vmwrite64(0x6C02, data.value)
    }

    func hostCR4() throws -> CPU.CR4Register {
        CPU.CR4Register(try vmread64(0x6C04))
    }

    func hostCR4(_ data: CPU.CR4Register) throws {
        try vmwrite64(0x6C04, data.value)
    }

    func hostFSBase() throws -> UInt64 {
        try vmreadNatural(0x6C06)
    }

    func hostFSBase(_ data: UInt64) throws {
        try vmwriteNatural(0x6C06, data)
    }

    func hostGSBase() throws -> UInt64 {
        try vmreadNatural(0x6C08)
    }

    func hostGSBase(_ data: UInt64) throws {
        try vmwriteNatural(0x6C08, data)
    }

    func hostTRBase() throws -> UInt64 {
        try vmreadNatural(0x6C0A)
    }

    func hostTRBase(_ data: UInt64) throws {
        try vmwriteNatural(0x6C0A, data)
    }

    func hostGDTRBase() throws -> UInt64 {
        try vmreadNatural(0x6C0C)
    }

    func hostGDTRBase(_ data: UInt64) throws {
        try vmwriteNatural(0x6C0C, data)
    }

    func hostIDTRBase() throws -> UInt64 {
        try vmreadNatural(0x6C0E)
    }

    func hostIDTRBase(_ data: UInt64) throws {
        try vmwriteNatural(0x6C0E, data)
    }

    func hostIA32SysenterESP() throws -> UInt64 {
        try vmreadNatural(0x6C10)
    }

    func hostIA32SysenterESP(_ data: UInt64) throws {
        try vmwriteNatural(0x6C10, data)
    }

    func hostIA32SysenterEIP() throws -> UInt64 {
        try vmreadNatural(0x6C12)
    }

    func hostIA32SysenterEIP(_ data: UInt64) throws {
        try vmwriteNatural(0x6C12, data)
    }

    func hostRSP() throws -> UInt64 {
        try vmreadNatural(0x6C14)
    }

    func hostRSP(_ data: UInt64) throws {
        try vmwriteNatural(0x6C14, data)
    }

    func hostRIP() throws -> UInt64 {
        try vmreadNatural(0x6C16)
    }

    func hostRIP(_ data: UInt64) throws {
        try vmwriteNatural(0x6C16, data)
    }

    /**
     func printVMCS() {

     func showValue<T: UnsignedInteger>(_ name: String, _ value: T?) {
     print(name, value == nil ? "Unsupported" : String(value!, radix: 16))
     }

     //        showValue("physicalAddress:", physicalAddress)
     showValue("vpid:", vpid)
     showValue("postedInterruptNotificationVector:", postedInterruptNotificationVector)
     showValue("eptpIndex:", eptpIndex)
     showValue("guestESSelector:", guestESSelector)
     showValue("guestCSSelector:", guestCSSelector)
     showValue("guestSSSelector:", guestSSSelector)
     showValue("guestDSSelector:", guestDSSelector)
     showValue("guestFSSelector:", guestFSSelector)
     showValue("guestGSSelector:", guestGSSelector)
     showValue("guestLDTRSelector:", guestLDTRSelector)
     showValue("guestTRSelector:", guestTRSelector)
     showValue("guestInterruptStatus:", guestInterruptStatus)
     /**
     showValue("pmlIndex:", pmlIndex)
     showValue("hostESSelector:", hostESSelector)
     showValue("hostCSSelector:", hostCSSelector)
     showValue("hostSSSelector:", hostSSSelector)
     showValue("hostDSSelector:", hostDSSelector)
     showValue("hostFSSelector:", hostFSSelector)
     showValue("hostGSSelector:", hostGSSelector)
     showValue("hostTRSelector:", hostTRSelector)
     showValue("ioBitmapAAddress:", ioBitmapAAddress)
     showValue("ioBitmapBAddress:", ioBitmapBAddress)
     showValue("msrBitmapAddress:", msrBitmapAddress)

     print("vmExitMSRStoreAddress:", vmExitMSRStoreAddress ?? "Unsupported")
     print("vmExitMSRLoadAddress:", vmExitMSRLoadAddress ?? "Unsupported")
     print("vmEntryMSRLoadAddress:", vmEntryMSRLoadAddress ?? "Unsupported")
     showValue("executiveVMCSPtr:", executiveVMCSPtr)
     print("pmlAddress:", pmlAddress ?? "Unsupported")
     showValue("tscOffset:", tscOffset)
     print("virtualAPICAddress:", virtualAPICAddress ?? "Unsupported")
     print("apicAccessAddress:", apicAccessAddress ?? "Unsupported")
     print("postedInterruptDescAddress:", postedInterruptDescAddress ?? "Unsupported")
     showValue("vmFunctionControls:", vmFunctionControls)
     showValue("eptp:", eptp)
     showValue("eoiExitBitmap0:", eoiExitBitmap0)
     showValue("eoiExitBitmap1:", eoiExitBitmap1)
     showValue("eoiExitBitmap2:", eoiExitBitmap2)
     showValue("eoiExitBitmap3:", eoiExitBitmap3)
     print("eptpListAddress:", eptpListAddress ?? "Unsupported")
     print("vmreadBitmapAddress:", vmreadBitmapAddress ?? "Unsupported")
     print("vmwriteBitmapAddress:", vmwriteBitmapAddress ?? "Unsupported")
     print("vExceptionInfoAddress:", vExceptionInfoAddress ?? "Unsupported")
     showValue("xssExitingBitmap:", xssExitingBitmap)
     showValue("enclsExitingBitmap:", enclsExitingBitmap)
     print("subPagePermissionTablePtr:", subPagePermissionTablePtr ?? "Unsupported")
     showValue("tscMultiplier:", tscMultiplier)
     showValue("guestPhysAddress:", guestPhysAddress)
     showValue("vmcsLinkPointer:", vmcsLinkPointer)
     ****/
     showValue("guestIA32DebugCtl:", guestIA32DebugCtl)
     showValue("guestIA32PAT:", guestIA32PAT)
     showValue("guestIA32EFER:", guestIA32EFER)
     showValue("guestIA32PerfGlobalCtrl:", guestIA32PerfGlobalCtrl)
     showValue("guestPDPTE0:", guestPDPTE0)
     showValue("guestPDPTE1:", guestPDPTE1)
     showValue("guestPDPTE2:", guestPDPTE2)
     showValue("guestPDPTE3:", guestPDPTE3)
     showValue("guestIA32bndcfgs:", guestIA32bndcfgs)
     showValue("guestIA32RtitCtl:", guestIA32RtitCtl)
     showValue("hostIA32PAT:", hostIA32PAT)
     showValue("hostIA32EFER:", hostIA32EFER)
     showValue("hostIA32PerfGlobalCtrl:", hostIA32PerfGlobalCtrl)
     showValue("pinBasedVMExecControls:", pinBasedVMExecControls)
     showValue("primaryProcVMExecControls:", primaryProcVMExecControls)
     showValue("exceptionBitmap:", exceptionBitmap)
     showValue("pagefaultErrorCodeMask:", pagefaultErrorCodeMask)
     showValue("pagefaultErrorCodeMatch:", pagefaultErrorCodeMatch)
     showValue("cr3TargetCount:", cr3TargetCount)
     showValue("vmExitControls:", vmExitControls)
     showValue("vmExitMSRStoreCount:", vmExitMSRStoreCount)
     showValue("vmExitMSRLoadCount:", vmExitMSRLoadCount)
     showValue("vmEntryControls:", vmEntryControls)
     showValue("vmEntryMSRLoadCount:", vmEntryMSRLoadCount)
     print("vmEntryInterruptInfo:", vmEntryInterruptInfo ?? "nil")
     showValue("vmEntryExceptionErrorCode:", vmEntryExceptionErrorCode)
     showValue("vmEntryInstructionLength:", vmEntryInstructionLength)
     showValue("tprThreshold:", tprThreshold)
     showValue("secondaryProcVMExecControls:", secondaryProcVMExecControls)
     /*        print("supportsPLE:", supportsPLE)
     showValue("pleGap:", pleGap)
     showValue("pleWindow:", pleWindow)
     showValue("vmInstructionError:", vmInstructionError)
     print("exitReason:", exitReason ?? "nil")
     */
     showValue("vmExitIntInfo:", vmExitIntInfo)
     showValue("vmExitIntErrorCode:", vmExitIntErrorCode)
     showValue("idtVectorInfoField:", idtVectorInfoField)
     showValue("idtVectorErrorCode:", idtVectorErrorCode)
     showValue("vmExitInstrLen:", vmExitInstrLen)
     showValue("vmExitInstrInfo:", vmExitInstrInfo)
     showValue("guestESLimit:", guestESLimit)
     showValue("guestCSLimit:", guestCSLimit)
     showValue("guestSSLimit:", guestSSLimit)
     showValue("guestDSLimit:", guestDSLimit)
     showValue("guestFSLimit:", guestFSLimit)
     showValue("guestGSLimit:", guestGSLimit)
     showValue("guestLDTRLimit:", guestLDTRLimit)
     showValue("guestTRLimit:", guestTRLimit)
     showValue("guestGDTRLimit:", guestGDTRLimit)
     showValue("guestIDTRLimit:", guestIDTRLimit)
     showValue("guestESAccessRights:", guestESAccessRights)
     showValue("guestCSAccessRights:", guestCSAccessRights)
     showValue("guestSSAccessRights:", guestSSAccessRights)
     showValue("guestDSAccessRights:", guestDSAccessRights)
     showValue("guestFSAccessRights:", guestFSAccessRights)
     showValue("guestGSAccessRights:", guestGSAccessRights)
     showValue("guestLDTRAccessRights:", guestLDTRAccessRights)
     showValue("guestTRAccessRights:", guestTRAccessRights)
     print("guestInterruptibilityState:", guestInterruptibilityState ?? "nil")
     showValue("guestActivityState:", guestActivityState)
     showValue("guestSMBASE:", guestSMBASE)
     showValue("guestIA32SysenterCS:", guestIA32SysenterCS)
     showValue("vmxPreemptionTimerValue:", vmxPreemptionTimerValue)
     showValue("hostIA32SysenterCS:", hostIA32SysenterCS)
     showValue("cr0mask:", cr0mask)
     showValue("cr4mask:", cr4mask)
     showValue("cr0ReadShadow:", cr0ReadShadow?.bits.toUInt64())
     showValue("cr4ReadShadow:", cr4ReadShadow?.bits.toUInt64())
     showValue("cr3TargetValue0:", cr3TargetValue0)
     showValue("cr3TargetValue1:", cr3TargetValue1)
     showValue("cr3TargetValue2:", cr3TargetValue2)
     showValue("cr3TargetValue3:", cr3TargetValue3)
     showValue("exitQualification:", exitQualification)
     showValue("ioRCX:", ioRCX)
     showValue("ioRSI:", ioRSI)
     showValue("ioRDI:", ioRDI)
     showValue("ioRIP:", ioRIP)
     showValue("guestLinearAddress:", guestLinearAddress)
     showValue("guestCR0:", guestCR0?.bits.toUInt64())
     showValue("guestCR3:", guestCR3?.bits.toUInt64())
     showValue("guestCR4:", guestCR4?.bits.toUInt64())
     showValue("guestESBase:", guestESBase)
     showValue("guestCSBase:", guestCSBase)
     showValue("guestSSBase:", guestSSBase)
     showValue("guestDSBase:", guestDSBase)
     showValue("guestFSBase:", guestFSBase)
     showValue("guestGSBase:", guestGSBase)
     showValue("guestLDTRBase:", guestLDTRBase)
     showValue("guestTRBase:", guestTRBase)
     showValue("guestGDTRBase:", guestGDTRBase)
     showValue("guestIDTRBase:", guestIDTRBase)
     showValue("guestDR7:", guestDR7)
     showValue("guestRSP:", guestRSP)
     showValue("guestRIP:", guestRIP)
     showValue("guestRFlags:", guestRFlags)
     print("guestPendingDebugExceptions:", guestPendingDebugExceptions ?? "nil")
     showValue("guestIA32SysenterESP:", guestIA32SysenterESP)
     showValue("guestIA32SysenterEIP:", guestIA32SysenterEIP)
     showValue("hostCR0:", hostCR0?.bits.toUInt64())
     showValue("hostCR3:", hostCR3?.bits.toUInt64())
     showValue("hostCR4:", hostCR4?.bits.toUInt64())
     showValue("hostFSBase:", hostFSBase)
     showValue("hostGSBase:", hostGSBase)
     showValue("hostTRBase:", hostTRBase)
     showValue("hostGDTRBase:", hostGDTRBase)
     showValue("hostIDTRBase:", hostIDTRBase)
     showValue("hostIA32SysenterESP:", hostIA32SysenterESP)
     showValue("hostIA32SysenterEIP:", hostIA32SysenterEIP)
     showValue("hostRSP:", hostRSP)
     showValue("hostRIP:", hostRIP)
     }
     *****/

}

#endif
