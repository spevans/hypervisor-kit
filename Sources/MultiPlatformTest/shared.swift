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
