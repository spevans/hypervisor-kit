//
//  File.swift
//  
//
//  Created by Simon Evans on 01/12/2019.
//


extension Bool {
    init(_ bit: Int) {
        precondition(bit == 0 || bit == 1)
        self = (bit == 1) ? true : false
    }
}

struct VMXExit: Error {
    let value: BitArray32

    var exitReason: VMXExitReason { VMXExitReason(rawValue: UInt16(value[0...15]))! }
    var vmExitInEnclaveMode: Bool { Bool(value[27]) }
    var pendingMTFvmExit: Bool { Bool(value[28]) }
    var vmExitFromVMXrootOperation: Bool { Bool(value[29]) }
    var vmEntryFailure: Bool { Bool(value[31]) }

    init(_ result: UInt32) {
        value = BitArray32(result)
    }
}

enum VMXError: Error, Equatable {

    enum VMFailValidError: UInt32 {
        case vmcallInVMXRootOperation = 1
        case vmclearWithInvalidAddress = 2
        case vmclearWithVxmonPointer = 3
        case vmlaunchWithNonClearVMCS = 4
        case vmresumeWithNonLaunchedVMCS = 5
        case vmresumeWithVMXOFF = 6
        case vmentryWithInvalidControlField = 7
        case vmentryWithInvalidHostStateField = 8
        case vmptrldWithInvalidPhysicalAddress = 9
        case vmptrldWithVxmonPointer = 10
        case vmptrldWithIncorrectVMCSRevisionId = 11
        case readWriteUsingUnsupportedVMCSComponent = 12
        case vmwriteToReadonlyComponent = 13
        case vxmonExecutedInVMXRootOperation = 15
        case vmentryWithInvalidExecutiveVMCSPointer = 16
        case vmentryWithNonLaunchedExecutiveVMCS = 17
        case vmentryWithExecutiveVMCSPointer = 18
        case vmcallWithNonClearVMCS = 19
        case vmcallWithInvalidVMExitControlFields = 20
        case vmcallWithIncorrectMSEGRevisionId = 22
        case vmxoffUnderDualMonitorTreatment = 23
        case vmcallWithInvalidSMMMonitorFeatures = 24
        case vmentryWithInvalidVMExecutionControlFields = 25
        case vmentryWithEventsBlockedByMOVSS = 26
        case InvalidOperandToInveptOrInvvpid = 28
        case unknownError = 0xffff
    }


    case vmSucceed
    case vmFailInvalid
    case vmFailValid(UInt32) //(VMFailValidError)
    case vmEntryFailure(VMXExitReason)

    init(_ error: UInt64) {
        switch(error) {
            case 0x0: self = .vmSucceed
            case 0x1: self = .vmFailInvalid
            default: fatalError("Invalid VMX error state: \(String(error, radix: 16))")
        }
    }
}

enum VMXExitReason: UInt16 {
    case exceptionOrNMI = 0
    case externalINT = 1
    case tripleFault = 2
    case initSignal = 3
    case startupIPI = 4
    case ioSMI = 5
    case otherSMI = 6
    case intWindow = 7
    case nmiWindow = 8
    case taskSwitch = 9
    case cpuid = 10
    case getsec = 11
    case hlt = 12
    case invd = 13
    case invlpg = 14
    case rdpmc = 15
    case rdtsc = 16
    case rsm = 17
    case vmcall = 18
    case vmclear = 19
    case vmlaunch = 20
    case vmptrld = 21
    case vmptrst = 22
    case vmread = 23
    case vmresume = 24
    case vmwrite = 25
    case vmxoff = 26
    case vmxon = 27
    case crAccess = 28
    case drAccess = 29
    case ioInstruction = 30
    case rdmsr = 31
    case wrmsr = 32
    case vmentryFailInvalidGuestState = 33
    case vmentryFailMSRLoading = 34
    case mwait = 36
    case monitorTrapFlag = 37
    case monitor = 39
    case pause = 40
    case vmentryFaileMCE = 41
    case tprBelowThreshold = 43
    case apicAccess = 44
    case virtualisedEOI = 45
    case accessToGDTRorIDTR = 46
    case accessToLDTRorTR = 47
    case eptViolation = 48
    case eptMisconfiguration = 49
    case invept = 50
    case rdtscp = 51
    case vmxPreemptionTimerExpired = 52
    case invvpid = 53
    case wbinvd = 54
    case xsetbv = 55
    case apicWrite = 56
    case rdrand = 57
    case invpcid  = 58
    case vmfunc = 59
    case envls = 60
    case rdseed = 61
    case pmlFull = 62
    case xsaves = 63
    case xrstors = 64
    case subPagePermissionEvent = 66
    case umwait = 67
    case tpause = 68
}

