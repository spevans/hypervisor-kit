//
//  checkvmcs.swift
//  tests
//
//  Created by Simon Evans on 28/08/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//


#if os(macOS)

import Hypervisor

extension CPU {
    enum PATEntry: UInt8 {
              case Uncacheable = 0
              case WriteCombining = 1
              case WriteThrough = 4
              case WriteProtected = 5
              case WriteBack = 6
              case Uncached = 7
          }

}

extension VMCS {

    struct SegmentSelector {
        let bits: BitArray16

        var rpl: Int { Int(bits[0...1]) }
        var ti: Int { Int(bits[2]) }
        var gdtDescriptor: Bool { ti == 0 }
        var ldtDescriptor: Bool { !gdtDescriptor }
        var index: Int { Int(bits[3...15]) }
        var realModeBaseAddress: UInt32 { UInt32(bits.rawValue) << 4 }

        init(_ rawValue: UInt16) {
            bits = BitArray16(rawValue)
        }
    }

    struct AccessRights {
        let bits: BitArray32
        var rawValue: UInt32 { bits.rawValue }

        var segmentType: Int { Int(bits[0...3]) }
        var accessed: Bool { bits[0] == 1 }
        var readable: Bool { bits[1] == 1 }
        var codeSegment: Bool { bits[3] == 1 }
        var dataSegment: Bool { !codeSegment }

        var systemDescriptor: Bool { bits[4] == 0 }
        var codeOrDataDescriptor: Bool { !systemDescriptor }
        var privilegeLevel: Int { Int(bits[5...6]) }
        var segmentPresent: Bool { bits[7] == 1 }
        var reserved1: Int { Int(bits[8...11]) }
        var available: Bool { bits[12] == 1 }
        var longModeActive: Bool { bits[13] == 1 }
        var operationSize: Int { Int(bits[14]) }
        var is16BitSegment: Bool { operationSize == 0 }
        var is32BitSegment: Bool { !is16BitSegment }
        var granularity: Bool { bits[15] == 1 }
        var unusable: Bool { bits[16] == 1 }
        var usable: Bool { !unusable }
        var reserved2: Int { Int(bits[17...31]) }

        init(_ rawValue: UInt32) {
            bits = BitArray32(rawValue)
        }
    }

