//
//  vmxmsr.swift
//  tests
//
//  Created by Simon Evans on 28/08/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//
// MSRs related to VMX operation

#if os(macOS)

import Hypervisor
struct VMXAllowedBits {
    let allowedToBeZero: Bool
    let allowedToBeOne: Bool

    init(_ bits :BitArray64, _ index: Int) {
        // Note that bits allowed to be zero are set to 0 but these are flipped
        // to enable 'allowedToBeZero == true' if they are zero
        allowedToBeZero = !Bool(bits[index])
        allowedToBeOne = Bool(bits[index + 32])
    }
}

protocol VMXAllowedBitsP {
    var low: UInt32 { get }
    var high: UInt32 { get }
    var value: UInt64 { get }

    var defaultValue: UInt32 { get }
    func checkAllowed0Bits(in: UInt32) -> Bool
    func checkAllowed1Bits(in: UInt32) -> Bool
    func checkAllowedBits(in: UInt32) -> Bool
}

extension VMXAllowedBitsP {
    var value: UInt64 {
        UInt64(high) << 32 | UInt64(low)
    }

    func createValue(_ value: UInt32) -> UInt32 {
        var result: UInt32 = value
        result |= low   // bits 0:31 contains allowed 0-settings. If bit is 1 it must be set
        result &= high  // bits 32:63 contains allowed 1-settings. If bit is 0 it must be cleared
        return result
    }

    var defaultValue: UInt32 {
        createValue(0)
    }

    func checkAllowed0Bits(in value: UInt32) -> Bool {
        let mustBe0 = ~low & ~high
        return (~value & mustBe0) == mustBe0
    }

    func checkAllowed1Bits(in value: UInt32) -> Bool {
        let mustBe1 = low & high
        return (value & mustBe1) == mustBe1
    }

    func checkAllowedBits(in value: UInt32) -> Bool {
        return checkAllowed0Bits(in: value) && checkAllowed1Bits(in: value)
    }
}

/*
struct VMXBasicInfo: CustomStringConvertible {

    private let bits: BitArray64

    let recommendedMemoryType: CPU.PATEntry

    var vmcsRevisionId: UInt32 { UInt32(bits[0...30]) }
    var vmxRegionSize: Int { Int(bits[32...44]) }
    var physAddressWidthMaxBits: UInt {
        Bool(bits[48]) ? 32 : CPU.capabilities.maxPhyAddrBits
    }
    var supportsDualMonitorOfSMM: Bool { Bool(bits[48]) }
    var vmExitsDueToInOut: Bool { Bool(bits[54]) }
    var vmxControlsCanBeCleared: Bool { Bool(bits[55]) }


    var maxPhysicalAddress: UInt {
        if physAddressWidthMaxBits == UInt.bitWidth {
            return UInt.max
        }
        else if physAddressWidthMaxBits == 0 {
            return 0
        } else {
            return (1 << physAddressWidthMaxBits) - 1
        }
    }

    var description: String {
        var str = "VMX: Basic Info: revision ID: \(vmcsRevisionId) \(String(vmcsRevisionId, radix: 16))\n"
        str += "VMX: region size: \(vmxRegionSize) bytes "
        str += "max address bits: \(physAddressWidthMaxBits)\n"
        str += "VMX: supportsDualMonitor: \(supportsDualMonitorOfSMM) "
        str += "recommendedMemoryType: \(recommendedMemoryType) "
        return str
    }

    init() {
        bits = BitArray64(CPU.readMSR(0x480))
        guard bits[31] == 0 else {
            fatalError("Bit31 of IA32_VMX_BASIC is not 0")
        }

        let memTypeVal = UInt8(bits[50...53])
        guard let memoryType = CPU.PATEntry(rawValue: memTypeVal) else {
            fatalError("Invalid memoryType: \(memTypeVal)")
        }
        recommendedMemoryType = memoryType

        guard vmxRegionSize > 0 && vmxRegionSize <= 4096 else {
            fatalError("vmxRegionSize: \(vmxRegionSize) should be 1-4096")
        }
    }
}
*/

struct VMXPinBasedControls: VMXAllowedBitsP {
    let low: UInt32
    let high: UInt32

    init() {
        var value: UInt64 = 0
        try! hvError(hv_vmx_read_capability(HV_VMX_CAP_PINBASED, &value))

        low = UInt32(truncatingIfNeeded: value)
        high = UInt32(truncatingIfNeeded: (value >> 32))
//        (low, high) = CPU.readMSR(0x481)
    }
}