struct CPU {
    struct CR0Register: CustomStringConvertible {
        private(set) var bits: BitArray64
        var value: UInt64 { bits.toUInt64() }

        init(_ value: UInt64) {
            bits = BitArray64(value)
        }

        //    init() {
        //        bits = BitArray64(getCR0())
        //    }

        var protectionEnable: Bool {
            get { Bool(bits[0]) }
            set { bits[0] = newValue ? 1 : 0 }
        }

        var monitorCoprocessor: Bool {
            get { Bool(bits[1]) }
            set { bits[1] = newValue ? 1 : 0 }
        }

        var fpuEmulation: Bool {
            get { Bool(bits[2]) }
            set { bits[2] = newValue ? 1 : 0 }
        }

        var taskSwitched: Bool {
            get { Bool(bits[3]) }
            set { bits[3] = newValue ? 1 : 0 }
        }

        var extensionType: Bool {
            get { Bool(bits[4]) }
            set { bits[4] = newValue ? 1 : 0 }
        }

        var numericError: Bool {
            get { Bool(bits[5]) }
            set { bits[5] = newValue ? 1 : 0 }
        }

        var writeProtect: Bool {
            get { Bool(bits[16]) }
            set { bits[16] = newValue ? 1 : 0 }
        }

        var alignmentMask: Bool {
            get { Bool(bits[18]) }
            set { bits[18] = newValue ? 1 : 0 }
        }

        var notWriteThrough: Bool {
            get { Bool(bits[29]) }
            set { bits[29] = newValue ? 1 : 0 }
        }

        var cacheDisable: Bool {
            get { Bool(bits[30]) }
            set { bits[30] = newValue ? 1 : 0 }
        }

        var paging: Bool {
            get { Bool(bits[31]) }
            set { bits[31] = newValue ? 1 : 0 }
        }

        var description: String {
            var result = "PE: " + (protectionEnable ? "1" : "0")
            result += " MC: " + (monitorCoprocessor ? "1" : "0")
            result += " FE: " + (fpuEmulation ? "1" : "0")
            result += " TS: " + (taskSwitched ? "1" : "0")
            result += " ET: " + (extensionType ? "1" : "0")
            result += " NE: " + (numericError ? "1" : "0")
            result += " WP: " + (writeProtect ? "1" : "0")
            result += " AM: " + (alignmentMask ? "1" : "0")
            result += " WT: " + (notWriteThrough ? "1" : "0")
            result += " CD: " + (cacheDisable ? "1" : "0")
            result += " PG: " + (paging ? "1" : "0")

            return result
        }
    }

    typealias PhysAddress = UInt64

    struct CR3Register {
        private(set) var bits: BitArray64
        var value: UInt64 { bits.toUInt64() }

        init(_ value: UInt64) {
            bits = BitArray64(value)
        }

        //    init() {
        //        bits = BitArray64(getCR3())
        //    }

        var pagelevelWriteThrough: Bool {
            get { Bool(bits[3]) }
            set { bits[3] = newValue ? 1 : 0 }
        }

        var pagelevelCacheDisable: Bool {
            get { Bool(bits[4]) }
            set { bits[4] = newValue ? 1 : 0 }
        }
        /*
         var pageDirectoryBase: PhysAddress {
         get { PhysAddress(UInt(value) & ~PAGE_MASK) }
         set {
         precondition(newValue.isPageAligned)
         bits[12...63] = 0  // clear current address
         bits = BitArray64(UInt64(newValue.value) | value)
         }
         }*/
    }


    struct CR4Register: CustomStringConvertible {
        private(set) var bits: BitArray64
        var value: UInt64 { bits.toUInt64() }

