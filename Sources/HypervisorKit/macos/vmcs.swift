//
//  vmcs.swift
//  
//
//  Created by Simon Evans on 05/12/2019.
//

#if os(macOS)

import Hypervisor

final class VMCS {
    /*
     static let vmxInfo = VMXBasicInfo()

     let vmExecPrimary = VMXPrimaryProcessorBasedControls()
     let vmExecSecondary: VMXSecondaryProcessorBasedControls?
     let page: PhysPageRange
     var vcpu: vcpu_info = vcpu_info()



     var physicalAddress: UInt64 {
     let physAddr = page.address
     let mask = UInt(maskFromBitCount: Int(VMCS.vmxInfo.physAddressWidthMaxBits))
     let addr = physAddr.value & mask
     return UInt64(addr)
     }





     init() {
     page = alloc(pages: 1)
     page.rawPointer.storeBytes(of: VMCS.vmxInfo.vmcsRevisionId, toByteOffset: 0,
     as: UInt32.self)

     if vmExecPrimary.activateSecondaryControls.allowedToBeOne {
     vmExecSecondary = VMXSecondaryProcessorBasedControls()
     } else {
     vmExecSecondary = nil
     }
     }

     deinit {
     freePages(pages: page)
     }
     */

    let vcpu: hv_vcpuid_t

    init(vcpu: hv_vcpuid_t) {
        self.vcpu = vcpu
    }



    /* read VMCS field */
    func vmread( _ field: UInt32, _ value: inout UInt64) -> UInt64 {
        //var value: UInt64 = 0
        let x = hv_vmx_vcpu_read_vmcs(vcpu, field, &value)
        if x < 0 {
            return 1
        } else {
            return 0
        }
    }