struct VMXPrimaryProcessorBasedControls: VMXAllowedBitsP {
    let bits: BitArray64
    let low: UInt32
    let high: UInt32

    init() {
        var value: UInt64 = 0
        try! hvError(hv_vmx_read_capability(HV_VMX_CAP_PROCBASED, &value))

        low = UInt32(truncatingIfNeeded: value)
        high = UInt32(truncatingIfNeeded: (value >> 32))
        bits = BitArray64(value)
//        (low, high) = CPU.readMSR(0x482)
//        bits = BitArray64(UInt64(high) << 32 | UInt64(low))

    }

    var intWindowExiting:           VMXAllowedBits { VMXAllowedBits(bits, 2)  }
    var useTSCOffsetting:           VMXAllowedBits { VMXAllowedBits(bits, 3)  }
    var hltExiting:                 VMXAllowedBits { VMXAllowedBits(bits, 7)  }
    var invlpgExiting:              VMXAllowedBits { VMXAllowedBits(bits, 9)  }
    var mwaitExiting:               VMXAllowedBits { VMXAllowedBits(bits, 10) }
    var rdpmcExiting:               VMXAllowedBits { VMXAllowedBits(bits, 11) }
    var rdtscExiting:               VMXAllowedBits { VMXAllowedBits(bits, 12) }
    var cr3LoadExiting:             VMXAllowedBits { VMXAllowedBits(bits, 15) }
    var cr3StoreExiting:            VMXAllowedBits { VMXAllowedBits(bits, 16) }
    var cr8LoadExiting:             VMXAllowedBits { VMXAllowedBits(bits, 19) }
    var cr8StoreExiting:            VMXAllowedBits { VMXAllowedBits(bits, 20) }
    var useTPRShadow:               VMXAllowedBits { VMXAllowedBits(bits, 21) }
    var nmiWindowExiting:           VMXAllowedBits { VMXAllowedBits(bits, 22) }
    var movDRExiting:               VMXAllowedBits { VMXAllowedBits(bits, 23) }
    var unconditionalIOExiting:     VMXAllowedBits { VMXAllowedBits(bits, 24) }
    var useIOBitmaps:               VMXAllowedBits { VMXAllowedBits(bits, 25) }
    var monitorTrapFlag:            VMXAllowedBits { VMXAllowedBits(bits, 27) }
    var useMSRbitmaps:              VMXAllowedBits { VMXAllowedBits(bits, 28) }
    var monitorExiting:             VMXAllowedBits { VMXAllowedBits(bits, 29) }
    var pauseExiting:               VMXAllowedBits { VMXAllowedBits(bits, 30) }
    var activateSecondaryControls:  VMXAllowedBits { VMXAllowedBits(bits, 31) }
}

struct VMXExitControls: VMXAllowedBitsP {
    let low: UInt32
    let high: UInt32

    init() {
        var value: UInt64 = 0
        try! hvError(hv_vmx_read_capability(HV_VMX_CAP_EXIT, &value))

        low = UInt32(truncatingIfNeeded: value)
        high = UInt32(truncatingIfNeeded: (value >> 32))
//        bits = BitArray64(value)
//        (low, high) = CPU.readMSR(0x483)
    }
}



struct VMXEntryControls: VMXAllowedBitsP {
    let low: UInt32
    let high: UInt32

    init() {
        var value: UInt64 = 0
        try! hvError(hv_vmx_read_capability(HV_VMX_CAP_ENTRY, &value))

        low = UInt32(truncatingIfNeeded: value)
        high = UInt32(truncatingIfNeeded: (value >> 32))
//        (low, high) = CPU.readMSR(0x484)
    }
}