        init(_ value: UInt64) {
            bits = BitArray64(value)
        }

        //   init() {
        //       bits = BitArray64(getCR4())
        //   }

        var vme: Bool {
            get { Bool(bits[0]) }
            set { bits[0] = newValue ? 1 : 0 }
        }

        var pvi: Bool {
            get { Bool(bits[1]) }
            set { bits[1] = newValue ? 1 : 0 }
        }

        var tsd: Bool {
            get { Bool(bits[2]) }
            set { bits[2] = newValue ? 1 : 0 }
        }

        var de: Bool {
            get { Bool(bits[3]) }
            set { bits[3] = newValue ? 1 : 0 }
        }

        var pse: Bool {
            get { Bool(bits[4]) }
            set { bits[4] = newValue ? 1 : 0 }
        }

        var pae: Bool {
            get { Bool(bits[5]) }
            set { bits[5] = newValue ? 1 : 0 }
        }

        var mce: Bool {
            get { Bool(bits[6]) }
            set { bits[6] = newValue ? 1 : 0 }
        }

        var pge: Bool {
            get { Bool(bits[7]) }
            set { bits[7] = newValue ? 1 : 0 }
        }

        var pce: Bool {
            get { Bool(bits[8]) }
            set { bits[8] = newValue ? 1 : 0 }
        }

        var osfxsr: Bool {
            get { Bool(bits[9]) }
            set { bits[9] = newValue ? 1 : 0 }
        }

        var osxmmxcpt: Bool {
            get { Bool(bits[10]) }
            set { bits[10] = newValue ? 1 : 0 }
        }

        var umip: Bool {
            get { Bool(bits[11]) }
            set { bits[11] = newValue ? 1 : 0 }
        }

        var vmxe: Bool {
            get { Bool(bits[13]) }
            set { bits[13] = newValue ? 1 : 0 }
        }

        var smxe: Bool {
            get { Bool(bits[14]) }
            set { bits[14] = newValue ? 1 : 0 }
        }

        var fsgsbase: Bool {
            get { Bool(bits[16]) }
            set { bits[16] = newValue ? 1 : 0 }
        }

        var pcide: Bool {
            get { Bool(bits[17]) }
            set { bits[17] = newValue ? 1 : 0 }
        }

        var osxsave: Bool {
            get { Bool(bits[18]) }
            set { bits[18] = newValue ? 1 : 0 }
        }

        var smep: Bool {
            get { Bool(bits[20]) }
            set { bits[20] = newValue ? 1 : 0 }
        }

        var smap: Bool {
            get { Bool(bits[21]) }
            set { bits[21] = newValue ? 1 : 0 }
        }

        var pke: Bool {
            get { Bool(bits[22]) }
            set { bits[22] = newValue ? 1 : 0 }
        }

        var description: String {
            var result = "VME: " + (vme ? "1" : "0")
            result += " PVI: " + (pvi ? "1" : "0")
            result += " TSD: " + (tsd ? "1" : "0")
            result += " DE: " + (tsd ? "1" : "0")
            result += " PSE: " + (pse ? "1" : "0")
            result += " PAE: " + (pae ? "1" : "0")
            result += " MCE: " + (mce ? "1" : "0")
            result += " PGE: " + (pge ? "1" : "0")
            result += " PCE: " + (pce ? "1" : "0")
            result += " OSFXSR: " + (osfxsr ? "1" : "0")
            result += " OSXMMXCPT: " + (osxmmxcpt ? "1" : "0")
            result += " UMIP: " + (umip ? "1" : "0")
            result += " VMXE: " + (vmxe ? "1" : "0")
            result += " SMXE: " + (smxe ? "1" : "0")
            result += " FSGSBASE: " + (fsgsbase ? "1" : "0")
            result += " PCIDE: " + (pcide ? "1" : "0")
            result += " OSXSAVE: " + (osxsave ? "1" : "0")
            result += " SMEP: " + (smep ? "1" : "0")
            result += " SMAP: " + (smap ? "1" : "0")
            result += " PKE: " + (pke ? "1" : "0")

            return result
        }
    }

}
