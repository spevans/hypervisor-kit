//
//  vmexit.swift
//  
//
//  Created by Simon Evans on 10/12/2019.
//

public typealias IOPort = UInt16

public enum VMExit: Equatable {

    // Used by IN/OUT and MMIO instructions
    public enum DataRead: Equatable {
        case byte
        case word
        case dword
        case qword

        init?(bitWidth: UInt8) {
            switch bitWidth {
                case 8: self = .byte
                case 16: self = .word
                case 32: self = .dword
                case 64: self = .qword
                default: return nil
            }
        }
    }

    public enum DataWrite: Equatable, CustomStringConvertible {
        case byte(UInt8)
        case word(UInt16)
        case dword(UInt32)
        case qword(UInt64)

        init?(bitWidth: UInt8, value: UInt64) {
            switch bitWidth {
                case 8: self = .byte(UInt8(truncatingIfNeeded: value))
                case 16: self = .word(UInt16(truncatingIfNeeded: value))
                case 32: self = .dword(UInt32(truncatingIfNeeded: value))
                case 64: self = .qword(value)
                default: return nil
            }
        }

        public var description: String {
            switch self {
                case .byte(let value): return String(value, radix: 16)
                case .word(let value): return String(value, radix: 16)
                case .dword(let value): return String(value, radix: 16)
                case .qword(let value): return String(value, radix: 16)
            }
        }
    }


    public struct ExceptionInfo: Equatable {
        enum Exception: UInt32 {
            case divideError = 0
            case debug = 1
            case nmi = 2
            case breakpoint = 3
            case overflow = 4
            case boundRangeExceeded = 5
            case undefinedOpcode = 6
            case deviceNotAvailable = 7
            case doubleFault = 8
            case coprocessorSegmentOverrun = 9
            case invalidTSS = 10
            case segmentNotPresent = 11
            case stackSegmentationFalue = 12
            case generalProtection = 13
            case pageFault = 14
            case reserved15 = 15
            case floatingPintError = 16
            case alignmentCheck = 17
            case machineCheck = 18
            case simdFloatingPointException = 19
            case virtualizationException = 20
            case controlProtectionException = 21
            case reserved22 = 22
            case reserved23 = 23
            case reserved24 = 24
            case reserved25 = 25
            case reserved26 = 26
            case reserved27 = 27
            case reserved28 = 28
            case reserved29 = 29
            case reserved30 = 30
            case reserved31 = 31
        }

        let exception: Exception
        let errorCode: UInt32?

        init?(exception: UInt32, errorCode: UInt32? = nil) {
            guard let e = Exception(rawValue: exception) else { return nil }
            self.exception = e
            self.errorCode = errorCode
        }
    }

    public struct Debug: Equatable {
        let rip: UInt64
        let dr6: UInt64
        let dr7: UInt64
        let exception: UInt32
    }

    public struct TPRAccess: Equatable {
        // TODO
    }

    public struct HyperV: Equatable {
        // TODO
    }

    public struct SystemEvent: Equatable {
        // TODO
    }


    public struct MemoryViolation: Equatable {
        enum Access {
            case read
            case write
            case instructionFetch
        }

        let access: Access
        let readable: Bool
        let writeable: Bool
        let executable: Bool
        let guestPhysicalAddress: UInt64
        let guestLinearAddress: UInt?
    }


    case unknown(UInt64)
    case exception(ExceptionInfo)
    case ioInOperation(IOPort, DataRead)
    case ioOutOperation(IOPort, DataWrite)
    case debug(Debug)
    case hlt
    case mmioReadOperation(PhysicalAddress, DataRead)
    case mmioWriteOperation(PhysicalAddress, DataWrite)
    case irqWindowOpen
    case shutdown
    case entryFailed(UInt64)
    case interrupt
    case setTpr
    case tprAccess(TPRAccess)
    case nmi
    #if os(Linux)
    case internalError(InternalError)
    #endif
    case memoryViolation(MemoryViolation)
    case systemEvent(SystemEvent)
    case ioapicEOI(UInt8)
    case hyperV(HyperV)
}