/*
struct VMXMiscInfo: CustomStringConvertible {
    private let bits: BitArray64

    init() {
        bits = BitArray64(CPU.readMSR(0x485))
    }

    var description: String {
        var result = "value: " + String(bits.toUInt64(), radix: 16)
        result += " timerRatio: \(self.timerRatio)"
        result += " storesLMA: \(self.storesLMA)"
        result += " maxCR3TargetValues: \(self.maxCR3TargetValues)"
        result += " maxMSRinLoadList: \(self.maxMSRinLoadList)"
        return result
    }

    var timerRatio: Int { Int(bits[0...4]) }
    var storesLMA: Bool { Bool(bits[5]) }
    var supportsActivityStateHLT: Bool { Bool(bits[6]) }
    var supportsActivityStateShutdown: Bool { Bool(bits[7]) }
    var supportsActivityStateWaitForSIPI: Bool { Bool(bits[8]) }
    var allowsIPTinVMX: Bool { Bool(bits[14]) }
    var allowsSMBASEReadInSMM: Bool { Bool(bits[15]) }
    var maxCR3TargetValues: Int { Int(bits[16...24]) }
    var maxMSRinLoadList: Int { (Int(bits[25...27]) + 1) * 512 }
    var allowSMIBlocksInVMXOFF: Bool { Bool(bits[28]) }
    var vmwriteCanModifyVMExitFields: Bool { Bool(bits[29]) }
    var allowZeroLengthInstructionInjection: Bool { Bool(bits[30]) }
    var msegRevision: UInt32 { UInt32(bits[32...63]) }
}*/

/*
struct VMXFixedBits {
    let cr0Fixed0Bits: UInt64
    let cr0Fixed1Bits: UInt64 = CPU.readMSR(0x487)
    let cr4Fixed0Bits: UInt64 = CPU.readMSR(0x488)
    let cr4Fixed1Bits: UInt64 = CPU.readMSR(0x489)


    init() {
        var cr0zeroBits: UInt64 = CPU.readMSR(0x486)

        let vmxPrimaryCtrl = VMXPrimaryProcessorBasedControls()
        if vmxPrimaryCtrl.activateSecondaryControls.allowedToBeOne {
            let vmxSecondaryCtrl = VMXSecondaryProcessorBasedControls()
            if vmxSecondaryCtrl.unrestrictedGuest.allowedToBeOne {
                // CR0 PG and PE can be zero when unrestrictedGuest is allowed
                cr0zeroBits &= ~UInt64(0x8000_0001)
            }
        }
        cr0Fixed0Bits = cr0zeroBits
    }

    func updateCR0(bits: CPU.CR0Register) -> CPU.CR0Register {
        var result = bits.value | cr0Fixed0Bits
        result &= cr0Fixed1Bits
        return CPU.CR0Register(result)
    }

    func updateCR4(bits: CPU.CR4Register) -> CPU.CR4Register {
        var result = bits.value | cr4Fixed0Bits
        result &= cr4Fixed1Bits
        return CPU.CR4Register(result)
    }

    // Unrestricted guest is true when the PG and PE bits in CR0
    // DO NOT need to be set, determined from the CR0 Fixed0 Bits MSR
    var allowsUnrestrictedGuest: Bool {
        let cr0 = CPU.CR0Register(cr0Fixed0Bits)
        return !(cr0.protectionEnable || cr0.paging)
    }
}


struct VMXVMCSEnumeration {
    let bits: BitArray64

    var highestIndex: Int {
        return Int(bits[1...9])
    }

    var description: String {
        let idx = String(highestIndex, radix: 16)
        return "VMCS Enumeration highest index: \(idx)"
    }

    init() {
        bits = BitArray64(CPU.readMSR(0x48A))
    }
}
*/

struct VMXSecondaryProcessorBasedControls: VMXAllowedBitsP {
    let bits: BitArray64
    let low: UInt32
    let high: UInt32

    init() {
        var value: UInt64 = 0
        try! hvError(hv_vmx_read_capability(HV_VMX_CAP_PROCBASED2, &value))

        low = UInt32(truncatingIfNeeded: value)
        high = UInt32(truncatingIfNeeded: (value >> 32))
        bits = BitArray64(value)

//        (low, high) = CPU.readMSR(0x48B)
//        bits = BitArray64(UInt64(high) << 32 | UInt64(low))
    }

