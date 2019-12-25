//
//  File.swift
//  
//
//  Created by Simon Evans on 10/12/2019.
//

#if os(Linux)

typealias KVM_RUN_PTR = UnsafeMutablePointer<kvm_run>

// X86 exits only
enum KVMExit: UInt32 {

    struct InternalError: Equatable {
        let subError: UInt32
        let nData: UInt32
        let data: (UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64)

        static func == (lhs: Self, rhs: Self) -> Bool {
            (lhs.subError == rhs.subError) && (lhs.nData == rhs.nData)
        }
    }


    case unknown = 0
    case exception = 1
    case io = 2
    case debug = 4
    case hlt = 5
    case mmio = 6
    case irqWindowOpen = 7
    case shutdown = 8
    case failEntry = 9
    case intr = 10
    case setTpr = 11
    case tprAccess = 12
    case nmi = 16
    case internalError = 17
    case systemEvent = 24
    case ioapicEoi = 26
    case hyperV = 27


    func vmExit(kvmRunPtr: KVM_RUN_PTR) -> VMExit {
        switch self {

            case .unknown:
                return VMExit.unknown(kvmRunPtr.pointee.hw.hardware_exit_reason)

            case .exception:
                return VMExit.exception(VMExit.ExceptionInfo(exception: kvmRunPtr.pointee.ex.exception, errorCode: kvmRunPtr.pointee.ex.error_code)!)

            case .io:
                let io = kvmRunPtr.pointee.io
                print("IO:", io)
                let dataOffset = io.data_offset
                let bitWidth = io.size * 8
                if io.count != 1 { fatalError("IO op with count != 1") }

                if io.direction == 0 {  // In
                    return VMExit.ioInOperation(VMExit.IOInOperation(
                        port: io.port,
                        bitWidth: bitWidth)
                    )
                } else {
                    let ptr = UnsafeMutableRawPointer(kvmRunPtr).advanced(by: Int(dataOffset))

                    let data: VMExit.IOOutOperation.Data = {
                        switch bitWidth {
                            case 8: return .byte(ptr.load(as: UInt8.self))
                            case 16: return .word(ptr.load(as: UInt16.self))
                            case 32: return .dword(ptr.load(as: UInt32.self))
                            default: fatalError("bad width")
                        }
                    }()

                    return VMExit.ioOutOperation(VMExit.IOOutOperation(
                        port: io.port,
                        data: data)
                    )
            }

            case .debug:
                let debugInfo = kvmRunPtr.pointee.debug.arch
                return VMExit.debug(VMExit.Debug(rip: debugInfo.pc, dr6: debugInfo.dr6, dr7: debugInfo.dr7, exception: debugInfo.exception))

            case .hlt:
                return VMExit.hlt

            case .mmio:
                let mmio = kvmRunPtr.pointee.mmio
                print("mmio:", mmio)
                let mmioOp = VMExit.MMIOOperation(isWrite: Bool(mmio.is_write), length: mmio.len, physicalAddress: mmio.phys_addr, data: mmio.data)
                return VMExit.mmioOp(mmioOp)

            case .irqWindowOpen:
                return VMExit.irqWindowOpen

            case .shutdown:
                return VMExit.shutdown

            case .failEntry:
                return VMExit.entryFailed(kvmRunPtr.pointee.fail_entry.hardware_entry_failure_reason)

            case .intr:
                return VMExit.interrupt

            case .setTpr:
                return VMExit.setTpr

            case .tprAccess:
                return VMExit.tprAccess(VMExit.TPRAccess())

            case .nmi:
                return VMExit.nmi

            case .internalError:
                let error = kvmRunPtr.pointee.internal
                return VMExit.internalError(InternalError(subError: error.suberror, nData: error.ndata, data: error.data))

            case .systemEvent:
                return VMExit.systemEvent(VMExit.SystemEvent())

            case .ioapicEoi:
                return VMExit.ioapicEOI(kvmRunPtr.pointee.eoi.vector)

            case .hyperV:
                return VMExit.hyperV(VMExit.HyperV())

//            @unknown default:
//            fatalError("Unknwon KVM exit code: \(self.rawValue)")
        }

    }
}

#endif

