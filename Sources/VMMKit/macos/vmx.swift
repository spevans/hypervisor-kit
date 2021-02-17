//
//  vmx.swift
//  
//
//  Created by Simon Evans on 10/12/2019.
//

#if os(macOS)

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

enum VMXExitReason: UInt16, CustomStringConvertible {
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
    case vmentryFailMCE = 41
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
    case encls = 60
    case rdseed = 61
    case pmlFull = 62
    case xsaves = 63
    case xrstors = 64
    case subPagePermissionEvent = 66
    case umwait = 67
    case tpause = 68

    var description: String {
        switch self {
            case .exceptionOrNMI:
                return "Exception or NMI"
            case .externalINT:
                return "External Interrupt"
            case .tripleFault:
                return "Triple Fault"
            case .initSignal:
                return "INIT Signal arrived"
            case .startupIPI:
                return "Start-up IPI arrived"
            case .ioSMI:
                return "I/O SMI arrived"
            case .otherSMI:
                return "Non-I/O SMI arrived"
            case .intWindow:
                return "Interrupt window"
            case .nmiWindow:
                return "NMI window"
            case .taskSwitch:
                return "Guest attempted Task Switch"
            case .cpuid:
                return "Guest attempted CPUID"
            case .getsec:
                return "Guest attempted GETSEC"
            case .hlt:
                return "Guest attempted HLT"
            case .invd:
                return "Guest attempted INVD"
            case .invlpg:
                return "Guest attempted INVLPG"
            case .rdpmc:
                return "Guest attempted RDPMC"
            case .rdtsc:
                return "Guest attempted RSTSC"
            case .rsm:
                return "Guest attempted RSM"
            case .vmcall:
                return "Guest executed VMCALL"
            case .vmclear:
                return "Guest attempted VMCLEAR"
            case .vmlaunch:
                return "Guest attempted VMLAUNCH"
            case .vmptrld:
                return "Guest attempted VMPTRLD"
            case .vmptrst:
                return "Guest attempted VMPTRST"
            case .vmread:
                return "Guest attempted VMMREAD"
            case .vmresume:
                return "Guest attempted VMRESUME"
            case .vmwrite:
                return "Guest attempted VMWRITE"
            case .vmxoff:
                return "Guest attempted VMXOFF"
            case .vmxon:
                return "Guest attempted VMXON"
            case .crAccess:
                return "Guest attempted CR access"
            case .drAccess:
                return "Guest attempted DR access"
            case .ioInstruction:
                return "Guest attempeted I/O instruction"
            case .rdmsr:
                return "Guest attempted RDMSR"
            case .wrmsr:
                return "Guest attempted WRMSR"
            case .vmentryFailInvalidGuestState:
                return "VMEntry failed due to invalid Guest State"
            case .vmentryFailMSRLoading:
                return "VMEntry failed due to MSR loading"
            case .mwait:
                return "Guest attempted MWAIT"
            case .monitorTrapFlag:
                return "Monitor trap flag"
            case .monitor:
                return "Guest attempted MONITOR"
            case .pause:
                return "Guest attempted PAUSE"
            case .vmentryFailMCE:
                return "VMEntry failed due to MCE"
            case .tprBelowThreshold:
                return "TPR below threshold"
            case .apicAccess:
                return "Guest attempted APIC access"
            case .virtualisedEOI:
                return "Virtualised EOI"
            case .accessToGDTRorIDTR:
                return "Guest attempted access to GDTR or IDTR"
            case .accessToLDTRorTR:
                return "Guest attempted access to LDTR or TR"
            case .eptViolation:
                return "EPT violation"
            case .eptMisconfiguration:
                return "EPT miscconfiguration"
            case .invept:
                return "Guest attempted INVEPT"
            case .rdtscp:
                return "Guest attempted RDTSCP"
            case .vmxPreemptionTimerExpired:
                return "VMX-preemption timer expired"
            case .invvpid:
                return "Guest attempted INVVPID"
            case .wbinvd:
                return "Guest attempted WBINVD"
            case .xsetbv:
                return "Guest attempted XSETBV"
            case .apicWrite:
                return "APIC write"
            case .rdrand:
                return "Guest attempted RDRAND"
            case .invpcid:
                return "Guest attempted INVPCID"
            case .vmfunc:
                return "Guest attempted VMFUNC"
            case .encls:
                return "Guest attempted ENCLS"
            case .rdseed:
                return "Guest attempted RDSEED"
            case .pmlFull:
                return "Page modification log full"
            case .xsaves:
                return "Guest attempted XSAVES"
            case .xrstors:
                return "Guest attempted XRSTORS"
            case .subPagePermissionEvent:
                return "Sub-page permission event"
            case .umwait:
                return "Guest attempted UMWAIT"
            case .tpause:
                return "Guest attempted TPAUSE"
        }
    }
}

#endif