    /* write VMCS field */
    func vmwrite(_ field: UInt32, _ value: UInt64) -> UInt64 {
        return UInt64(hv_vmx_vcpu_write_vmcs(vcpu, field, value))
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

    var vpid: UInt16? {
        get { _vmread16(0x0) }
        set { _vmwrite16(0x0, newValue) }
    }

    var postedInterruptNotificationVector: UInt16? {
        get { _vmread16(0x2) }
        set { _vmwrite16(0x2, newValue) }
    }

    var eptpIndex: UInt16? {
        get { _vmread16(0x4) }
        set { _vmwrite16(0x4, newValue) }
    }


    // Guest Selectors
    var guestESSelector: UInt16? {
        get { _vmread16(0x800) }
        set { _vmwrite16(0x800, newValue) }
    }

    var guestCSSelector: UInt16? {
        get { _vmread16(0x802) }
        set { _vmwrite16(0x802, newValue) }
    }

    var guestSSSelector: UInt16? {
        get { _vmread16(0x804) }
        set { _vmwrite16(0x804, newValue) }
    }

    var guestDSSelector: UInt16? {
        get { _vmread16(0x806) }
        set { _vmwrite16(0x806, newValue) }
    }

    var guestFSSelector: UInt16? {
        get { _vmread16(0x808) }
        set { _vmwrite16(0x808, newValue) }
    }

    var guestGSSelector: UInt16? {
        get { _vmread16(0x80A) }
        set { _vmwrite16(0x80A, newValue) }
    }

    var guestLDTRSelector: UInt16? {
        get { _vmread16(0x80C) }
        set { _vmwrite16(0x80C, newValue) }
    }

    var guestTRSelector: UInt16? {
        get { _vmread16(0x80E) }
        set { _vmwrite16(0x80E, newValue) }
    }

    var guestInterruptStatus: UInt16? {
        get { _vmread16(0x810) }
        set { _vmwrite16(0x810, newValue) }
    }

    var pmlIndex: UInt16? {
        get { _vmread16(0x812) }
        set { _vmwrite16(0x812, newValue) }
    }


    // Host Selectors
    var hostESSelector: UInt16? {
        get { _vmread16(0xC00) }
        set { _vmwrite16(0xC00, newValue) }
    }

    var hostCSSelector: UInt16? {
        get { _vmread16(0xC02) }
        set { _vmwrite16(0xC02, newValue) }
    }

    var hostSSSelector: UInt16? {
        get { _vmread16(0xC04) }
        set { _vmwrite16(0xC04, newValue) }
    }

    var hostDSSelector: UInt16? {
        get { _vmread16(0xC06) }
        set { _vmwrite16(0xC06, newValue) }
    }

    var hostFSSelector: UInt16? {
        get { _vmread16(0xC08) }
        set { _vmwrite16(0xC08, newValue) }
    }

    var hostGSSelector: UInt16? {
        get { _vmread16(0xC0A) }
        set { _vmwrite16(0xC0A, newValue) }
    }

    var hostTRSelector: UInt16? {
        get { _vmread16(0xC0C) }
        set { _vmwrite16(0xC0C, newValue) }
    }

    // 64Bit Control Fields
    var ioBitmapAAddress: UInt64? {
        get { _vmread64(0x2000) }
        set { _vmwrite64(0x2000, newValue) }
    }

    var ioBitmapBAddress: UInt64? {
        get { _vmread64(0x2002) }
        set { _vmwrite64(0x2002, newValue) }
    }

    var msrBitmapAddress: UInt64? {
        get { _vmread64(0x2004) }
        set { _vmwrite64(0x2004, newValue) }
    }
    /****
     var vmExitMSRStoreAddress: PhysAddress? {
     get {
     if let addr = _vmread64(0x2006) { return PhysAddress(RawAddress(addr)) }
     return nil
     }
     set { _vmwrite64(0x2006, UInt64(newValue!.value)) }
     }

     var vmExitMSRLoadAddress: PhysAddress? {
     get {
     if let addr = _vmread64(0x2008) { return PhysAddress(RawAddress(addr)) }
     return nil
     }
     set { _vmwrite64(0x2008, UInt64(newValue!.value)) }
     }

     var vmEntryMSRLoadAddress: PhysAddress? {
     get {
     if let addr = _vmread64(0x200A) { return PhysAddress(RawAddress(addr)) }
     return nil
     }
     set { _vmwrite64(0x200A, UInt64(newValue!.value)) }
     }

     var executiveVMCSPtr: UInt64? {
     get { _vmread64(0x200C) }
     set { _vmwrite64(0x200C, newValue) }
     }

     var pmlAddress: PhysAddress? {
     get {
     if let addr = _vmread64(0x200E) { return PhysAddress(RawAddress(addr)) }
     return nil
     }
     set { _vmwrite64(0x200E, UInt64(newValue!.value)) }
     }

     var tscOffset: UInt64? {
     get { _vmread64(0x2010) }
     set { _vmwrite64(0x2010, newValue) }
     }

     var virtualAPICAddress: PhysAddress? {
     get {
     if let addr = _vmread64(0x2012) { return PhysAddress(RawAddress(addr)) }
     return nil
     }
     set { _vmwrite64(0x2012, UInt64(newValue!.value)) }
     }

     var apicAccessAddress: PhysAddress? {
     get {
     if let addr = _vmread64(0x2014) { return PhysAddress(RawAddress(addr)) }
     return nil
     }
     set { _vmwrite64(0x2014, UInt64(newValue!.value)) }
     }

     var postedInterruptDescAddress: PhysAddress? {
     get {
     if let addr = _vmread64(0x2016) { return PhysAddress(RawAddress(addr)) }
     return nil
     }
     set { _vmwrite64(0x2016, UInt64(newValue!.value)) }
     }
     ****/
    var vmFunctionControls: UInt64? {
        get { _vmread64(0x2018) }
        set { _vmwrite64(0x2018, newValue) }
    }

    var eptp: UInt64? {
        get { _vmread64(0x201A) }
        set { _vmwrite64(0x201A, newValue) }
    }

    var eoiExitBitmap0: UInt64? {
        get { _vmread64(0x201C) }
        set { _vmwrite64(0x201C, newValue) }
    }

    var eoiExitBitmap1: UInt64? {
        get { _vmread64(0x201E) }
        set { _vmwrite64(0x201E, newValue) }
    }

    var eoiExitBitmap2: UInt64? {
        get { _vmread64(0x2020) }
        set { _vmwrite64(0x2020, newValue) }
    }

    var eoiExitBitmap3: UInt64? {
        get { _vmread64(0x2022) }
        set { _vmwrite64(0x2022, newValue) }
    }
    /****
     var eptpListAddress: PhysAddress? {
     get {
     if let addr = _vmread64(0x2024) { return PhysAddress(RawAddress(addr)) }
     return nil
     }
     set { _vmwrite64(0x2024, UInt64(newValue!.value)) }
     }

     var vmreadBitmapAddress: PhysAddress? {
     get {
     if let addr = _vmread64(0x2026) { return PhysAddress(RawAddress(addr)) }
     return nil
     }
     set { _vmwrite64(0x2026, UInt64(newValue!.value)) }
     }

     var vmwriteBitmapAddress: PhysAddress? {
     get {
     if let addr = _vmread64(0x2028) { return PhysAddress(RawAddress(addr)) }
     return nil
     }
     set { _vmwrite64(0x2028, UInt64(newValue!.value)) }
     }

     var vExceptionInfoAddress: PhysAddress? {
     get {
     if let addr = _vmread64(0x202A) { return PhysAddress(RawAddress(addr)) }
     return nil
     }
     set { _vmwrite64(0x202A, UInt64(newValue!.value)) }
     }

     var xssExitingBitmap: UInt64? {
     get { _vmread64(0x202C) }
     set { _vmwrite64(0x202C, newValue) }
     }

     var enclsExitingBitmap: UInt64? {
     get { _vmread64(0x202E) }
     set { _vmwrite64(0x202E, newValue) }
     }

     var subPagePermissionTablePtr: PhysAddress? {
     get {
     if let addr = _vmread64(0x2030) { return PhysAddress(RawAddress(addr)) }
     return nil
     }
     set { _vmwrite64(0x2030, UInt64(newValue!.value)) }
     }
     *****/
    var tscMultiplier: UInt64? {
        get { _vmread64(0x2032) }
        set { _vmwrite64(0x2032, newValue) }
    }

    // 64-Bit Read-Only Data Field
    var guestPhysAddress: UInt64? { _vmread64(0x2400) }

    // 64-Bit Guest-State Fields
    var vmcsLinkPointer: UInt64? {
        get { _vmread64(0x2800) }
        set { _vmwrite64(0x2800, newValue) }
    }

    var guestIA32DebugCtl: UInt64? {
        get { _vmread64(0x2802) }
        set { _vmwrite64(0x2802, newValue) }
    }

    var guestIA32PAT: UInt64? {
        get { _vmread64(0x2804) }
        set { _vmwrite64(0x2804, newValue) }
    }

    var guestIA32EFER: UInt64? {
        get { _vmread64(0x2806) }
        set { _vmwrite64(0x2806, newValue) }
    }

    var guestIA32PerfGlobalCtrl: UInt64? {
        get { _vmread64(0x2808) }
        set { _vmwrite64(0x2808, newValue) }
    }

    var guestPDPTE0: UInt64? {
        get { _vmread64(0x280A) }
        set { _vmwrite64(0x280A, newValue) }
    }

    var guestPDPTE1: UInt64? {
        get { _vmread64(0x280C) }
        set { _vmwrite64(0x280C, newValue) }
    }

    var guestPDPTE2: UInt64? {
        get { _vmread64(0x280E) }
        set { _vmwrite64(0x280E, newValue) }
    }

    var guestPDPTE3: UInt64? {
        get { _vmread64(0x2810) }
        set { _vmwrite64(0x2810, newValue) }
    }

    var guestIA32bndcfgs: UInt64? {
        get { _vmread64(0x2812) }
        set { _vmwrite64(0x2812, newValue) }
    }

    var guestIA32RtitCtl: UInt64? {
        get { _vmread64(0x2814) }
        set { _vmwrite64(0x2814, newValue) }
    }

    // 64-Bit Host-State Fields
    var hostIA32PAT: UInt64? {
        get { _vmread64(0x2C00) }
        set { _vmwrite64(0x2C00, newValue) }
    }

    var hostIA32EFER: UInt64? {
        get { _vmread64(0x2C02) }
        set { _vmwrite64(0x2C02, newValue) }
    }

    var hostIA32PerfGlobalCtrl: UInt64? {
        get { _vmread64(0x2C04) }
        set { _vmwrite64(0x2C04, newValue) }
    }

    // 32Bit Control Fields
    var pinBasedVMExecControls: UInt32? {
        get { _vmread32(0x4000) }
        set { _vmwrite32(0x4000, newValue) }
    }

    var primaryProcVMExecControls: UInt32? {
        get { _vmread32(0x4002) }
        set { _vmwrite32(0x4002, newValue) }
    }

    var exceptionBitmap: UInt32? {
        get { _vmread32(0x4004) }
        set { _vmwrite32(0x4004, newValue) }
    }

    var pagefaultErrorCodeMask: UInt32? {
        get { _vmread32(0x4006) }
        set { _vmwrite32(0x4006, newValue) }
    }

    var pagefaultErrorCodeMatch: UInt32? {
        get { _vmread32(0x4008) }
        set { _vmwrite32(0x4008, newValue) }
    }

    var cr3TargetCount: UInt32? {
        get { _vmread32(0x400A) }
        set { _vmwrite32(0x400A, newValue) }
    }

    var vmExitControls: UInt32? {
        get { _vmread32(0x400C) }
        set { _vmwrite32(0x400C, newValue) }
    }

    var vmExitMSRStoreCount: UInt32? {
        get { _vmread32(0x400E) }
        set { _vmwrite32(0x400E, newValue) }
    }

    var vmExitMSRLoadCount: UInt32? {
        get { _vmread32(0x4010) }
        set { _vmwrite32(0x4010, newValue) }
    }

    var vmEntryControls: UInt32? {
        get { _vmread32(0x4012) }
        set { _vmwrite32(0x4012, newValue) }
    }

    var vmEntryMSRLoadCount: UInt32? {
        get { _vmread32(0x4014) }
        set { _vmwrite32(0x4014, newValue) }
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
        var deliverErrorCode: Bool { bits[11] == 1}
        var reserved: Int { Int(bits[12...30]) }
        var valid: Bool { bits[31] == 1}

        init?(_ rawValue: UInt32?) {
            guard let rawValue = rawValue else { return nil }
            bits = BitArray32(rawValue)
        }
    }


    var vmEntryInterruptInfo: VMEntryInterruptionInfoField? {
        get { VMEntryInterruptionInfoField(_vmread32(0x4016)) }
        set { _vmwrite32(0x4016, newValue?.rawValue) }
    }

    var vmEntryExceptionErrorCode: UInt32? {
        get { _vmread32(0x4018) }
        set { _vmwrite32(0x4018, newValue) }
    }

    var vmEntryInstructionLength: UInt32? {
        get { _vmread32(0x401A) }
        set { _vmwrite32(0x401A, newValue) }
    }

    var tprThreshold: UInt32? {
        get { _vmread32(0x401C) }
        set { _vmwrite32(0x401C, newValue) }
    }

    var secondaryProcVMExecControls: UInt32? {
        get { _vmread32(0x401E) }
        set { _vmwrite32(0x401E, newValue) }
    }

    /*
     private var supportsPLE: Bool {
     if let flag = vmExecSecondary?.pauseLoopExiting.allowedToBeOne {
     return flag
     }
     return false
     }

     var pleGap: UInt32? {
     get { return supportsPLE ? _vmread32(0x4020) : nil }
     set {
     if supportsPLE {
     _vmwrite32(0x4020, newValue)
     }
     }
     }

     var pleWindow: UInt32? {
     get { return supportsPLE ? _vmread32(0x4022) : nil }
     set {
     if supportsPLE {
     _vmwrite32(0x4022, newValue)
     }
     }
     }
     */
    // Read only Data fields
    var vmInstructionError: UInt32? { _vmread32(0x4400) }
    var exitReason:         VMXExit? {
        guard let reason = _vmread32(0x4402) else { return nil }
        return VMXExit(reason)
    }
    var vmExitIntInfo:      UInt32? { _vmread32(0x4404) }
    var vmExitIntErrorCode: UInt32? { _vmread32(0x4406) }
    var idtVectorInfoField: UInt32? { _vmread32(0x4408) }
    var idtVectorErrorCode: UInt32? { _vmread32(0x440A) }
    var vmExitInstrLen:     UInt32? { _vmread32(0x440C) }
    var vmExitInstrInfo:    UInt32? { _vmread32(0x440E) }

    // 32bit Guest State Fields
    var guestESLimit: UInt32? {
        get { _vmread32(0x4800) }
        set { _vmwrite32(0x4800, newValue) }
    }

    var guestCSLimit: UInt32? {
        get { _vmread32(0x4802) }
        set { _vmwrite32(0x4802, newValue) }
    }
    var guestSSLimit: UInt32? {
        get { _vmread32(0x4804) }
        set { _vmwrite32(0x4804, newValue) }
    }
    var guestDSLimit: UInt32? {
        get { _vmread32(0x4806) }
        set { _vmwrite32(0x4806, newValue) }
    }
    var guestFSLimit: UInt32? {
        get { _vmread32(0x4808) }
        set { _vmwrite32(0x4808, newValue) }
    }
    var guestGSLimit: UInt32? {
        get { _vmread32(0x480A) }
        set { _vmwrite32(0x480A, newValue) }
    }
    var guestLDTRLimit: UInt32? {
        get { _vmread32(0x480C) }
        set { _vmwrite32(0x480C, newValue) }
    }
    var guestTRLimit: UInt32? {
        get { _vmread32(0x480E) }
        set { _vmwrite32(0x480E, newValue) }
    }
    var guestGDTRLimit: UInt32? {
        get { _vmread32(0x4810) }
        set { _vmwrite32(0x4810, newValue) }
    }

    var guestIDTRLimit: UInt32? {
        get { _vmread32(0x4812) }
        set { _vmwrite32(0x4812, newValue) }
    }

    var guestESAccessRights: UInt32? {
        get { _vmread32(0x4814) }
        set { _vmwrite32(0x4814, newValue) }
    }

    var guestCSAccessRights: UInt32? {
        get { _vmread32(0x4816) }
        set { _vmwrite32(0x4816, newValue) }
    }

    var guestSSAccessRights: UInt32? {
        get { _vmread32(0x4818) }
        set { _vmwrite32(0x4818, newValue) }
    }

    var guestDSAccessRights: UInt32? {
        get { _vmread32(0x481A) }
        set { _vmwrite32(0x481A, newValue) }
    }

    var guestFSAccessRights: UInt32? {
        get { _vmread32(0x481C) }
        set { _vmwrite32(0x481C, newValue) }
    }

    var guestGSAccessRights: UInt32? {
        get { _vmread32(0x481E) }
        set { _vmwrite32(0x481E, newValue) }
    }

    var guestLDTRAccessRights: UInt32? {
        get { _vmread32(0x4820) }
        set { _vmwrite32(0x4820, newValue) }
    }

    var guestTRAccessRights: UInt32? {
        get { _vmread32(0x4822) }
        set { _vmwrite32(0x4822, newValue) }
    }

    struct InterruptibilityState {
        private let bits: BitArray32
        var rawValue: UInt32 { bits.rawValue }

        var blockingBySTI: Bool         { bits[0] == 1 }
        var blockingByMovSS: Bool       { bits[1] == 1 }
        var blockingBySMI: Bool          { bits[2] == 1 }
        var blockingByNMI: Bool          { bits[3] == 1}
        var enclaveInterruption: Bool   { bits[4] == 1 }
        var reserved: Int               { Int(bits[5...31]) }

        init?(_ rawValue: UInt32?) {
            guard let rawValue = rawValue else { return nil }
            bits = BitArray32(rawValue)
        }
    }


    var guestInterruptibilityState: InterruptibilityState? {
        get { InterruptibilityState(_vmread32(0x4824)) }
        set { _vmwrite32(0x4824, newValue?.rawValue) }
    }

    var guestActivityState: UInt32? {
        get { _vmread32(0x4826) }
        set { _vmwrite32(0x4826, newValue) }
    }

    var guestSMBASE: UInt32? {
        get { _vmread32(0x4828) }
        set { _vmwrite32(0x4828, newValue) }
    }

    var guestIA32SysenterCS: UInt32? {
        get { _vmread32(0x482A) }
        set { _vmwrite32(0x482A, newValue) }
    }

    var vmxPreemptionTimerValue: UInt32? {
        get { _vmread32(0x482E) }
        set { _vmwrite32(0x482E, newValue) }
    }

    var hostIA32SysenterCS: UInt32? {
        get { _vmread32(0x4C00) }
        set { _vmwrite32(0x4C00, newValue) }
    }

    var cr0mask: UInt? {
        get { _vmreadNatural(0x6000) }
        set { _vmwriteNatural(0x6000, newValue) }
    }

    var cr4mask: UInt? {
        get { _vmreadNatural(0x6002) }
        set { _vmwriteNatural(0x6002, newValue) }
    }

    var cr0ReadShadow: CPU.CR0Register? {
        get { return _vmread64(0x6004).map { CPU.CR0Register($0) } }
        set { _vmwrite64(0x6004, newValue?.value) }
    }

    var cr4ReadShadow: CPU.CR4Register? {
        get { return _vmread64(0x6006).map { CPU.CR4Register($0) } }
        set { _vmwrite64(0x6006, newValue?.value) }
    }

    var cr3TargetValue0: UInt? {
        get { _vmreadNatural(0x6008) }
        set { _vmwriteNatural(0x6008, newValue) }
    }

    var cr3TargetValue1: UInt? {
        get { _vmreadNatural(0x600A) }
        set { _vmwriteNatural(0x600A, newValue) }
    }

    var cr3TargetValue2: UInt? {
        get { _vmreadNatural(0x600C) }
        set { _vmwriteNatural(0x600C, newValue) }
    }

    var cr3TargetValue3: UInt? {
        get { _vmreadNatural(0x600E) }
        set { _vmwriteNatural(0x600E, newValue) }
    }

    // Natural width Read-Only data fields
    var exitQualification: UInt? { _vmreadNatural(0x6400) }
    var ioRCX: UInt? { _vmreadNatural(0x6402) }
    var ioRSI: UInt? { _vmreadNatural(0x6404) }
    var ioRDI: UInt? { _vmreadNatural(0x6406) }
    var ioRIP: UInt? { _vmreadNatural(0x6408) }
    var guestLinearAddress: UInt? { _vmreadNatural(0x640A) }

    // Natural width Guest state fields
    var guestCR0: CPU.CR0Register? {
        get { return _vmread64(0x6800).map { CPU.CR0Register($0) } }
        set { _vmwrite64(0x6800, newValue?.value) }
    }

    var guestCR3: CPU.CR3Register? {
        get { return _vmread64(0x6802).map { CPU.CR3Register($0) } }
        set { _vmwrite64(0x6802, newValue?.value) }
    }

    var guestCR4: CPU.CR4Register? {
        get { return _vmread64(0x6804).map { CPU.CR4Register($0) } }
        set { _vmwrite64(0x6804, newValue?.value) }
    }

    var guestESBase: UInt? {
        get { _vmreadNatural(0x6806) }
        set { _vmwriteNatural(0x6806, newValue) }
    }

    var guestCSBase: UInt? {
        get { _vmreadNatural(0x6808) }
        set { _vmwriteNatural(0x6808, newValue) }
    }

    var guestSSBase: UInt? {
        get { _vmreadNatural(0x680A) }
        set { _vmwriteNatural(0x680A, newValue) }
    }

    var guestDSBase: UInt? {
        get { _vmreadNatural(0x680C) }
        set { _vmwriteNatural(0x680C, newValue) }
    }

    var guestFSBase: UInt? {
        get { _vmreadNatural(0x680E) }
        set { _vmwriteNatural(0x680E, newValue) }
    }

    var guestGSBase: UInt? {
        get { _vmreadNatural(0x6810) }
        set { _vmwriteNatural(0x6810, newValue) }
    }

    var guestLDTRBase: UInt? {
        get { _vmreadNatural(0x6812) }
        set { _vmwriteNatural(0x6812, newValue) }
    }

    var guestTRBase: UInt? {
        get { _vmreadNatural(0x6814) }
        set { _vmwriteNatural(0x6814, newValue) }
    }

    var guestGDTRBase: UInt? {
        get { _vmreadNatural(0x6816) }
        set { _vmwriteNatural(0x6816, newValue) }
    }

    var guestIDTRBase: UInt? {
        get { _vmreadNatural(0x6818) }
        set { _vmwriteNatural(0x6818, newValue) }
    }

    var guestDR7: UInt? {
        get { _vmreadNatural(0x681A) }
        set { _vmwriteNatural(0x681A, newValue) }
    }

    var guestRSP: UInt? {
        get { _vmreadNatural(0x681C) }
        set { _vmwriteNatural(0x681C, newValue) }
    }

    var guestRIP: UInt? {
        get { _vmreadNatural(0x681E) }
        set { _vmwriteNatural(0x681E, newValue) }
    }

    var guestRFlags: UInt? {
        get { _vmreadNatural(0x6820) }
        set { _vmwriteNatural(0x6820, newValue) }
    }

    struct PendingDebugExceptions {
        let bits: BitArray64
        var rawValue: UInt { UInt(bits.rawValue) }

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

        init?(_ rawValue: UInt?) {
            guard let rawValue = rawValue else { return nil }
            bits = BitArray64(rawValue)
        }
    }

    var guestPendingDebugExceptions: PendingDebugExceptions? {
        get { PendingDebugExceptions(_vmreadNatural(0x6822)) }
        set { _vmwriteNatural(0x6822, newValue?.rawValue) }
    }

    var guestIA32SysenterESP: UInt? {
        get { _vmreadNatural(0x6824) }
        set { _vmwriteNatural(0x6824, newValue) }
    }

    var guestIA32SysenterEIP: UInt? {
        get { _vmreadNatural(0x6826) }
        set { _vmwriteNatural(0x6826, newValue) }
    }

    // Natural-Width Host-State Fields
    var hostCR0: CPU.CR0Register? {
        get { return _vmread64(0x6C00).map { CPU.CR0Register($0) } }
        set { _vmwrite64(0x6C00, newValue?.value) }
    }

    var hostCR3: CPU.CR3Register? {
        get { return _vmread64(0x6C02).map { CPU.CR3Register($0) } }
        set { _vmwrite64(0x6C02, newValue?.value) }
    }

    var hostCR4: CPU.CR4Register? {
        get { return _vmread64(0x6C04).map{ CPU.CR4Register($0) } }
        set { _vmwrite64(0x6C04, newValue?.value) }
    }

    var hostFSBase: UInt? {
        get { _vmreadNatural(0x6C06) }
        set { _vmwriteNatural(0x6C06, newValue) }
    }

    var hostGSBase: UInt? {
        get { _vmreadNatural(0x6C08) }
        set { _vmwriteNatural(0x6C08, newValue) }
    }

    var hostTRBase: UInt? {
        get { _vmreadNatural(0x6C0A) }
        set { _vmwriteNatural(0x6C0A, newValue) }
    }

    var hostGDTRBase: UInt? {
        get { _vmreadNatural(0x6C0C) }
        set { _vmwriteNatural(0x6C0C, newValue) }
    }

    var hostIDTRBase: UInt? {
        get { _vmreadNatural(0x6C0E) }
        set { _vmwriteNatural(0x6C0E, newValue) }
    }

    var hostIA32SysenterESP: UInt? {
        get { _vmreadNatural(0x6C10) }
        set { _vmwriteNatural(0x6C10, newValue) }
    }

    var hostIA32SysenterEIP: UInt? {
        get { _vmreadNatural(0x6C12) }
        set { _vmwriteNatural(0x6C12, newValue) }
    }

    var hostRSP: UInt? {
        get { _vmreadNatural(0x6C14) }
        set { _vmwriteNatural(0x6C14, newValue) }
    }

    var hostRIP: UInt? {
        get { _vmreadNatural(0x6C16) }
        set { _vmwriteNatural(0x6C16, newValue) }
    }


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


    func vmread16(_ index: UInt32) -> Result<UInt16, VMXError> {
        var data: UInt64 = 0
        let error = VMXError(vmread(index, &data))
        switch error {
            case .vmSucceed:
                return .success(UInt16(data))
            default:
                return .failure(error)
        }
    }


    func vmread32(_ index: UInt32) -> Result<UInt32, VMXError> {
        var data: UInt64 = 0
        let error = VMXError(vmread(index, &data))
        switch error {
            case .vmSucceed:
                return .success(UInt32(data))
            default:
                return .failure(error)
        }
    }


    func vmread64(_ index: UInt32) -> Result<UInt64, VMXError> {
        var data: UInt64 = 0
        let error = VMXError(vmread(index, &data))
        switch error {
            case .vmSucceed:
                return .success(data)
            default:
                return .failure(error)
        }
    }


    func vmwrite16(_ index: UInt32, _ data: UInt16) -> VMXError? {
        let error = vmwrite(index, UInt64(data))
        guard error == 0 else {
            return  VMXError(error)
        }
        return nil
    }


    func vmwrite32(_ index: UInt32, _ data: UInt32) -> VMXError? {
        let error = vmwrite(index, UInt64(data))
        guard error == 0 else {
            return VMXError(error)
        }
        return nil
    }


    func vmwrite64(_ index: UInt32, _ data: UInt64) -> VMXError? {
        let error = vmwrite(index, data)
        guard error == 0 else {
            return VMXError(error)
        }
        return nil
    }


    private func _readError(_ index: UInt32, _ vmxError: VMXError) {
        print("VMXError: vmread(\(String(index, radix: 16))):", vmxError)
    }


    private func _vmread16(_ index: UInt32) -> UInt16? {
        switch vmread16(index) {
            case .failure(let vmxError):
                print("VMXError: vmread16(\(String(index, radix: 16))):", vmxError)
                return nil
            case .success(let result):
                return result
        }
    }

    private func _vmread32(_ index: UInt32) -> UInt32? {
        switch vmread32(index) {
            case .failure(let vmxError):
                print("VMXError: vmread32(\(String(index, radix: 16))):", vmxError)
                return nil
            case .success(let result):
                return result
        }
    }

    private func _vmread64(_ index: UInt32) -> UInt64? {
        switch vmread64(index) {
            case .failure(let vmxError):
                print("VMXError: vmread64(\(String(index, radix: 16))):", vmxError)
                return nil
            case .success(let result):
                return result
        }
    }

    private func _vmreadNatural(_ index: UInt32) -> UInt? {
        switch vmread64(index) {
            case .failure(let vmxError):
                print("VMXError: vmread64(\(String(index, radix: 16))):", vmxError)
                return nil
            case .success(let result):
                return UInt(result)
        }
    }

    private func _vmwrite16(_ index: UInt32, _ data: UInt16?) {
        if let data = data, let vmxError = vmwrite16(index, data) {
            print("VMXError: vmread16(\(String(index, radix: 16)), \(String(index, radix: 16))):", vmxError)
        }
    }

    private func _vmwrite32(_ index: UInt32, _ data: UInt32?) {
        if let data = data, let vmxError = vmwrite32(index, data) {
            print("VMXError: vmread32(\(String(index, radix: 16)), \(String(index, radix: 16))):", vmxError)
        }
    }

    private func _vmwrite64(_ index: UInt32, _ data: UInt64?) {
        if let data = data, let vmxError = vmwrite64(index, data) {
            print("VMXError: vmread64(\(String(index, radix: 16)), \(String(index, radix: 16))):", vmxError)
        }
    }

    private func _vmwriteNatural(_ index: UInt32, _ data: UInt?) {
        if let data = data, let vmxError = vmwrite64(index, UInt64(data)) {
            print("VMXError: vmread64(\(String(index, radix: 16)), \(String(index, radix: 16))):", vmxError)
        }
    }

}





#endif