    var vitualizeApicAccesses:      VMXAllowedBits { VMXAllowedBits(bits, 0)  }
    var enableEPT:                  VMXAllowedBits { VMXAllowedBits(bits, 1)  }
    var descriptorTableExiting:     VMXAllowedBits { VMXAllowedBits(bits, 2)  }
    var enableRDTSCP:               VMXAllowedBits { VMXAllowedBits(bits, 3)  }
    var virtualizeX2ApicMode:       VMXAllowedBits { VMXAllowedBits(bits, 4)  }
    var enableVPID:                 VMXAllowedBits { VMXAllowedBits(bits, 5)  }
    var wbinvdExiting:              VMXAllowedBits { VMXAllowedBits(bits, 6)  }
    var unrestrictedGuest:          VMXAllowedBits { VMXAllowedBits(bits, 7)  }
    var apicRegisterVirtualization: VMXAllowedBits { VMXAllowedBits(bits, 8)  }
    var virtualInterruptDelivery:   VMXAllowedBits { VMXAllowedBits(bits, 9)  }
    var pauseLoopExiting:           VMXAllowedBits { VMXAllowedBits(bits, 10) }
    var rdrandExiting:              VMXAllowedBits { VMXAllowedBits(bits, 11) }
    var enableInvpcid:              VMXAllowedBits { VMXAllowedBits(bits, 12) }
    var enableVMFunctions:          VMXAllowedBits { VMXAllowedBits(bits, 13) }
    var vmcsShadowing:              VMXAllowedBits { VMXAllowedBits(bits, 14) }
    var enableEnclsExiting:         VMXAllowedBits { VMXAllowedBits(bits, 15) }
    var rdseedExiting:              VMXAllowedBits { VMXAllowedBits(bits, 16) }
    var enablePML:                  VMXAllowedBits { VMXAllowedBits(bits, 17) }
    var eptViolation:               VMXAllowedBits { VMXAllowedBits(bits, 18) }
    var concealVMXFromPT:           VMXAllowedBits { VMXAllowedBits(bits, 19) }
    var enableXSAVES:               VMXAllowedBits { VMXAllowedBits(bits, 20) }
    var modeBasedExecCtrlForEPT:    VMXAllowedBits { VMXAllowedBits(bits, 22) }
    var subpageWritePermsForEPT:    VMXAllowedBits { VMXAllowedBits(bits, 23) }
    var iptUsesGuestPhysAddress:    VMXAllowedBits { VMXAllowedBits(bits, 24) }
    var useTSCScaling:              VMXAllowedBits { VMXAllowedBits(bits, 25) }
    var enableUserWaitAndPause:     VMXAllowedBits { VMXAllowedBits(bits, 26) }
    var enableENCLVExiting:         VMXAllowedBits { VMXAllowedBits(bits, 28) }
}