    func checkFieldsAreValid() throws {

        print("Checking VMCS fields")
        // These are VMCS or MSR lookups so read once
//        let maxPhysicalAddress = VMXBasicInfo().maxPhysicalAddress
        let maxCPUPhysicalAddress = CPU.capabilities.maxPhysicalAddress
        let vmEntryControls = BitArray32(try self.vmEntryControls())
        let vmExitControls = BitArray32(try self.vmExitControls())
        let vmExecutionControls = BitArray32(try self.pinBasedVMExecControls())
        let primaryControls = BitArray32(try self.primaryProcVMExecControls())
        let secondaryControls = BitArray32(try self.secondaryProcVMExecControls())
//        let vmxFixedBits = VMXFixedBits()
//        let vmxBasicInfo = VMXBasicInfo()
        let supports64Bit = true    // Should come from CPUID or LMA


        func checkCanonicalAddress(_ addr: UInt64) -> Bool {
            let bits = CPU.capabilities.maxPhyAddrBits
            guard bits < 64 else { return true }
            let mask: UInt64 = ~((1 << bits) - 1)
            if mask & addr == 0 || mask & addr == mask {
                return true
            } else {
                return false
            }
        }

        func checkVMExecutionControlFields() throws {

            // VM entries perform the following checks on the VM-execution control fields:1
            let pinBased = BitArray32(try self.pinBasedVMExecControls())

            let vmxPinBasedControls = VMXPinBasedControls()
            let vmxPrimaryProcessorBasedControls = VMXPrimaryProcessorBasedControls()
#if false
            if !vmxBasicInfo.vmxControlsCanBeCleared {
                vmxPinBasedControls = VMXPinBasedControls()
                vmxPrimaryProcessorBasedControls = VMXPrimaryProcessorBasedControls()
            } else {
                vmxPinBasedControls = VMXTruePinBasedControls()
                vmxPrimaryProcessorBasedControls = VMXTruePrimaryProcessorBasedControls()
            }
#endif

            // • Reserved bits in the pin-based VM-execution controls must be set properly. Software may consult the VMX capability MSRs to determine the proper settings.
            //print("VMKPinBasedControls Allowed 0:", binary(vmxPinBasedControls.low))
            //print("VMKPinBasedControls Allowed 1:", binary(vmxPinBasedControls.high))
            //print("VMCS pinBasedVMExecControls  :", binary(pinBased.rawValue), "\n")
            if !vmxPinBasedControls.checkAllowed0Bits(in: pinBased.rawValue) {
                fatalError("Pin Based execution controls have bits set that should be cleared")
            }
            if !vmxPinBasedControls.checkAllowed1Bits(in: pinBased.rawValue) {
                fatalError("Pin Based execution controls have bits cleared that should be set")
            }

            // • Reserved bits in the primary processor-based VM-execution controls must be set properly. Software may consult the VMX capability MSRs to determine the proper settings.
            //print("VMXPrimaryProcessorBasedControls Allowed 0:", binary(vmxPrimaryProcessorBasedControls.low))
            //print("VMXPrimaryProcessorBasedControls Allowed 1:", binary(vmxPrimaryProcessorBasedControls.high))
            //print("VMCS Primary Controls                     :", binary(primaryControls.rawValue), "\n")
            if !vmxPrimaryProcessorBasedControls.checkAllowed0Bits(in: primaryControls.rawValue) {
                fatalError("Primary Processor Based Controls have bits set that should be cleared")
            }
            if !vmxPrimaryProcessorBasedControls.checkAllowed1Bits(in: primaryControls.rawValue) {
                fatalError("Primary Processor Based Controls have bits cleared that should be set")
            }

            // • If the “activate secondary controls” primary processor-based VM-execution control is 1,
            // reserved bits in the secondary processor-based VM-execution controls must be cleared.
            // Software may consult the VMX capability MSRs to determine which bits are reserved (see Appendix A.3.3).
            // • If the “activate secondary controls” primary processor-based VM-execution control is 0
            // (or if the processor does not support the 1-setting of that control),
            // no checks are performed on the secondary processor-based VM-execution controls.
            // The logical processor operates as if all the secondary processor-based VM-execution controls were 0.

            if VMXPrimaryProcessorBasedControls().activateSecondaryControls.allowedToBeOne {
                let vmxSecondaryProcessorBasedControls = VMXSecondaryProcessorBasedControls()
                //print("VMXSecondaryProcessorBasedControls allowed 0:", binary(vmxSecondaryProcessorBasedControls.low))
                //print("VMXSecondaryProcessorBasedControls allowed 1:", binary(vmxSecondaryProcessorBasedControls.high))
                //print("VMCS Secondary Controls                     :", binary(secondaryControls.rawValue), "\n")
                if !vmxSecondaryProcessorBasedControls.checkAllowed0Bits(in: secondaryControls.rawValue) {
                    fatalError("Secondary Processor Based Controls hasve bits set that should be cleared")
                }
                if !vmxSecondaryProcessorBasedControls.checkAllowed1Bits(in: secondaryControls.rawValue) {
                    fatalError("Secondary Processor Based Controls hasve bits cleared that should be set")
                }
            }


            // • The CR3-target count must not be greater than 4. Future processors may support a different number of CR3- target values.
            // Software should read the VMX capability MSR IA32_VMX_MISC to determine the number of values supported (see Appendix A.6).
            if try self.cr3TargetCount() > 4 {
                fatalError("VMX: CR3-target count must not be greater than 4")
            }
#if false

            // • If the “use I/O bitmaps” VM-execution control is 1, bits 11:0 of each I/O-bitmap address must be 0.
            // Neither address should set any bits beyond the processor’s physical-address width.1,2
            if primaryControls[25] != 0 {
                let addrA = try self.ioBitmapAAddress()
                if (addrA & 0x3ff) != 0 || addrA > maxPhysicalAddress {
                    fatalError("IO Bitmaps enabled but ioBitmapAAddress \(String(addrA, radix: 16)) is invalid")
                }
                let addrB = try self.ioBitmapBAddress()
                if (addrB & 0x3ff) != 0 || addrB > maxPhysicalAddress {
                    fatalError("IO Bitmaps enabled but ioBitmapBAddress \(String(addrB, radix: 16)) is invalid")
                }
            }

            //• If the “use MSR bitmaps” VM-execution control is 1, bits 11:0 of the MSR-bitmap address must be 0.
            // The address should not set any bits beyond the processor’s physical-address width.
            if primaryControls[28] != 0 {
                let addr = try self.msrBitmapAddress()
                if (addr & 0x3ff) != 0 || addr > maxPhysicalAddress {
                    fatalError("MSR Bitmaps enabled but msrBitmapAAddress \(String(addr, radix: 16)) is invalid")
                }
            }

            // • If the “use TPR shadow” VM-execution control is 1, the virtual-APIC address must satisfy the following checks:
            // — Bits 11:0 of the address must be 0.
            // — The address should not set any bits beyond the processor’s physical-address width.
#endif
            let tprShadow = (primaryControls[21] != 0)
#if false
            if tprShadow {
                let vAPICPage = try self.virtualAPICAddress()
                let addr = vAPICPage.rawValue
                if (addr & 0x3ff) != 0 || addr > maxPhysicalAddress {
                    fatalError("TPR Shadow is enabled but vAPIC address \(String(addr, radix: 16)) is invalid")
                }

                // If the “use TPR shadow” VM-execution control is 1 and the “virtual-interrupt delivery” VM-execution control is 0,
                // bits 31:4 of the TPR threshold VM-execution control field must be 0.
                if primaryControls[9] == 0 {
                    let threshold = try self.tprThreshold()
                    if threshold & 0xffff_fff0 != 0 {
                        fatalError("TPR Shadow is enabled, vINT delivery is disabled, TPR threshold \(String(threshold, radix: 16)) is invalid")
                    }

                    // • The following check is performed if the “use TPR shadow” VM-execution control is 1 and the “virtualize APIC accesses”
                    // and “virtual-interrupt delivery” VM-execution controls are both 0: the value of bits 3:0 of the TPR threshold VM-execution
                    // control field should not be greater than the value of bits 7:4 of VTPR (see Section 29.1.1).
                    if primaryControls[0] == 0 {
                        let vtpr = vAPICPage.rawPointer.load(fromByteOffset: 0x80, as: UInt32.self)
                        let val = (vtpr >> 4) & 0xf
                        if (threshold & 0xf) > val {
                            fatalError("TPR threshold VM-execution field value \(String(threshold & 0xf, radix: 16)) > VTPR[7..4] \(String(val, radix: 16))")
                        }
                    }
                }
            }
#endif

            // • If the “NMI exiting” VM-execution control is 0, the “virtual NMIs” VM-execution control must be 0.
            if pinBased[3] == 0 && pinBased[5] != 0 {
                fatalError("NMI exiting = 0 but virtual NMIs = 1")
            }

            // • If the “virtual NMIs” VM-execution control is 0, the “NMI-window exiting” VM-execution control must be 0.
            if pinBased[5] == 0 && primaryControls[22] != 0 {
                fatalError("virtual NMIs = 0 but NMI-window exiting = 1")
            }

            // • If the “virtualize APIC-accesses” VM-execution control is 1, the APIC-access address must satisfy the following checks:
            // — Bits 11:0 of the address must be 0.
            // — The address should not set any bits beyond the processor’s physical-address width.
#if false
            if secondaryControls[0] == 1 {
                let addr = try self.apicAccessAddress().rawValue
                if (addr & 0x3ff) != 0 || addr > maxPhysicalAddress {
                    fatalError("Virtualise APIC access is 1 but APIC access address \(String(addr, radix: 16)) is invalid")
                }
            }
#endif
            // • If the “use TPR shadow” VM-execution control is 0, the following VM-execution controls must also be 0:
            // “virtualize x2APIC mode”, “APIC-register virtualization”, and “virtual-interrupt delivery”.7

            let virtualizeAPICAccesses = (secondaryControls[0] != 0)
            let virtualizeX2APIC = (secondaryControls[4] != 0)
            let apicRegisterVirtualization = (secondaryControls[8] != 0)
            let virtualInterruptDelivery = (secondaryControls[9] != 0)

            let externalInterruptExiting = (pinBased[0] != 0)
            let processPostedInterrupts = (pinBased[7] != 0)


            let acknowledgeInterruptOnExit = (vmExitControls[15] != 0)

            if !tprShadow {
                if virtualizeX2APIC { fatalError("TPR Shadow is 0 but virtualise X2 APIC is 1") }
                if apicRegisterVirtualization { fatalError("TPR Shadow is 0 but APIC Register Virtualisation is 1") }
                if virtualInterruptDelivery { fatalError("TPR Shadow is 0 but Virtual Interrupt Delivery is 1") }
            }

            // • If the “virtualize x2APIC mode” VM-execution control is 1, the “virtualize APIC accesses” VM-execution control must be 0.
            if virtualizeX2APIC {
                if virtualizeAPICAccesses { fatalError("Virtualise X2 APIC is 1 but virtualise APIC Accesses is not 0") }
            }

            //• If the “virtual-interrupt delivery” VM-execution control is 1, the “external-interrupt exiting” VM-execution control must be 1.
            if virtualInterruptDelivery {
                if !externalInterruptExiting { fatalError("Virtual Interrupt Delivery is 1 but External Interrupt Exiting is not 1") }
            }

            // • If the “process posted interrupts” VM-execution control is 1, the following must be true:
            // — The “virtual-interrupt delivery” VM-execution control is 1.
            // — The “acknowledge interrupt on exit” VM-exit control is 1.
            // — The posted-interrupt notification vector has a value in the range 0–255 (bits 15:8 are all 0).
            // — Bits 5:0 of the posted-interrupt descriptor address are all 0.
            // — The posted-interrupt descriptor address does not set any bits beyond the processor's physical-address width.
            if processPostedInterrupts {
                if !virtualInterruptDelivery { fatalError("processPostedInterrupts is 1 but virtual-interrupt delivery is not 1") }
                if !acknowledgeInterruptOnExit { fatalError("processPostedInterrupts is 1 but acknowledge interrupt on exit is not 1") }
                let vector = try self.postedInterruptNotificationVector()
                if vector > 255 {
                    fatalError("processPostedInterrupts is 1 but posted-interrupt notification vector does not have a value in the range 0–255 ")
                }
                let addr = try self.postedInterruptDescAddress().value
#if false
                if (addr & 0x3f) != 0 || addr > maxPhysicalAddress {
                    fatalError("processPostedInterrupts is 1 but postedInterruptDescAddress \(String(addr, radix: 16)) is invalid")
                }
#endif
            }

            // • If the “enable VPID” VM-execution control is 1, the value of the VPID VM-execution control field must not be 0000H.
            let enableVPID = (secondaryControls[5] != 0)
            if enableVPID {
                if try self.vpid() == 0 {
                    fatalError("enable VPID is set but VPID == 0")
                }
            }

            // • If the “enable EPT” VM-execution control is 1, the EPTP VM-execution control field (see Table 24-8 in Section 24.6.11) must satisfy the following checks
            // — The EPT memory type (bits 2:0) must be a value supported by the processor as indicated in the IA32_VMX_EPT_VPID_CAP MSR (see Appendix A.10).
            // — Bits 5:3 (1 less than the EPT page-walk length) must be 3, indicating an EPT page-walk length of 4; see Section 28.2.2.
            // — Bit 6 (enable bit for accessed and dirty flags for EPT) must be 0 if bit 21 of the IA32_VMX_EPT_VPID_CAP MSR (see Appendix A.10) is read as 0,
            // indicating that the processor does not support accessed and dirty flags for EPT.
            //— Reserved bits 11:7 and 63:N (where N is the processor’s physical-address width) must all be 0.

            let enableEPT = (secondaryControls[1] != 0)
#if false
            if enableEPT {
                //print("EPTP enabled:", binary(self.eptp!))
                let eptp = BitArray64(try self.eptp())
                let eptCap = VMX_EPT_VPID_CAP()
                let memtype = eptp[0...2]
                if (memtype == 0 && !eptCap.allowsEPTUncacheableType) || (memtype == 6 && !eptCap.allowsEPTWriteBackType) || (memtype > 0 && memtype < 6) {
                    fatalError("EPT enabled by memory type is not supported")
                }
                if eptp[3...5] != 3 {
                    fatalError("EPT enabled but page walk length (\(String(eptp[3...5])) is not 3")
                }
                if !eptCap.supportsEPTDirtyAccessedFlags {
                    if eptp[6] != 0 { fatalError("EPT does not support Dirty/Accessed Flags but EPTP has bit 6 set") }
                }
                var cpuMaxBits = Int(CPU.capabilities.maxPhyAddrBits)
                while cpuMaxBits <= 63 {
                    if eptp[cpuMaxBits] == 1 { fatalError("EPTP has reserved bits set to 1") }
                    cpuMaxBits += 1
                }
                if (eptp[7...11] != 0) { fatalError("EPTP has reserved bits set to 1") }
            } else {
                print("EPTP not enabled")
            }
#endif
            // • If the “enable PML” VM-execution control is 1, the “enable EPT” VM-execution control must also be 1.5 In addition,
            // the PML address must satisfy the following checks:
            // — Bits 11:0 of the address must be 0.
            // — The address should not set any bits beyond the processor’s physical-address width.
            let enablePML = (secondaryControls[17] != 0)
            if enablePML {
                if !enableEPT  { fatalError("enablePML is 1 but enableEPT is 0") }
                let pmladdr = try self.pmlAddress().rawValue
                if (pmladdr & 0x3ff) != 0 || pmladdr > maxCPUPhysicalAddress {
                    fatalError("enablePML is 1 but PML Address \(pmladdr.description) is invalid")
                }
            }


            // • If either the “unrestricted guest” VM-execution control or the “mode-based execute control for EPT” VM- execution control is 1,
            // the “enable EPT” VM-execution control must also be 1.
            let unrestrictedGuest = (secondaryControls[7] != 0)
            let modeBasedExecuteCtrlForEPT = (secondaryControls[22] != 0)
            if unrestrictedGuest && !enableEPT { fatalError("Unrestricted Guest is enabled but EPT is not") }
            if modeBasedExecuteCtrlForEPT && !enableEPT { fatalError("Mode Based Execute Control for EPT is enabled but EPT is not") }

            // • If the “sub-page write permissions for EPT” VM-execution control is 1, the “enable EPT” VM-execution control must also be 1.
            // In addition, the SPPTP VM-execution control field (see Table 24-10 in Section 24.6.21) must satisfy the following checks:
            // — Bits 11:0 of the address must be 0.
            // — The address should not set any bits beyond the processor’s physical-address width.
            let subPageWritePermsForEPT = (secondaryControls[23] != 0)
            if subPageWritePermsForEPT {
                if !enableEPT { fatalError("Sub Page Write Permissions for EPT are enabled but EPT is not") }
                let addr = try self.subPagePermissionTablePtr().value
                if (addr & 0x3ff) != 0 || addr > maxCPUPhysicalAddress {
                    fatalError("Sub Page Write Permissions for EPT are enabled but SPPTP is invalid")
                }
            }

            // • If the “enable VM functions” processor-based VM-execution control is 1, reserved bits in the VM-function controls must be clear.
            // Software may consult the VMX capability MSRs to determine which bits are reserved (see Appendix A.11). In addition, the following
            // check is performed based on the setting of bits in the VM- function controls (see Section 24.6.14):
            // — If “EPTP switching” VM-function control is 1, the “enable EPT” VM-execution control must also be 1.
            //   In addition, the EPTP-list address must satisfy the following checks:
            //  • Bits 11:0 of the address must be 0.
            //  • The address must not set any bits beyond the processor’s physical-address width.
            //  If the “enable VM functions” processor-based VM-execution control is 0, no checks are performed on the VM-function controls.

            let enableVMFunctions = (secondaryControls[13] != 0)
            if enableVMFunctions {
                let vmfuncs = BitArray64(try self.vmFunctionControls())
                // FIXME Check reserved bits are clear
                if vmfuncs[0] != 0 {
                    if !enableEPT { fatalError("EPTP switching is enabled but EPT is not") }
                }
                let addr = try self.eptpListAddress().value
                if (addr & 0x3ff) != 0 || addr > maxCPUPhysicalAddress {
                    fatalError("EPTP switching is enabled but EPTP List address \(addr.description) is invalid")
                }
            }

            // • If the “VMCS shadowing” VM-execution control is 1, the VMREAD-bitmap and VMWRITE-bitmap addresses must each satisfy the following checks:
            // — Bits 11:0 of the address must be 0.
            // — The address must not set any bits beyond the processor’s physical-address width.
            let enableVMCSShadowing = (secondaryControls[14] != 0)
            if enableVMCSShadowing {
                let addr1 =  try self.vmreadBitmapAddress().value
                if (addr1 & 0x3ff) != 0 || addr1 > maxCPUPhysicalAddress {
                    fatalError("VMCS Shadowing is enabled but VMREAD Bitmap address \(addr1.description) is invalid")
                }
                let addr2 = try self.vmwriteBitmapAddress().value
                if (addr2 & 0x3ff) != 0 || addr2 > maxCPUPhysicalAddress {
                    fatalError("VMCS Shadowing is enabled but VMWRITE Bitmap address \(addr2.description) is invalid")
                }
            }

            // • If the “EPT-violation #VE” VM-execution control is 1, the virtualization-exception information address must satisfy the following checks:
            // — Bits 11:0 of the address must be 0.
            // — The address must not set any bits beyond the processor’s physical-address width.
            let enableEPTViolationExceptions = (secondaryControls[18] != 0)
            if enableEPTViolationExceptions {
                let addr = try self.vExceptionInfoAddress().value
                if (addr & 0x3ff) != 0 || addr > maxCPUPhysicalAddress {
                    fatalError("EPT Violation VirtualisationExceptions are enabled but Exception Info Address \(addr.description) is invalid")
                }
            }

            // • If the logical processor is operating with Intel PT enabled (if IA32_RTIT_CTL.TraceEn = 1) at the time of VM entry,
            // the “load IA32_RTIT_CTL” VM-entry control must be 0.
            // FIXME - TODO

            // • If the “Intel PT uses guest physical addresses” VM-execution control is 1, the following controls must also be 1:
            // the “enable EPT” VM-execution control; the “load IA32_RTIT_CTL” VM-entry control; and the “clear IA32_RTIT_CTL” VM-exit control.4
            // FIXME - TODO
        }

        func checkVMExitControlFields() throws {
            let pinBased = BitArray32(try self.pinBasedVMExecControls())

            // • Reserved bits in the VM-exit controls must be set properly. Software may consult the VMX capability MSRs to determine the proper settings (see Appendix A.4).
            let vmxExitControls = VMXExitControls()
#if false
            if !vmxBasicInfo.vmxControlsCanBeCleared {
                vmxExitControls = VMXExitControls()
            } else {
                vmxExitControls = VMXTrueExitControls()
            }
#endif
            //print("VMXExitControls Allowed 0:", binary(vmxExitControls.low))
            //print("VMXExitControls Allowed 1:", binary(vmxExitControls.high))
            //print("VMCS Exit Control:        ", binary(vmExitControls.rawValue), "\n")
            if !vmxExitControls.checkAllowed0Bits(in: vmExitControls.rawValue) {
                fatalError("VM Exit Controls have bits set that should be cleared")
            }
            if !vmxExitControls.checkAllowed1Bits(in: vmExitControls.rawValue) {
                fatalError("VM Exit Controls have bits cleared that should be set")
            }

            // • If the “activate VMX-preemption timer” VM-execution control is 0, the “save VMX-preemption timer value” VM- exit control must also be 0.
            let activateVMXPreemptionTimer = (pinBased[6] != 0)
            let saveVMXPreemptionTimerValue = (vmExitControls[22] != 0)
            if !activateVMXPreemptionTimer && saveVMXPreemptionTimerValue {
                fatalError("Activate VMS Premetion Time is not set vut Save Time Value is set")
            }

            // • The following checks are performed for the VM-exit MSR-store address if the VM-exit MSR-store count field is non-zero:
            // — The lower 4 bits of the VM-exit MSR-store address must be 0. The address should not set any bits beyond the processor’s physical-address width.
            // — The address of the last byte in the VM-exit MSR-store area should not set any bits beyond the processor’s physical-address width.
            // The address of this last byte is VM-exit MSR-store address + (MSR count * 16) – 1. (The arithmetic used for the computation uses more bits than
            // the processor’s physical-address width.)
            // If IA32_VMX_BASIC[48] is read as 1, neither address should set any bits in the range 63:32; see Appendix A.1.

#if false
            if try self.vmExitMSRStoreCount() != 0 {
                let addr = try self.vmExitMSRStoreAddress()
                let lastAddr = addr.value - 1
                if (lastAddr > (maxPhysicalAddress - UInt(try self.vmExitMSRStoreCount() * 16))) || (addr.value & 0xf) != 0 {
                    fatalError("VMExitMSR Store Count > 0 but MSR Store Address \(addr.description) is invalid")
                }
            }

            // • The following checks are performed for the VM-exit MSR-load address if the VM-exit MSR-load count field is non-zero:
            // — The lower 4 bits of the VM-exit MSR-load address must be 0. The address should not set any bits beyond the processor’s physical-address width.
            // — The address of the last byte in the VM-exit MSR-load area should not set any bits beyond the processor’s physical-address width.
            // The address of this last byte is VM-exit MSR-load address + (MSR count * 16) – 1. (The arithmetic used for the computation uses more bits than
            // the processor’s physical-address width.)
            // If IA32_VMX_BASIC[48] is read as 1, neither address should set any bits in the range 63:32; see Appendix A.1.

            if try self.vmExitMSRLoadCount() != 0 {
                let addr = try self.vmExitMSRLoadAddress()
                let lastAddr = addr.value - 1
                if (lastAddr > (maxPhysicalAddress - UInt(try self.vmExitMSRLoadCount() * 16))) || (addr.value & 0xf) != 0 {
                    fatalError("VMExitMSR Load Count > 0 but MSR Load Address \(addr.description) is invalid")
                }
            }
#endif
        }


        func checkVMEntryControlFields() throws {
            let unrestrictedGuest = (secondaryControls[7] != 0)
            let pinBased = BitArray32(try self.pinBasedVMExecControls())

            // • Reserved bits in the VM-entry controls must be set properly. Software may consult the VMX capability MSRs to determine the proper settings (see Appendix A.5).
            let vmxEntryControls = VMXEntryControls()
#if false
            if !vmxBasicInfo.vmxControlsCanBeCleared {
                vmxEntryControls = VMXEntryControls()
            } else {
                vmxEntryControls = VMXTrueEntryControls()
            }
#endif
            //print("VMXEntryControls Allowed 0:", binary(vmxEntryControls.low))
            //print("VMXEntryControls Allowed 1:", binary(vmxEntryControls.high))
            //print("VMCS Entry Control:        ", binary(vmEntryControls.rawValue), "\n")
            if !vmxEntryControls.checkAllowed0Bits(in: vmEntryControls.rawValue) {
                fatalError("VM Entry Controls have bits set that should be cleared")
            }
            if !vmxEntryControls.checkAllowed1Bits(in: vmEntryControls.rawValue) {
                fatalError("VM Entry Controls have bits cleared that should be set")
            }

            // • If the “activate VMX-preemption timer” VM-execution control is 0, the “save VMX-preemption timer value” VM- exit control must also be 0.
            let activateVMXPreemptionTimer = (pinBased[6] != 0)
            let saveVMXPreemptionTimerValue = (vmExitControls[22] != 0)
            if !activateVMXPreemptionTimer && saveVMXPreemptionTimerValue {
                fatalError("Activate VMS Premetion Time is not set vut Save Time Value is set")
            }

            // • Fields relevant to VM-entry event injection must be set properly. These fields are the VM-entry interruption- information field
            // (see Table 24-14 in Section 24.8.3), the VM-entry exception error code, and the VM-entry instruction length. If the valid bit (bit 31)
            // in the VM-entry interruption-information field is 1, the following must hold:
            // — The field’s interruption type (bits 10:8) is not set to a reserved value. Value 1 is reserved on all logical processors; value 7 (other event)
            // is reserved on logical processors that do not support the 1-setting of the “monitor trap flag” VM-execution control.
            // — The field’s vector (bits 7:0) is consistent with the interruption type:
            //  • If the interruption type is non-maskable interrupt (NMI), the vector is 2.
            //  • If the interruption type is hardware exception, the vector is at most 31.
            //  • If the interruption type is other event, the vector is 0 (pending MTF VM exit).
            // — The field's deliver-error-code bit (bit 11) is 1 if and only if (1) either (a) the "unrestricted guest" VM- execution control is 0;
            // or (b) bit 0 (corresponding to CR0.PE) is set in the CR0 field in the guest-state area; (2) the interruption type is hardware exception;
            // and (3) the vector indicates an exception that would normally deliver an error code (8 = #DF; 10 = TS; 11 = #NP; 12 = #SS; 13 = #GP; 14 = #PF; or 17 = #AC).
            // — Reserved bits in the field (30:12) are 0.
            // — If the deliver-error-code bit (bit 11) is 1, bits 31:15 of the VM-entry exception error-code field are 0.
            // — If the interruption type is software interrupt, software exception, or privileged software exception, the VM-entry instruction-length field is in the range 0–15.
            // A VM-entry instruction length of 0 is allowed only if IA32_VMX_MISC[30] is read as 1; see Appendix A.6.

            let vmEntryInterruptInfoField = try self.vmEntryInterruptInfo()

            if vmEntryInterruptInfoField.valid {
                let intType = vmEntryInterruptInfoField.interruptType
                if intType == .reserved
                    || (intType == .otherEvent && !VMXPrimaryProcessorBasedControls().monitorTrapFlag.allowedToBeOne) {
                    fatalError("VMEnry IntInfo Field is valid but IntType \(intType) is invalid")
                }
                let vector = vmEntryInterruptInfoField.vector
                if (intType == .nmi && vector != 2)
                    || (intType == .hardwareException && vector > 31)
                    || (intType == .otherEvent && vector != 0) {
                    fatalError("VMEntry Int Type is \(intType) but the vector is \(vector)")
                }
                if vmEntryInterruptInfoField.deliverErrorCode {
                    let cr0 = try self.guestCR0()
                    if (!unrestrictedGuest || cr0.protectionEnable) && intType == .hardwareException &&
                        (vector == 8 || vector == 10 || vector == 11 || vector == 12 || vector == 13 || vector == 14 || vector == 17) {
                    } else {
                        fatalError("Int Info Deliver error code is set but interrupt type is incorrect")
                    }
                }
                if vmEntryInterruptInfoField.reserved != 0 {
                    fatalError("VM Entry Int Info Field bits 12 to 30 are not zero")
                }
                if try vmEntryInterruptInfoField.deliverErrorCode && (BitArray32(self.vmEntryExceptionErrorCode())[15...31] != 0) {
                    fatalError("Deliver Error Code bits is set but error code 15...31 sre not zero")
                }
#if false
                if intType == .softwareInterrupt || intType == .privilegedSoftwareException || intType == .softwareException {
                    let length = try self.vmEntryInstructionLength()
                    if length > 15 || (length == 0 && !VMXMiscInfo().allowZeroLengthInstructionInjection) {
                        fatalError("VMEntry instruction length \(length) is invalid")
                    }
                }
#endif
            }
            // • The following checks are performed for the VM-entry MSR-load address if the VM-entry MSR-load count field is non-zero:
            // — The lower 4 bits of the VM-entry MSR-load address must be 0. The address should not set any bits beyond the processor’s physical-address width.
            // — The address of the last byte in the VM-entry MSR-load area should not set any bits beyond the processor’s physical-address width.
            // The address of this last byte is VM-entry MSR-load address + (MSR count * 16) – 1. (The arithmetic used for the computation uses more bits than
            // the processor’s physical-address width.)
#if false
            if try self.vmEntryMSRLoadCount() != 0 {
                let addr = try self.vmEntryMSRLoadAddress()
                let lastAddr = addr.value - 1
                if (lastAddr > (maxPhysicalAddress - UInt(try self.vmEntryMSRLoadCount() * 16))) || (addr.value & 0xf) != 0 {
                    fatalError("VMEntryMSR Load Count > 0 but MSR Load Address \(addr.description) is invalid")
                }
            }
#endif
            // • If the processor is not in SMM, the “entry to SMM” and “deactivate dual-monitor treatment” VM-entry controls must be 0.
            // TODO: Determine if in SMM

            // • The “entry to SMM” and “deactivate dual-monitor treatment” VM-entry controls cannot both be 1.
            if (vmEntryControls[10] == 1) && (vmEntryControls[11] == 1) {
                fatalError("The entry to SMM and deactivate dual-monitor treatment VM-entry controls cannot both be 1.")
            }
        }

        func checkHostControlRegistersAndMSR() throws {
#if false
            // • The CR0 field must not set any bit to a value not supported in VMX operation (see Section 23.8).
            let cr0 = try self.hostCR0().value

            //print("Fixed0 Bits:", binary(vmxFixedBits.cr0Fixed0Bits))
            //print("Fixed1 Bits:", binary(vmxFixedBits.cr0Fixed1Bits))
            //print("Host CR0:   ", binary(cr0), "\n")

            if (cr0 & ~vmxFixedBits.cr0Fixed1Bits) != 0 {
                fatalError("Host Cr0 has Fixed1 Bits cleared")
            }
            if (cr0 & vmxFixedBits.cr0Fixed0Bits != vmxFixedBits.cr0Fixed0Bits) {
                fatalError("Host CR0 has Fixed0 bits set")
            }

            // • The CR4 field must not set any bit to a value not supported in VMX operation (see Section 23.8).
            let cr4 = try self.hostCR4().value

            //print("Fixed0 Bits:", binary(vmxFixedBits.cr4Fixed0Bits))
            //print("Fixed1 Bits:", binary(vmxFixedBits.cr4Fixed1Bits))
            //print("Host CR4:   ", binary(cr4), "\n")
            if (cr4 & ~vmxFixedBits.cr4Fixed1Bits) != 0 {
                fatalError("Host CR4 has Fixed1 bits cleared")
            }
            if (cr4 & vmxFixedBits.cr4Fixed0Bits != vmxFixedBits.cr4Fixed0Bits) {
                fatalError("Hosr CR4 has Fixed0 bits set")
            }

            // • On processors that support Intel 64 architecture, the CR3 field must be such that bits 63:52 and
            // bits in the range 51:32 beyond the processor’s physical-address width must be 0.
            let cr3val = try self.hostCR3().pageDirectoryBase.value
            if  cr3val > maxCPUPhysicalAddress {
                fatalError("Host CR3 Register \(String(cr3val, radix: 16)) exceeds max address")
            }
            if BitArray64(cr3val)[63] != 0 {
                fatalError("CR3 Bit 63 is not clear")
            }

            // • On processors that support Intel 64 architecture, the IA32_SYSENTER_ESP field and
            //   the IA32_SYSENTER_EIP field must each contain a canonical address.
            if !checkCanonicalAddress(UInt64(try self.hostIA32SysenterESP())) { fatalError("IA32_SYSEnTER_ESP is not canonical") }
            if !checkCanonicalAddress(UInt64(try self.hostIA32SysenterEIP())) { fatalError("IA32_SYSEnTER_EIP is not canonical") }

            // • If the “load IA32_PERF_GLOBAL_CTRL” VM-exit control is 1, bits reserved in the IA32_PERF_GLOBAL_CTRL MSR must be 0 in the field for that register (see Figure 18-3).
            if vmExitControls[12] != 0 {
                // TODO: Need to determine which MSR is referenced - guest or host?
                fatalError("IA32_PERF_GLOBAL_CTRL is set - Implement  IA32_PERF_GLOBAL_CTRL MSR check ")
            }

            // • If the “load IA32_PAT” VM-exit control is 1, the value of the field for the IA32_PAT MSR must be one that could be written by WRMSR without fault at CPL 0.
            // Specifically, each of the 8 bytes in the field must have one of the values 0 (UC), 1 (WC), 4 (WT), 5 (WP), 6 (WB), or 7 (UC-).
            if vmExitControls[18] != 0 {
                fatalError("load IS32_PAT is set - Implemnt IA32_PAT MSR checks")
            }
            // • If the “load IA32_EFER” VM-exit control is 1, bits reserved in the IA32_EFER MSR must be 0 in the field for that register.
            // In addition, the values of the LMA and LME bits in the field must each be that of the “host address- space size” VM-exit control.
            if vmExitControls[21] != 0 {
                fatalError("load IA32_EFR is set - Implement IA32_EFER MSR checks")
            }
#endif
        }


        func checkHostSegmentAndDescriptorTableRegisters() throws {

            // The following checks are performed on fields in the host-state area that correspond to segment and descriptor- table registers:
            // • In the selector field for each of CS, SS, DS, ES, FS, GS and TR, the RPL (bits 1:0) and the TI flag (bit 2) must be 0.
#if false
            if try self.hostCSSelector() & 0x3 != 0 { fatalError("Host CS Selector has RPL != 0 or TI flag is set") }
            if try self.hostSSSelector() & 0x3 != 0 { fatalError("Host SS Selector has RPL != 0 or TI flag is set") }
            if try self.hostDSSelector() & 0x3 != 0 { fatalError("Host DS Selector has RPL != 0 or TI flag is set") }
            if try self.hostESSelector() & 0x3 != 0 { fatalError("Host ES Selector has RPL != 0 or TI flag is set") }
            if try self.hostFSSelector() & 0x3 != 0 { fatalError("Host FS Selector has RPL != 0 or TI flag is set") }
            if try self.hostGSSelector() & 0x3 != 0 { fatalError("Host GS Selector has RPL != 0 or TI flag is set") }
            if try self.hostTRSelector() & 0x3 != 0 { fatalError("Host TR Selector has RPL != 0 or TI flag is set") }
#endif
            // • The selector fields for CS and TR cannot be 0000H.
            if try self.hostCSSelector() == 0 { fatalError("Host CS Selector cannot be 0x0000") }
            if try self.hostTRSelector() == 0 { fatalError("Host TR Selector cannot be 0x0000") }

            //• The selector field for SS cannot be 0000H if the “host address-space size” VM-exit control is 0.
            if BitArray32(try self.vmExitControls())[9] == 0 {
                if try self.hostSSSelector() == 0x0 { fatalError("Host address-space size VM-exit control is 0 but SS selector is 0x0000") }
            }

            //• On processors that support Intel 64 architecture, the base-address fields for FS, GS, GDTR, IDTR, and TR must contain canonical addresses.
            if !checkCanonicalAddress(UInt64(try self.hostFSBase()))   { fatalError("FS base is not canonical ") }
            if !checkCanonicalAddress(UInt64(try self.hostGSBase()))   { fatalError("GS base is not canonical ") }
            if !checkCanonicalAddress(UInt64(try self.hostGDTRBase())) { fatalError("GDTR base is not canonical ") }
            if !checkCanonicalAddress(UInt64(try self.hostIDTRBase())) { fatalError("IDTR base is not canonical ") }
            if !checkCanonicalAddress(UInt64(try self.hostTRBase()))   { fatalError("TR base is not canonical ") }
        }


        // 26.2.4 Checks Related to Address-Space Size
        func checksRelatedToAddressSpaceSize() throws {
            // On processors that support Intel 64 architecture, the following checks related to address-space size are performed on VMX controls and fields in the host-state area:
            // TODO: Add check for 64bit support

#if false
            let efer = CPU.IA32_EFER()
            // • If the logical processor is outside IA-32e mode (if IA32_EFER.LMA = 0) at the time of VM entry, the following must hold:
            // — The “IA-32e mode guest” VM-entry control is 0.
            // — The “host address-space size” VM-exit control is 0.
            if !efer.ia32eModeActive {
                if vmEntryControls[9] != 0 { fatalError("IA32_EFER.LMA == 0 but VMEntryControls.IA-32e mode guest != 0") }
                if vmExitControls[9] != 0 { fatalError("IA32_EFER.LMA == 0 but VMExitControls.hostAddressSpaceSize != 0") }
            } else {
                // • If the logical processor is in IA-32e mode (if IA32_EFER.LMA = 1) at the time of VM entry, the “host address- space size” VM-exit control must be 1.
                if vmExitControls[9] == 0 { fatalError("IA32_EFER.LMA == 1 but VMExitControls.hostAddressSpaceSize == 0") }
            }
#endif
            // • If the “host address-space size” VM-exit control is 0, the following must hold:
            // — The “IA-32e mode guest” VM-entry control is 0.
            // — Bit 17 of the CR4 field (corresponding to CR4.PCIDE) is 0.
            // — Bits 63:32 in the RIP field is 0.
            if vmExitControls[9] == 0 {
#if false
                if efer.ia32eModeActive == true { fatalError("VMExitControls.hostAddressSpaceSize == 0 but IA32_EFER.LMA == 1") }
#endif
                if try self.hostCR4().pcide == true { fatalError("VMExitControls.hostAddressSpaceSize == 0 but CR4.PCIDE != 0") }
                if (try self.hostRIP() & 0xffff_ffff_0000_0000) != 0 { fatalError("VMExitControls.hostAddressSpaceSize == 0 RIP bits 63:32 are not all 0") }
            } else {
                // • If the “host address-space size” VM-exit control is 1, the following must hold:
                // — Bit 5 of the CR4 field (corresponding to CR4.PAE) is 1.
                // — The RIP field contains a canonical address.
                if try self.hostCR4().pae == false { fatalError("VMExitControls.hostAddressSpaceSize == 1 but CR4.PAE != 1") }
                if !checkCanonicalAddress(UInt64(try self.guestRIP())) { fatalError("VMExitControls.hostAddressSpaceSize == 0 but RIP is not a canonical address") }
            }
            //On processors that do not support Intel 64 architecture, checks are performed to ensure that the “IA-32e mode guest” VM-entry control and the “host address-space size” VM-exit control are both 0.
            //TODO
        }


        // 26.3.1.1 Checks on Guest Control Registers, Debug Registers, and MSRs
        func checkGuestControlDebugRegistersAndMSRs() throws {
#if false
            let unrestrictedGuest = (secondaryControls[7] != 0)

            // • The CR0 field must not set any bit to a value not supported in VMX operation (see Section 23.8). The following are exceptions:
            // — Bit 0 (corresponding to CR0.PE) and bit 31 (PG) are not checked if the “unrestricted guest” VM-execution control is 1.1
            // — Bit 29 (corresponding to CR0.NW) and bit 30 (CD) are never checked because the values of these bits are not changed by VM entry; see Section 26.3.2.1.
            var cr0Fixed0Bits = BitArray64(vmxFixedBits.cr0Fixed0Bits)
            var cr0Fixed1Bits = BitArray64(vmxFixedBits.cr0Fixed1Bits)
            if unrestrictedGuest {
                cr0Fixed0Bits[0] = 0
                cr0Fixed0Bits[31] = 0
                cr0Fixed1Bits[0] = 1
                cr0Fixed1Bits[31] = 1
            }
            cr0Fixed0Bits[29] = 0
            cr0Fixed0Bits[30] = 0
            cr0Fixed1Bits[29] = 1
            cr0Fixed1Bits[30] = 1
            let cr0 = try self.guestCR0()
            //print("Fixed0 Bits:", binary(cr0Fixed0Bits.rawValue))
            //print("Fixed1 Bits:", binary(cr0Fixed1Bits.rawValue))
            //print("Guest CR0  :", binary(cr0.value), "\n")

            if (cr0.value & ~cr0Fixed1Bits.toUInt64()) != 0 {
                fatalError("Guest Cr0 has Fixed1 Bits cleared")
            }
            if (cr0.value & cr0Fixed0Bits.toUInt64() != cr0Fixed0Bits.toUInt64()) {
                fatalError("Guest CR0 has Fixed0 bits set")
            }

            // • If bit 31 in the CR0 field (corresponding to PG) is 1, bit 0 in that field (PE) must also be 1.1
            if cr0.paging && !cr0.protectionEnable {
                fatalError("Guest CR0 has Paging enabled but Protection Enable is clear")
            }

            // • The CR4 field must not set any bit to a value not supported in VMX operation (see Section 23.8).
            let cr4 = try self.guestCR4()

            //print("Fixed0 Bits:", binary(vmxFixedBits.cr4Fixed0Bits))
            //print("Fixed1 Bits:", binary(vmxFixedBits.cr4Fixed1Bits))
            //print("Guest CR4  :", binary(cr4.value), "\n")
            if (cr4.value & ~vmxFixedBits.cr4Fixed1Bits) != 0 {
                fatalError("Guest CR4 has Fixed1 bits cleared")
            }
            if (cr4.value & vmxFixedBits.cr4Fixed0Bits != vmxFixedBits.cr4Fixed0Bits) {
                fatalError("Guest CR4 has Fixed0 bits set")
            }
#endif
            // • If the “load debug controls” VM-entry control is 1, bits reserved in the IA32_DEBUGCTL MSR must be 0 in the field for that register.
            // The first processors to support the virtual-machine extensions supported only the 1- setting of this control and thus performed this check unconditionally.
#if false
            if vmEntryControls[2] != 0 {
                // TODO
                if try self.guestIA32DebugCtl() & 0xFFFF203C != 0 {
                    fatalError("load debug controls” VM-entry control is 1, but bits reserved in the IA32_DEBUGCTL MSR must be 0")
                }
            }
#endif
            // • The following checks are performed on processors that support Intel 64 architecture:
            // — If the “IA-32e mode guest” VM-entry control is 1, bit 31 in the CR0 field (corresponding to CR0.PG) and
            // bit 5 in the CR4 field (corresponding to CR4.PAE) must each be 1.
#if false
            if vmEntryControls[9] != 0 {
                if !cr0.paging { fatalError("IA-32e mode guest is set in VM-Entry controls but CR0.PE is clear") }
                if !cr4.pae { fatalError("IA-32emode guet is set in VM-Entry controls but CR4.PAE is clear") }
            }
            // — If the “IA-32e mode guest” VM-entry control is 0, bit 17 in the CR4 field (corresponding to CR4.PCIDE) must be 0.
            if vmEntryControls[9] == 0 && cr4.pcide { fatalError("IA-32emode guet is clear in VM-Entry controls but CR4.PCIDE is set") }
#endif
            // — The CR3 field must be such that bits 63:52 and bits in the range 51:32 beyond the processor’s physical- address width are 0.3,4
            let cr3 = try self.guestCR3()
            let cr3val = cr3.pageDirectoryBase.value
            if  cr3val > maxCPUPhysicalAddress {
                fatalError("Guest CR3 Register \(String(cr3val, radix: 16)) exceeds max address")
            }
            if cr3.bits[52...63] != 0 {
                fatalError("CR3 Bit 63 is not clear")
            }

            // — If the “load debug controls” VM-entry control is 1, bits 63:32 in the DR7 field must be 0. The first processors to support the virtual-machine
            // extensions supported only the 1-setting of this control and thus performed this check unconditionally (if they supported Intel 64 architecture).
            if vmEntryControls[2] != 0 {
                let dr7 = BitArray64(try self.guestDR7())
                if dr7[32...63] != 0 {
                    fatalError("Load debug controls is set in VM Entry controls but DR7 has bits set in 63:32")
                }
            }

            // — The IA32_SYSENTER_ESP field and the IA32_SYSENTER_EIP field must each contain a canonical address.
            let guestIA32SysenterESP = try self.guestIA32SysenterESP()
            if !checkCanonicalAddress(UInt64(guestIA32SysenterESP)) {
                fatalError("IA32_SYSENTER_ESP 0x\(String(guestIA32SysenterESP, radix: 16)) is not a canonical address")
            }

            let guestIA32SysenterEIP = try self.guestIA32SysenterEIP()
            if !checkCanonicalAddress(UInt64(guestIA32SysenterEIP)) {
                fatalError("IA32_SYSENTER_EIP 0x\(String(guestIA32SysenterEIP, radix: 16)) is not a canonical address")
            }

            // • If the “load IA32_PERF_GLOBAL_CTRL” VM-entry control is 1, bits reserved in the IA32_PERF_GLOBAL_CTRL MSR must be 0 in the field for that register (see Figure 18-3).
            if vmEntryControls[13] != 0 {
                // TODO
                fatalError("Load IA32_PERF_GLOBAL_CTRL is set in VM Entry controls but, add checks for IA32_PERF_GLOBAL_CTRL MSR")
            }

            // • If the “load IA32_PAT” VM-entry control is 1, the value of the field for the IA32_PAT MSR must be one that could be written by WRMSR without fault at CPL 0.
            // Specifically, each of the 8 bytes in the field must have one of the values 0 (UC), 1 (WC), 4 (WT), 5 (WP), 6 (WB), or 7 (UC-).
            if vmEntryControls[14] != 0 {
                // TODO
                fatalError("Load IA32_PAT is set in VM Entry controls, add checks for IA32_PAT MSR")
            }


            // • If the “load IA32_EFER” VM-entry control is 1, the following checks are performed on the field for the IA32_EFER MSR:
            // — Bits reserved in the IA32_EFER MSR must be 0.
            // — Bit 10 (corresponding to IA32_EFER.LMA) must equal the value of the “IA-32e mode guest” VM-entry control.
            // It must also be identical to bit 8 (LME) if bit 31 in the CR0 field (corresponding to CR0.PG) is 1.5
#if false
            if vmEntryControls[15] != 0 {
                // TODO
                fatalError("Load IA32_EFER is set in the VM Entry controls, add checks for the IA32_EFER MSR")
            }

            // • If the “load IA32_BNDCFGS” VM-entry control is 1, the following checks are performed on the field for the IA32_BNDCFGS MSR:
            // — Bits reserved in the IA32_BNDCFGS MSR must be 0.
            // — The linear address in bits 63:12 must be canonical.
            if vmEntryControls[16] != 0 {
                // TODO
                fatalError("Load IA32_BNDCFGS is set in the VM Entry controls, add checks for the IA32_BNDCFGS MSR")
            }

            // • If the “load IA32_RTIT_CTL” VM-entry control is 1, bits reserved in the IA32_RTIT_CTL MSR must be 0 in the field for that register (see Table 35-6).
            if vmEntryControls[18] != 0 {
                // TODO
                fatalError("Load IA32_RTIT_CTL is set in the VM Entry controls, add checks for the IA32_RTIT_CTL MSR")
            }
#endif
        }

        // 26.3.1.2 Checks on Guest Segment Registers
        func checkGuestSegmentRegisters() throws {
            //This section specifies the checks on the fields for CS, SS, DS, ES, FS, GS, TR, and LDTR. The following terms are used in defining these checks:
            // • The guest will be virtual-8086 if the VM flag (bit 17) is 1 in the RFLAGS field in the guest-state area.
            // • The guest will be IA-32e mode if the “IA-32e mode guest” VM-entry control is 1. (This is possible only on processors that support Intel 64 architecture.)
            // • Any one of these registers is said to be usable if the unusable bit (bit 16) is 0 in the access-rights field for that register.

            let rflags = BitArray64(try self.guestRFlags().rawValue)
            let vm86mode = rflags[17] == 1
            let unrestrictedGuest = (secondaryControls[7] != 0)
            let ia32eModeGuest = vmEntryControls[9] != 0

            let csSelector = SegmentSelector(try self.guestCSSelector())
            let dsSelector = SegmentSelector(try self.guestDSSelector())
            let esSelector = SegmentSelector(try self.guestESSelector())
            let fsSelector = SegmentSelector(try self.guestFSSelector())
            let gsSelector = SegmentSelector(try self.guestGSSelector())
            let ssSelector = SegmentSelector(try self.guestSSSelector())

            let csAccessRights = AccessRights(try self.guestCSAccessRights())
            let dsAccessRights = AccessRights(try self.guestDSAccessRights())
            let esAccessRights = AccessRights(try self.guestESAccessRights())
            let fsAccessRights = AccessRights(try self.guestFSAccessRights())
            let gsAccessRights = AccessRights(try self.guestGSAccessRights())
            let ssAccessRights = AccessRights(try self.guestSSAccessRights())
            let trAccessRights = AccessRights(try self.guestTRAccessRights())
            let ldtrAccessRights = AccessRights(try self.guestLDTRAccessRights())

            // The following are the checks on these fields:
            // • Selector fields.
            // — TR. The TI flag (bit 2) must be 0.
            // — LDTR. If LDTR is usable, the TI flag (bit 2) must be 0.
            // — SS. If the guest will not be virtual-8086 and the “unrestricted guest” VM-execution control is 0, the RPL (bits 1:0) must equal the RPL of the selector field for CS
            let tr = SegmentSelector(try self.guestTRSelector())
            if tr.ti != 0 { fatalError("TR.TI must be 0") }

            if try ldtrAccessRights.usable && SegmentSelector(self.guestLDTRSelector()).ti != 0 {
                fatalError("LDTR is usable but TI flag != 0")
            }

            if !vm86mode {
                if !unrestrictedGuest && ssSelector.rpl != csSelector.rpl {
                    fatalError("!VM86, !unrestricted guest SS.rpl != CS.rpl")
                }
            }


            // • Base-address fields.
            // — CS, SS, DS, ES, FS, GS. If the guest will be virtual-8086, the address must be the selector field shifted left
            //   4 bits (multiplied by 16).
            if vm86mode {
                if try csSelector.realModeBaseAddress != self.guestCSBase() { fatalError("VM86 CS << 4 != CSBaseAddress") }
                if try ssSelector.realModeBaseAddress != self.guestSSBase() { fatalError("VM86 SS << 4 != SSBaseAddress") }
                if try dsSelector.realModeBaseAddress != self.guestDSBase() { fatalError("VM86 DS << 4 != DBaseAddress") }
                if try esSelector.realModeBaseAddress != self.guestESBase() { fatalError("VM86 ES << 4 != ESBaseAddress") }
                if try fsSelector.realModeBaseAddress != self.guestFSBase() { fatalError("VM86 FS << 4 != FSBaseAddress") }
                if try gsSelector.realModeBaseAddress != self.guestGSBase() { fatalError("VM86 GS << 4 != GSBaseAddress") }
            }

            // — The following checks are performed on processors that support Intel 64 architecture:
            if supports64Bit {
                // • TR, FS, GS. The address must be canonical.
                if !checkCanonicalAddress(UInt64(try self.guestTRBase())) { fatalError("TR Base Address is not canonical") }
                if !checkCanonicalAddress(UInt64(try self.guestFSBase())) { fatalError("FS Base Address is not canonical") }
                if !checkCanonicalAddress(UInt64(try self.guestGSBase())) { fatalError("GS Base Address is not canonical") }

                // • LDTR. If LDTR is usable, the address must be canonical.
                if try ldtrAccessRights.usable && !checkCanonicalAddress(UInt64(self.guestLDTRBase())) {
                    fatalError("LDTR is usable but has non canonical base address")
                }

                // • CS. Bits 63:32 of the address must be zero.
                if (try self.guestCSBase() & 0xffff_ffff_0000_0000) != 0 { fatalError("CS bits 63:32 are not zero") }

                // • SS, DS, ES. If the register is usable, bits 63:32 of the address must be zero.
                if try ssAccessRights.usable && (self.guestSSBase() & 0xffff_ffff_0000_0000 != 0) { fatalError("SS is usable but bits 63:32 are not zero") }
                if try dsAccessRights.usable && (self.guestDSBase() & 0xffff_ffff_0000_0000 != 0) { fatalError("DS is usable but bits 63:32 are not zero") }
                if try esAccessRights.usable && (self.guestESBase() & 0xffff_ffff_0000_0000 != 0) { fatalError("ES is usable but bits 63:32 are not zero") }
            }

            // • Limit fields for CS, SS, DS, ES, FS, GS. If the guest will be virtual-8086, the field must be 0000FFFFH.
            if vm86mode {
                if try self.guestCSLimit() != 0xffff { fatalError("VM86: CS Limit is not 0xffff") }
                if try self.guestSSLimit() != 0xffff { fatalError("VM86: SS Limit is not 0xffff") }
                if try self.guestDSLimit() != 0xffff { fatalError("VM86: DS Limit is not 0xffff") }
                if try self.guestESLimit() != 0xffff { fatalError("VM86: ES Limit is not 0xffff") }
                if try self.guestFSLimit() != 0xffff { fatalError("VM86: FS Limit is not 0xffff") }
                if try self.guestGSLimit() != 0xffff { fatalError("VM86: GS Limit is not 0xffff") }
            }

            // • Access-rights fields.
            // — CS, SS, DS, ES, FS, GS.
            //   • If the guest will be virtual-8086, the field must be 000000F3H. This implies the following:
            //     — Bits 3:0 (Type) must be 3, indicating an expand-up read/write accessed data segment.
            //     — Bit4(S) must be 1.
            //     — Bits 6:5 (DPL) must be 3.
            //     — Bit7(P) must be 1.
            //     — Bits 11:8 (reserved), bit 12 (software available), bit 13 (reserved/L), bit 14 (D/B), bit 15 (G), bit 16 (unusable), and bits 31:17 (reserved) must all be 0.
            if vm86mode {
                if csAccessRights.rawValue != 0x0000_00F3 { fatalError("VM86: CS Access Rights != 0xF3") }
                if ssAccessRights.rawValue != 0x0000_00F3 { fatalError("VM86: SS Access Rights != 0xF3") }
                if dsAccessRights.rawValue != 0x0000_00F3 { fatalError("VM86: DS Access Rights != 0xF3") }
                if esAccessRights.rawValue != 0x0000_00F3 { fatalError("VM86: ES Access Rights != 0xF3") }
                if fsAccessRights.rawValue != 0x0000_00F3 { fatalError("VM86: FS Access Rights != 0xF3") }
                if gsAccessRights.rawValue != 0x0000_00F3 { fatalError("VM86: GS Access Rights != 0xF3") }
            } else {
                // • If the guest will not be virtual-8086, the different sub-fields are considered separately:
                //   — Bits 3:0 (Type).
                //     • CS. The values allowed depend on the setting of the “unrestricted guest” VM-execution control:
                //       — If the control is 0, the Type must be 9, 11, 13, or 15 (accessed code segment).
                //       — If the control is 1, the Type must be either 3 (read/write accessed expand-up data segment) or one of 9, 11, 13, and 15 (accessed code segment).
                var validTypes = [9 , 11, 13, 15]
                if unrestrictedGuest { validTypes.append(3) }
                if !validTypes.contains(csAccessRights.segmentType) {
                    fatalError("CS selector type is not valid")
                }


                //     • SS. If SS is usable, the Type must be 3 or 7 (read/write, accessed data segment).
                if ssAccessRights.usable && (ssAccessRights.segmentType != 3 && ssAccessRights.segmentType != 7) {
                    fatalError("SS is Usable but type is not 3 or 7")
                }
                //     • DS, ES, FS, GS. The following checks apply if the register is usable:
                //       — Bit 0 of the Type must be 1 (accessed).
                //       — If bit 3 of the Type is 1 (code segment), then bit 1 of the Type must be 1 (readable).
                if dsAccessRights.usable && (!dsAccessRights.accessed || (dsAccessRights.codeSegment && !dsAccessRights.readable)) {
                    fatalError("DS is usable but not accessed or Code segment not readable")
                }
                if esAccessRights.usable && (!esAccessRights.accessed || (esAccessRights.codeSegment && !esAccessRights.readable)) {
                    fatalError("ES is usable but not accessed or Code segment not readable")
                }
                if fsAccessRights.usable && (!fsAccessRights.accessed || (fsAccessRights.codeSegment && !fsAccessRights.readable)) {
                    fatalError("FS is usable but not accessed or Code segment not readable")
                }
                if gsAccessRights.usable && (!gsAccessRights.accessed || (gsAccessRights.codeSegment && !gsAccessRights.readable)) {
                    fatalError("GS is usable but not accessed or Code segment not readable")
                }


                //       — Bit 4 (S). If the register is CS or if the register is usable, S must be 1.
                if !csAccessRights.codeOrDataDescriptor { fatalError("CS is not a code or data Descriptor") }
                if dsAccessRights.usable && !dsAccessRights.codeOrDataDescriptor { fatalError("DS is usable but not a code or data descriptor") }
                if esAccessRights.usable && !esAccessRights.codeOrDataDescriptor { fatalError("ES is usable but not a code or data descriptor") }
                if fsAccessRights.usable && !fsAccessRights.codeOrDataDescriptor { fatalError("FS is usable but not a code or data descriptor") }
                if gsAccessRights.usable && !gsAccessRights.codeOrDataDescriptor { fatalError("GS is usable but not a code or data descriptor") }
                if ssAccessRights.usable && !ssAccessRights.codeOrDataDescriptor { fatalError("SS is usable but not a code or data descriptor") }

                //       — Bits 6:5 (DPL).
                //          • CS.
                //            — If the Type is 3 (read/write accessed expand-up data segment), the DPL must be 0. The
                //              Type can be 3 only if the “unrestricted guest” VM-execution control is 1.
                //            — If the Type is 9 or 11 (non-conforming code segment), the DPL must equal the DPL in the access-rights field for SS.
                //            — If the Type is 13 or 15 (conforming code segment), the DPL cannot be greater than the DPL in the access-rights field for SS.

                if csAccessRights.segmentType == 3 {
                    if csAccessRights.privilegeLevel != 0 { fatalError("CS is type 3 but DPL != 0") }
                    if !unrestrictedGuest { fatalError("CS is type 3 but !unrestrictedGuest") }
                }
                if [9, 11].contains(csAccessRights.segmentType) && csAccessRights.privilegeLevel != ssAccessRights.privilegeLevel {
                    fatalError("CS type is 9 or 11 and CS.DPL != SS.DPL")
                }
                if [13, 15].contains(csAccessRights.segmentType) && csAccessRights.privilegeLevel > ssAccessRights.privilegeLevel {
                    fatalError("CS type is 13 or 15 and CS.DPL > SS.DPL")
                }

                //          • SS.
                //            — If the “unrestricted guest” VM-execution control is 0, the DPL must equal the RPL from the selector field.
                //            — The DPL must be 0 either if the Type in the access-rights field for CS is 3 (read/write accessed expand-up data segment) or if bit 0 in the CR0 field (corresponding to CR0.PE) is 0.
                if !unrestrictedGuest && (ssAccessRights.privilegeLevel != ssSelector.rpl) { fatalError("SS: !unrestrictedGuest and DPL != RPL") }
                if try csAccessRights.segmentType == 3 || !(self.guestCR0().protectionEnable) {
                    if ssAccessRights.privilegeLevel != 0 { fatalError("CS type == 3 or CR0.PE == 0 but SS.DPL != 0") }
                }

                //          • DS, ES, FS, GS.
                //            - The DPL cannot be less than the RPL in the selector field if
                //              (1) the “unrestricted guest” VM-execution control is 0;
                //              (2) the register is usable; and
                //              (3) the Type in the access-rights field is in the range 0 – 11 (data segment or non-conforming code segment).
                if !unrestrictedGuest {
                    if dsAccessRights.usable && dsAccessRights.segmentType <= 11 && dsAccessRights.privilegeLevel < dsSelector.rpl { fatalError("DS: usable, type <= 11 but DPL < RPL") }
                    if esAccessRights.usable && esAccessRights.segmentType <= 11 && esAccessRights.privilegeLevel < ssSelector.rpl { fatalError("ES: usable, type <= 11 but DPL < RPL") }
                    if fsAccessRights.usable && fsAccessRights.segmentType <= 11 && fsAccessRights.privilegeLevel < fsSelector.rpl { fatalError("FS: usable, type <= 11 but DPL < RPL") }
                    if gsAccessRights.usable && gsAccessRights.segmentType <= 11 && gsAccessRights.privilegeLevel < gsSelector.rpl { fatalError("GS: usable, type <= 11 but DPL < RPL") }
                }

                //      — Bit 7 (P). If the register is CS or if the register is usable, P must be 1.
                if !csAccessRights.segmentPresent { fatalError("CS: Segment not present") }
                if dsAccessRights.usable && !dsAccessRights.segmentPresent { fatalError("DS: Segment usable but not present") }
                if esAccessRights.usable && !esAccessRights.segmentPresent { fatalError("ES: Segment usable but not present") }
                if fsAccessRights.usable && !fsAccessRights.segmentPresent { fatalError("FS: Segment usable but not present") }
                if gsAccessRights.usable && !gsAccessRights.segmentPresent { fatalError("GS: Segment usable but not present") }
                if ssAccessRights.usable && !ssAccessRights.segmentPresent { fatalError("SS: Segment usable but not present") }

                //      — Bits 11:8 (reserved). If the register is CS or if the register is usable, these bits must all be 0.
                //      — Bits 31:17 (reserved). If the register is CS or if the register is usable, these bits must all be 0.*/
                if csAccessRights.reserved1 != 0 || csAccessRights.reserved2 != 0 { fatalError("CS: Reserved bits are set") }
                if dsAccessRights.usable && (dsAccessRights.reserved1 != 0 || dsAccessRights.reserved2 != 0) { fatalError("DS: Reserved bits are set") }
                if esAccessRights.usable && (esAccessRights.reserved1 != 0 || esAccessRights.reserved2 != 0) { fatalError("ES: Reserved bits are set") }
                if fsAccessRights.usable && (fsAccessRights.reserved1 != 0 || fsAccessRights.reserved2 != 0) { fatalError("FS: Reserved bits are set") }
                if gsAccessRights.usable && (gsAccessRights.reserved1 != 0 || gsAccessRights.reserved2 != 0) { fatalError("GS: Reserved bits are set") }
                if ssAccessRights.usable && (gsAccessRights.reserved1 != 0 || ssAccessRights.reserved2 != 0) { fatalError("SS: Reserved bits are set") }

                //      — Bit 14 (D/B). For CS, D/B must be 0 if the guest will be IA-32e mode and the L bit (bit 13) in the access-rights field is 1.
                if ia32eModeGuest && csAccessRights.longModeActive && csAccessRights.operationSize != 0 {
                    fatalError("CS: IA32E Mode Guest and L bit set but operationSize != 0")
                }
                //      — Bit 15 (G). The following checks apply if the register is CS or if the register is usable:
                //          • If any bit in the limit field in the range 11:0 is 0, G must be 0.
                //          • If any bit in the limit field in the range 31:20 is 1, G must be 1.
                let csLimit = BitArray32(try self.guestCSLimit())
                let dsLimit = BitArray32(try self.guestDSLimit())
                let esLimit = BitArray32(try self.guestESLimit())
                let fsLimit = BitArray32(try self.guestFSLimit())
                let gsLimit = BitArray32(try self.guestGSLimit())
                let ssLimit = BitArray32(try self.guestCSLimit())

                if csLimit[0...11] != 4095 && csAccessRights.granularity { fatalError("CS: lower limit != 4095 and G bit not 0") }
                if csLimit[20...31] != 0 && !csAccessRights.granularity { fatalError("CS: upper limit != 0 and G bit not 1") }

                if dsAccessRights.usable {
                    if dsLimit[0...11] != 4095 && dsAccessRights.granularity { fatalError("DS: lower limit != 4095 and G bit not 0") }
                    if dsLimit[20...31] != 0 && !dsAccessRights.granularity { fatalError("DS: upper limit != 0 and G bit not 1") }
                }
                if esAccessRights.usable {
                    if esLimit[0...11] != 4095 && esAccessRights.granularity { fatalError("ES: lower limit != 4095 and G bit not 0") }
                    if esLimit[20...31] != 0 && !esAccessRights.granularity { fatalError("ES: upper limit != 0 and G bit not 1") }
                }
                if fsAccessRights.usable {
                    if fsLimit[0...11] != 4095 && fsAccessRights.granularity { fatalError("FS: lower limit != 4095 and G bit not 0") }
                    if fsLimit[20...31] != 0 && !fsAccessRights.granularity { fatalError("FS: upper limit != 0 and G bit not 1") }
                }
                if gsAccessRights.usable {
                    if gsLimit[0...11] != 4095 && gsAccessRights.granularity { fatalError("GS: lower limit != 4095 and G bit not 0") }
                    if gsLimit[20...31] != 0 && !gsAccessRights.granularity { fatalError("GS: upper limit != 0 and G bit not 1") }
                }
                if ssAccessRights.usable {
                    if ssLimit[0...11] != 4095 && ssAccessRights.granularity { fatalError("SS: lower limit != 4095 and G bit not 0") }
                    if ssLimit[20...31] != 0 && !ssAccessRights.granularity { fatalError("SS: upper limit != 0 and G bit not 1") }
                }
            }

            //  — TR. The different sub-fields are considered separately:
            //      • Bits 3:0 (Type).
            //         — If the guest will not be IA-32e mode, the Type must be 3 (16-bit busy TSS) or 11 (32-bit busy TSS).
            //         — If the guest will be IA-32e mode, the Type must be 11 (64-bit busy TSS).
            if !ia32eModeGuest {
                if trAccessRights.segmentType != 3 && trAccessRights.segmentType != 11 {
                    fatalError("TR: is32eModeGuest = 0 and segment type not 3 or 11")
                }
            } else {
                if trAccessRights.segmentType != 11 {
                    fatalError("TR: is32eModeGuest = 1 and segment type not 11")
                }
            }

            //      • Bit4(S). S must be 0.
            if !trAccessRights.systemDescriptor { fatalError("TR: S bit must be 0") }

            //      • Bit7 (P). P must be 1.
            if !trAccessRights.segmentPresent { fatalError("TR: Segment not present") }

            //      • Bits 11:8 (reserved). These bits must all be 0.
            //      • Bits 31:17 (reserved). These bits must all be 0.
            if trAccessRights.reserved1 != 0 || trAccessRights.reserved2 != 0 { fatalError("TR: reserved bits are set") }

            //      • Bit 15 (G).
            //        — If any bit in the limit field in the range 11:0 is 0, G must be 0.
            //        — If any bit in the limit field in the range 31:20 is 1, G must be 1.
            let trLimit = BitArray32(try self.guestTRLimit())
            if trLimit[0...11] != 4095 && trAccessRights.granularity { fatalError("TR: lower limit != 4095 and G bit not 0") }
            if trLimit[20...31] != 0 && !trAccessRights.granularity { fatalError("TR: upper limit != 0 and G bit not 1") }

            //      • Bit 16 (Unusable). The unusable bit must be 0.
            if trAccessRights.unusable { fatalError("TR: Segment is set unsable") }

            //  — LDTR. The following checks on the different sub-fields apply only if LDTR is usable:
            if ldtrAccessRights.usable {
                //      • Bits 3:0 (Type). The Type must be 2 (LDT).
                if ldtrAccessRights.segmentType != 2 { fatalError("LDTR: Segment type must be 2") }

                //      • Bit 4 (S). S must be 0.
                if !ldtrAccessRights.systemDescriptor { fatalError("LDTR: S bit must be 0") }
                //      • Bit 7 (P). P must be 1.
                if !ldtrAccessRights.segmentPresent { fatalError("LDTR: Segment not present") }

                //      • Bits 11:8 (reserved). These bits must all be 0.
                //      • Bits 31:17 (reserved). These bits must all be 0.
                if ldtrAccessRights.reserved1 != 0 || ldtrAccessRights.reserved2 != 0 { fatalError("LDTR: reserved bits are set") }

                //      • Bit 15 (G).
                //        — If any bit in the limit field in the range 11:0  is 0, G must be 0.
                //        — If any bit in the limit field in the range 31:20 is 1, G must be 1.
                let ldtrLimit = BitArray32(try self.guestLDTRLimit())
                if ldtrLimit[0...11] != 4095 && ldtrAccessRights.granularity { fatalError("LDTR: lower limit != 4095 and G bit not 0") }
                if ldtrLimit[20...31] != 0 && !ldtrAccessRights.granularity { fatalError("LDTR: upper limit != 0 and G bit not 1") }
            }
        }

        // 26.3.1.3 Checks on Guest Descriptor-Table Registers
        func checkGuestDescriptorRegisters() throws{
            // The following checks are performed on the fields for GDTR and IDTR:
            // • On processors that support Intel 64 architecture, the base-address fields must contain canonical addresses.
            let gdtrBase = UInt64(try self.guestGDTRBase())
            if !checkCanonicalAddress(gdtrBase) { fatalError("Guest GDTR Base address is not canonical 0x\(String(gdtrBase, radix: 16))") }
            let idtrBase = UInt64(try self.guestIDTRBase())
            if !checkCanonicalAddress(idtrBase) { fatalError("Guest IDTR Base address is not canonical 0x\(String(idtrBase, radix: 16))") }

            // • Bits 31:16 of each limit field must be 0.
            if BitArray32(try self.guestGDTRLimit())[16...31] != 0 {
                fatalError("Guest GDTR Limit has bits set in bits 16...31")
            }

            if BitArray32(try self.guestIDTRLimit())[16...31] != 0 {
                fatalError("Guest IDTR Limit has bits set in bits 16...31")
            }
        }

        // 26.3.1.4 Checks on Guest RIP and RFLAGS
        func checkGuestRIPandRFLAGS() throws {
            let rip = try self.guestRIP()
            let rflags = try self.guestRFlags().rawValue
            let ia32eModeGuest = vmEntryControls[9] != 0

            // The following checks are performed on fields in the guest-state area corresponding to RIP and RFLAGS:
            // • RIP. The following checks are performed on processors that support Intel 64 architecture:
            // — Bits 63:32 must be 0 if the “IA-32e mode guest” VM-entry control is 0 or if the L bit (bit 13) in the access- rights field for CS is 0.
            // — If the processor supports N < 64 linear-address bits, bits 63:N must be identical if the “IA-32e mode guest” VM-entry control is 1
            //    and the L bit in the access-rights field for CS is 1.1 (No check applies if the processor supports 64 linear-address bits.)

            let guestCSAccessRights = BitArray32(try self.guestCSAccessRights())
            if !ia32eModeGuest || guestCSAccessRights[13] == 0 {
                if rip & 0xffffffff_00000000 != 0 {
                    fatalError("RIP has bits set in 63:32 but IA32e-Mode is 0 or CS guest access rights L bit is 0")
                }
            }
            if ia32eModeGuest || guestCSAccessRights[13] != 0 {
                if !checkCanonicalAddress(UInt64(rip)) { fatalError("IA32e guest mode is active or L bit is set in CS and RIP is not canonical") }
            }

            // • RFLAGS.
            // — Reserved bits 63:22 (bits 31:22 on processors that do not support Intel 64 architecture), bit 15, bit 5 and
            // bit 3 must be 0 in the field, and reserved bit 1 must be 1.

            if rflags & 0xFFFFFFFF_FFC0802A != 2 {
                fatalError("RFLAGS [0x\(String(rflags, radix: 16))] has incorrects bits set to 0 or 1 ")
            }

            // — The VM flag (bit 17) must be 0 either if the “IA-32e mode guest” VM-entry control is 1 or if bit 0 in the CR0 field (corresponding to CR0.PE) is 0.
            let cr0 = try self.guestCR0()
            if ia32eModeGuest || !cr0.protectionEnable {
                if BitArray64(rflags)[17] != 0 { fatalError("IA32-e mode is 1 or CR0.PE is 0 but RFLAGS VM flag is set") }
            }

            // — The IF flag (RFLAGS[bit 9]) must be 1 if the valid bit (bit 31) in the VM-entry interruption-information field is 1
            // and the interruption type (bits 10:8) is external interrupt.
            let interruptInfo = try self.vmEntryInterruptInfo()
            if interruptInfo.valid && (interruptInfo.interruptType == .external) {
                if BitArray64(rflags)[9] == 0 { fatalError("IntInfoField is external interrupt but RFLAGS IF Flag is Clear") }
            }
        }

        // 26.3.1.5 Checks on Guest Non-Register State
        func checkGuestNonRegisterState() throws {
            let _guestActivityState = try self.guestActivityState()
            let guestInterruptibilityState = try self.guestInterruptibilityState()
            let interruptInfo = try self.vmEntryInterruptInfo()
            let rflags = BitArray64((try self.guestRFlags().rawValue))
#if false
            let vmxMiscInfo = VMXMiscInfo()
#endif

            // The following checks are performed on fields in the guest-state area corresponding to non-register state:
            // • Activity state.
            // — The activity-state field must contain a value in the range 0 – 3, indicating an activity state supported by the implementation (see Section 24.4.2).
            // Future processors may include support for other activity states. Software should read the VMX capability MSR IA32_VMX_MISC (see Appendix A.6) to determine what activity states are supported.
            // — The activity-state field must not indicate the HLT state if the DPL (bits 6:5) in the access-rights field for SS is not 0
            // — The activity-state field must indicate the active state if the interruptibility-state field indicates blocking by either MOV-SS or by STI (if either bit 0 or bit 1 in that field is 1).
            // — If the valid bit (bit 31) in the VM-entry interruption-information field is 1, the interruption to be delivered (as defined by interruption type and vector) must not be one that would normally
            //   be blocked while a logical processor is in the activity state corresponding to the contents of the activity-state field. The following items enumerate the interruptions (as specified in the
            //   VM-entry interruption-information field) whose injection is allowed for the different activity states:
            //      • Active. Any interruption is allowed.
            //      • HLT. The only events allowed are the following:
            //      — Those with interruption type external interrupt or non-maskable interrupt (NMI).
            //      — Those with interruption type hardware exception and vector 1 (debug exception) or vector 18 (machine-check exception).
            //      — Those with interruption type other event and vector 0 (pending MTF VM exit).
            //      See Table 24-14 in Section 24.8.3 for details regarding the format of the VM-entry interruption- information field.
            //      • Shutdown. Only NMIs and machine-check exceptions are allowed.
            //      • Wait-for-SIPI. No interruptions are allowed.
            //  — The activity-state field must not indicate the wait-for-SIPI state if the “entry to SMM” VM-entry control is 1.

            if _guestActivityState != 0 && (guestInterruptibilityState.blockingBySTI || guestInterruptibilityState.blockingByMovSS) {
                fatalError("Interrupibility-state field indicates blocking by either MOV-SS or STI but activity state is not the Active state")
            }

            switch _guestActivityState {
                case 0:     // Active
                    break

            case 1:     // HLT
#if false
                if !vmxMiscInfo.supportsActivityStateHLT { fatalError("GuestActivityState is HLT but CPU does not support it") }
#endif
                if BitArray32(try self.guestSSAccessRights())[5...6] != 0 { fatalError("GuestActivityState is HLT but DPL in SS access-rights field is not 0") }
                    if interruptInfo.valid {
                        switch interruptInfo.interruptType {
                            // OK
                            case .external, .nmi,
                                 .hardwareException where (interruptInfo.vector == 1 || interruptInfo.vector == 18),
                                 .otherEvent where interruptInfo.vector == 0:
                                break

                            default: fatalError("Invalid vmEntryInterruptInfo type: \(interruptInfo.interruptType) vector: \(interruptInfo.vector) for HLT Activity state")
                        }
                    }

            case 2:     // Shutdown
#if false
                if !vmxMiscInfo.supportsActivityStateShutdown { fatalError("GuestActivityState is Shutdown but CPU does not support it") }
#endif
                    if interruptInfo.valid {
                            switch interruptInfo.interruptType {
                                // OK
                                case .nmi,
                                     .hardwareException where interruptInfo.vector == 18: // 18 = Machine Check Exception
                                    break

                                default: fatalError("Invalid vmEntryInterruptInfo type: \(interruptInfo.interruptType) for Shutdown Activity state")
                            }
                        }

            case 3:     // Wait-for-SIPI
#if false
                if !vmxMiscInfo.supportsActivityStateWaitForSIPI { fatalError("GuestActivityState is Wait-For-SIPI but CPU does not support it") }
#endif
                    if interruptInfo.valid { fatalError("VMEntry Interrupt Info is not valid in Wait-for-SIPI activity state") }

            default:

                    fatalError("Invalid guest activity state \(_guestActivityState)")
            }


            // • Interruptibility state.
            // — The reserved bits (bits 31:5) must be 0.
            if guestInterruptibilityState.reserved != 0 { fatalError("Guest Interruptability State: reserved bits must be 0") }
            // — The field cannot indicate blocking by both STI and MOV SS (bits 0 and 1 cannot both be 1).
            if guestInterruptibilityState.blockingByMovSS && guestInterruptibilityState.blockingBySTI {
                fatalError("Guest Interruptability State: both MOV by SS and STI are enabled")
            }

            //— Bit 0 (blocking by STI) must be 0 if the IF flag (bit 9) is 0 in the RFLAGS field.
            if  rflags[9] == 0 && guestInterruptibilityState.blockingBySTI {
                fatalError("RFLAGS.IF == 0 but Guest Interruptability State.BlockingBySTI == 1")
            }

            // — Bit 0 (blocking by STI) and bit 1 (blocking by MOV-SS) must both be 0 if the valid bit (bit 31) in the VM-entry interruption-information field is 1
            // and the interruption type (bits 10:8) in that field has value 0, indicating external interrupt.
            if interruptInfo.valid && interruptInfo.interruptType == .external {
                if guestInterruptibilityState.blockingBySTI || guestInterruptibilityState.blockingByMovSS {
                    fatalError("Guest Interruptability State is valid and has external interrupt type but .BlockingBySTI == 1 OR .BlockingByMovSS == 1")
                }
            }

            // — Bit 1 (blocking by MOV-SS) must be 0 if the valid bit (bit 31) in the VM-entry interruption-information field is 1 and the interruption type (bits 10:8) in that field has value 2, indicating non-maskable interrupt (NMI).
            if interruptInfo.valid && interruptInfo.interruptType == .nmi {
                if guestInterruptibilityState.blockingByMovSS {
                    fatalError("Guest Interruptability State is valid and has NMI interrupt type but .BlockingByMovSS == 1")
                }
            }

            // — Bit 2 (blocking by SMI) must be 0 if the processor is not in SMM.
            if guestInterruptibilityState.blockingBySMI {
                fatalError("Guest Interruptability State.blockingBySMI must be 0 when not in SMM")
            }

            // — Bit 2 (blocking by SMI) must be 1 if the “entry to SMM” VM-entry control is 1.
            if vmEntryControls[10] == 1 && !guestInterruptibilityState.blockingBySMI {
                fatalError("Guest Interruptability State.blockingBySMI must be 1 when VM-entry control 'entry to SMM' is set")
            }

            // — A processor may require bit 0 (blocking by STI) to be 0 if the valid bit (bit 31) in the VM-entry interruption- information field is 1 and the interruption type (bits 10:8) in that field has value 2, indicating NMI.
            //Other processors may not make this requirement.
            //TODO??

            // — Bit 3 (blocking by NMI) must be 0 if the “virtual NMIs” VM-execution control is 1, the valid bit (bit 31) in the VM-entry interruption-information field is 1,
            // and the interruption type (bits 10:8) in that field has value 2 (indicating NMI).
            if (vmExecutionControls[5] == 1) && interruptInfo.valid && interruptInfo.interruptType == .nmi {
                if guestInterruptibilityState.blockingByNMI { fatalError("Guest Interruptability State.blockingByNMI must be 0 when vitual NMIs are enabled and interrupt type is NMI") }
            }


            // — If bit 4 (enclave interruption) is 1, bit 1 (blocking by MOV-SS) must be 0 and the processor must support for SGX by enumerating CPUID.(EAX=07H,ECX=0):EBX.SGX[bit 2] as 1.
            if guestInterruptibilityState.enclaveInterruption {
                if guestInterruptibilityState.blockingByMovSS { fatalError("Guest Interruptibility State.enclave interruption is enabled but MOV-SS is also") }
                if !CPU.capabilities.sgx { fatalError("Guest Interruptibility State.enclave interruption is enabled but processor doesn not support SGX") }
            }

            //NOTE
            // If the “virtual NMIs” VM-execution control is 0, there is no requirement that bit 3 be 0 if the valid bit in the VM-entry interruption-information field is 1 and the interruption type in that field has value 2.

            // • Pending debug exceptions.
            let pendingDebugExceptions = try self.guestPendingDebugExceptions()
            // — Bits 11:4, bit 13, bit 15, and bits 63:17 (bits 31:17 on processors that do not support Intel 64 architecture) must be 0.
            if pendingDebugExceptions.reserved != 0 { fatalError("PendingDebugExceptions has reserved bits set") }
            // — The following checks are performed if any of the following holds:
            // (1) the interruptibility-state field indicates blocking by STI (bit 0 in that field is 1);
            // (2) the interruptibility-state field indicates blocking by MOV SS (bit 1 in that field is 1); or
            // (3) the activity-state field indicates HLT:
            // • Bit14(BS) must be 1 if the TF flag(bit8) in the RFLAGS field is 1 and the BTF flag(bit1) in the IA32_DEBUGCTL field is 0.
            // • Bit14(BS) must be 0 if the TF flag(bit8) in the RFLAGS field is 0 or the BTF flag(bit1) in the IA32_DEBUGCTL field is 1.

            if guestInterruptibilityState.blockingBySTI || guestInterruptibilityState.blockingByMovSS || _guestActivityState == 1 {
                let debugCtl = BitArray64(try self.guestIA32DebugCtl())
                if rflags[8] == 1 && debugCtl[1] == 0 {
                    if !pendingDebugExceptions.bs { fatalError("pendingDebugExceptions.BS must be 1 when RFLAGS.TF == 1 and IA32_DEBUGCTL.BTF == 0") }
                }
                if rflags[8] == 0 || debugCtl[1] == 1 {
                    if pendingDebugExceptions.bs {  fatalError("pendingDebugExceptions.BS must be 0 when RFLAGS.TF == 0 or IA32_DEBUGCTL.BTF == 1") }
                }
            }

            // — The following checks are performed if bit 16 (RTM) is 1:
            //   • Bits 11:0, bits 15:13, and bits 63:17 (bits 31:17 on processors that do not support Intel 64 archi- tecture) must be 0; bit 12 must be 1.
            //   • The processor must support for RTM by enumerating CPUID.(EAX=07H,ECX=0):EBX[bit 11] as 1.
            //   • The interruptibility-state field must not indicate blocking by MOV SS (bit 1 in that field must be 0).

            if pendingDebugExceptions.rtm {
                if pendingDebugExceptions.bits[0...11] != 0 || pendingDebugExceptions.bits[13...15] != 0 || pendingDebugExceptions.bits[17...63] != 0 || pendingDebugExceptions.bits[12] != 1 {
                    fatalError("PendingDebugExceptions.RTM is set and other bits are invalid")
                }
                if !CPU.capabilities.rtm { fatalError("PendingDebugExceptions.RTM is set but CPU does not support RTM") }
                if guestInterruptibilityState.blockingByMovSS { fatalError("PendingDebugExceptions.RTM is set but blockingByMovSS == 1") }
            }

            // • VMCS link pointer. The following checks apply if the field contains a value other than FFFFFFFF_FFFFFFFFH:
            // — Bits 11:0 must be 0.
            // — Bits beyond the processor’s physical-address width must be 0.
            // — The 4 bytes located in memory referenced by the value of the field (as a physical address) must satisfy the following:
            // • Bits 30:0 must contain the processor’s VMCS revision identifier (see Section 24.2).3
            // • Bit 31 must contain the setting of the “VMCS shadowing” VM-execution control.4 This implies that the referenced VMCS is a shadow VMCS (see Section 24.10) if and only if the “VMCS shadowing” VM- execution control is 1.
            // — If the processor is not in SMM or the “entry to SMM” VM-entry control is 1, the field must not contain the current VMCS pointer.
            // — If the processor is in SMM and the “entry to SMM” VM-entry control is 0, the field must differ from the executive-VMCS pointer.
#if false
            let linkPtr = BitArray64(try self.vmcsLinkPointer())
            if linkPtr.rawValue != UInt64(0xffff_ffff_ffff_ffff) {
                if linkPtr[0...11] != 0 { fatalError("Link Pointer has some of bits 0..11 set") }
                fatalError("TODO: Add extra checks")
            }
#endif
        }

        // 26.3.1.6 Checks on Guest Page-Directory-Pointer-Table Entries
        func checkGuestPDPTEntries() {
  //          let cr0 = self.guestCR0!
//            let cr4 = self.guestCR4!
        }


        // VM Entry/Exit checks
        try checkVMExecutionControlFields()
        try checkVMExitControlFields()
        try checkVMEntryControlFields()

        // Host Checks
        try checkHostControlRegistersAndMSR()
        try checkHostSegmentAndDescriptorTableRegisters()
        try checksRelatedToAddressSpaceSize()

        // Guest Checks
        try checkGuestControlDebugRegistersAndMSRs()
        try checkGuestSegmentRegisters()
        try checkGuestDescriptorRegisters()
        try checkGuestRIPandRFLAGS()
        try checkGuestNonRegisterState()
        checkGuestPDPTEntries()
        print("VMCS Fields OK")
    }
}

#endif
