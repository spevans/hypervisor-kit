//
//  vmexit.swift
//  
//
//  Created by Simon Evans on 10/12/2019.
//

enum VMExit: Equatable {

    struct IOInOperation: Equatable {
        enum Data: Equatable {
            case byte
            case word
            case dword
            case bytes(PhysicalAddress, UInt32)
            case words(PhysicalAddress, UInt32)
            case dwords(PhysicalAddress, UInt32)

            init(bitWidth: UInt8) {
                if bitWidth == 8 {
                    self = .byte
                } else if bitWidth == 16 {
                    self = .word
                } else {
                    self = .dword
                }
            }

            init(bitWidth: UInt8, address: UInt64, count: UInt32) {
                if bitWidth == 8 {
                    self = .bytes(address, count)
                } else if bitWidth == 16 {
                    self = .words(address, count)
                } else {
                    self = .dwords(address, count)
                }
            }

        }

        //let bitWidth: UInt8
        let port: UInt16
        let data: Data

        init(port: UInt16, bitWidth: UInt8) {
            self.port = port
            self.data = Data(bitWidth: bitWidth)
        }

        init(port: UInt16, bitWidth: UInt8, address: PhysicalAddress, count: UInt32) {
            self.port = port
            self.data = Data(bitWidth: bitWidth, address: address, count: count)
        }
    }

    struct IOOutOperation: Equatable {
        enum Data: Equatable {
            case byte(UInt8)
            case word(UInt16)
            case dword(UInt32)
            case bytes(PhysicalAddress, UInt32)
            case words(PhysicalAddress, UInt32)
            case dwords(PhysicalAddress, UInt32)

            init(bitWidth: UInt8, rax: UInt64) {
                if bitWidth == 8 {
                    self = .byte(UInt8(truncatingIfNeeded: rax))
                } else if bitWidth == 16 {
                    self = .word(UInt16(truncatingIfNeeded: rax))
                } else {
                    self = .dword(UInt32(truncatingIfNeeded: rax))
                }
            }

            init(bitWidth: UInt8, address: PhysicalAddress, count: UInt32) {
                if bitWidth == 8 {
                    self = .bytes(address, count)
                } else if bitWidth == 16 {
                    self = .words(address, count)
                } else {
                    self = .dwords(address, count)
                }
            }

        }
        
        let port: UInt16
        let data: Data

        init(port: UInt16, bitWidth: UInt8, rax: UInt64) {
            self.port = port
            self.data = Data(bitWidth: bitWidth, rax: rax)
        }

        init(port: UInt16, bitWidth: UInt8, address: PhysicalAddress, count: UInt32) {
            self.port = port
            self.data = Data(bitWidth: bitWidth, address: address, count: count)
        }

    }


    struct MMIOOperation: Equatable {
        let isWrite: Bool
        let length: UInt32
        let physicalAddress: UInt64
        let data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

        static func == (lhs: VMExit.MMIOOperation, rhs: VMExit.MMIOOperation) -> Bool {
            lhs.isWrite == rhs.isWrite
                && lhs.length == rhs.length
                && lhs.physicalAddress == rhs.physicalAddress
        }
    }

    struct ExceptionInfo: Equatable {
        enum Exception: UInt8 {
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

        init?(exception: UInt8, errorCode: UInt32? = nil) {
            guard let e = Exception(rawValue: exception) else { return nil}
            self.exception = e
            self.errorCode = errorCode
        }
    }

    struct Debug: Equatable {
        let rip: UInt64
        let dr6: UInt64
        let dr7: UInt64
        let exception: UInt32
    }

    struct TPRAccess: Equatable {
        // TODO
    }

    struct HyperV: Equatable {
        // TODO
    }

    struct SystemEvent: Equatable {
        // TODO
    }


    struct MemoryViolation: Equatable {
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
    case ioInOperation(IOInOperation)
    case ioOutOperation(IOOutOperation)
    case debug(Debug)
    case hlt
    case mmioOp(MMIOOperation)
    case irqWindowOpen
    case shutdown
    case entryFailed(UInt64)
    case interrupt
    case setTpr
    case tprAccess(TPRAccess)
    case nmi
    #if os(Linux)
    case internalError(KVMExit.InternalError)
    #endif
    case memoryViolation(MemoryViolation)
    case systemEvent(SystemEvent)
    case ioapicEOI(UInt8)
    case hyperV(HyperV)
}