/*
struct VMX_EPT_VPID_CAP: CustomStringConvertible {
    let bits: BitArray64

    var description: String {
        var result = "EPT_VPID_CAP:"
        if supportsExecOnlyEPT { result += " supportsExecOnlyEPT" }
        if supportsPageWalk4   { result += " supportsPageWalk4" }
        if allowsEPTUncacheableType { result += " allowsEPTUncacheableType" }
        if allowsEPTWriteBackType { result += " allowsEPTWriteBackType" }
        if allowsEPT2mbPages { result += " allowsEPT2mbPages" }
        if allowsEPT1gbPages { result += " allowsEPT1gbPages" }
        if supportsINVEPT { result += " supportsINVEPT" }
        if supportsSingleContextINVEPT { result += " supportsSingleContextINVEPT" }
        if supportsAllContextINVEPT { result += " supportsAllContextINVEPT" }
        if supportsEPTDirtyAccessedFlags { result += " supportsEPTDirtyAccessedFlags" }
        if reportsVMExitInfoForEPTViolations { result += " reportsVMExitInfoForEPTViolations" }
        if supportsINVVIPD { result += " supportsINVVIPD" }
        if supportsIndividualAddressINVVIPD { result += " supportsIndividualAddressINVVIPD" }
        if supportsSingleContextINVVIPD { result += " supportsSingleContextINVVIPD" }
        if supportsAllContextINVVIPD { result += " supportsAllContextINVVIPD" }
        if supportsSingleContextRetainingGlobalsINVVIPD { result += " supportsSingleContextRetainingGlobalsINVVIPD" }
        return result
    }

    var supportsExecOnlyEPT: Bool { Bool(bits[0]) }
    var supportsPageWalk4: Bool { Bool(bits[6]) }
    var allowsEPTUncacheableType: Bool { Bool(bits[8]) }
    var allowsEPTWriteBackType: Bool { Bool(bits[14]) }
    var allowsEPT2mbPages: Bool { Bool(bits[16]) }
    var allowsEPT1gbPages: Bool { Bool(bits[17]) }
    var supportsINVEPT: Bool { Bool(bits[20]) }
    var supportsEPTDirtyAccessedFlags: Bool { Bool(bits[21]) }
    var reportsVMExitInfoForEPTViolations: Bool { Bool(bits[22]) }
    var supportsSingleContextINVEPT: Bool { Bool(bits[25]) }
    var supportsAllContextINVEPT: Bool { Bool(bits[26]) }
    var supportsINVVIPD: Bool { Bool(bits[32]) }
    var supportsIndividualAddressINVVIPD: Bool { Bool(bits[40]) }
    var supportsSingleContextINVVIPD: Bool { Bool(bits[41]) }
    var supportsAllContextINVVIPD: Bool { Bool(bits[42]) }
    var supportsSingleContextRetainingGlobalsINVVIPD: Bool { Bool(bits[43]) }

    init() {
        bits = BitArray64(CPU.readMSR(0x48C))
    }
}

struct VMXTruePinBasedControls: VMXAllowedBitsP {
    let low: UInt32
    let high: UInt32

    init() {
        (low, high) = CPU.readMSR(0x48D)
    }
}

struct VMXTruePrimaryProcessorBasedControls: VMXAllowedBitsP {
    let low: UInt32
    let high: UInt32

    init() {
        (low, high) = CPU.readMSR(0x48E)
    }
}

struct VMXTrueExitControls: VMXAllowedBitsP {
    let low: UInt32
    let high: UInt32

    init() {
        (low, high) = CPU.readMSR(0x48f)
    }
}


struct VMXTrueEntryControls: VMXAllowedBitsP {
    let low: UInt32
    let high: UInt32

    init() {
        (low, high) = CPU.readMSR(0x490)
    }
}


struct VMXVMFunc {
    let bits: BitArray64

    var eptpSwitching: Bool { Bool(bits[0]) }

    init() {
        bits = BitArray64(CPU.readMSR(0x491))
    }
}


struct VMXMSRs {

    let vmxBasicInfo: VMXBasicInfo
    let vmxPinBasedControls: VMXPinBasedControls
    let vmxPrimaryProcessorBasedControls: VMXPrimaryProcessorBasedControls
    let vmxExitControls: VMXExitControls
    let vmxEntryControls: VMXEntryControls
    let vmxMiscInfo: VMXMiscInfo
    let vmxFixedBits: VMXFixedBits
    let vmxVmcsEnumeration: VMXVMCSEnumeration
    let vmxSecondaryProcessorBasedControls: VMXSecondaryProcessorBasedControls?
    let vmxEptVpidCap: VMX_EPT_VPID_CAP?
    let vmxTruePinBasedControls: VMXTruePinBasedControls?
    let vmxTruePrimaryProcessorBasedControls: VMXTruePrimaryProcessorBasedControls?
    let vmxTrueExitControls: VMXTrueExitControls?
    let vmxTrueEntryControls: VMXTrueEntryControls?
    let vmxVmFunc: VMXVMFunc?

    init() {
        vmxBasicInfo = VMXBasicInfo()
        vmxPinBasedControls = VMXPinBasedControls()
        vmxPrimaryProcessorBasedControls = VMXPrimaryProcessorBasedControls()

        vmxExitControls = VMXExitControls()
        vmxEntryControls = VMXEntryControls()
        vmxMiscInfo = VMXMiscInfo()
        vmxFixedBits = VMXFixedBits()
        vmxVmcsEnumeration = VMXVMCSEnumeration()

        if vmxPrimaryProcessorBasedControls.activateSecondaryControls.allowedToBeOne {
            vmxSecondaryProcessorBasedControls = VMXSecondaryProcessorBasedControls()
        } else {
            vmxSecondaryProcessorBasedControls = nil
        }

        if let secondaryControls = vmxSecondaryProcessorBasedControls, secondaryControls.enableEPT.allowedToBeOne || secondaryControls.enableVPID.allowedToBeOne {
            vmxEptVpidCap = VMX_EPT_VPID_CAP()
        } else {
            vmxEptVpidCap = nil
        }

        if vmxBasicInfo.vmxControlsCanBeCleared {
            vmxTruePinBasedControls = VMXTruePinBasedControls()
            vmxTruePrimaryProcessorBasedControls = VMXTruePrimaryProcessorBasedControls()
            vmxTrueExitControls = VMXTrueExitControls()
            vmxTrueEntryControls = VMXTrueEntryControls()
        } else {
            vmxTruePinBasedControls = nil
            vmxTruePrimaryProcessorBasedControls = nil
            vmxTrueExitControls = nil
            vmxTrueEntryControls = nil
        }

        if let secondaryControls = vmxSecondaryProcessorBasedControls, secondaryControls.enableVMFunctions.allowedToBeOne {
            vmxVmFunc = VMXVMFunc()
        } else {
            vmxVmFunc = nil
        }
    }
}*/
#endif
