//
//  kvmexit.swift
//  HypervisorKit
//
//  Created by Simon Evans on 10/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

#if os(Linux)
@_implementationOnly import CHypervisorKit

typealias KVM_RUN_PTR = UnsafeMutablePointer<kvm_run>

public struct InternalError: Equatable {
    let subError: UInt32
    let nData: UInt32
    let data: (UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64)

    public static func == (lhs: Self, rhs: Self) -> Bool {
        (lhs.subError == rhs.subError) && (lhs.nData == rhs.nData)
    }
}

// X86 exits only
enum KVMExit: UInt32 {

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
                let dataOffset = io.data_offset
                let bitWidth = io.size * 8
                if io.count != 1 { fatalError("IO op with count != 1") }

                if io.direction == 0 {  // In
                    if let data = VMExit.DataRead(bitWidth: bitWidth) {
                        return VMExit.ioInOperation(io.port, data)
                    }
                } else {
                    let ptr = UnsafeMutableRawPointer(kvmRunPtr).advanced(by: Int(dataOffset))

                    switch bitWidth {
                        case 8: return VMExit.ioOutOperation(io.port, .byte(ptr.load(as: UInt8.self)))
                        case 16: return VMExit.ioOutOperation(io.port, .word(ptr.load(as: UInt16.self)))
                        case 32: return VMExit.ioOutOperation(io.port, .dword(ptr.load(as: UInt32.self)))
                        case 64: return VMExit.ioOutOperation(io.port, .qword(ptr.load(as: UInt64.self)))
                        default: break
                    }
            }

            case .debug:
                let debugInfo = kvmRunPtr.pointee.debug.arch
                return .debug(VMExit.Debug(rip: debugInfo.pc, dr6: debugInfo.dr6, dr7: debugInfo.dr7, exception: debugInfo.exception))

            case .hlt:
                return VMExit.hlt

            case .mmio:
                let mmio = kvmRunPtr.pointee.mmio
                let address = PhysicalAddress(mmio.phys_addr)
                if Bool(mmio.is_write) {
                    switch mmio.len {
                        case 1: return .mmioWriteOperation(address, .byte(mmio.data.0))
                        case 2: return .mmioWriteOperation(address, .word(UInt16(bytes: (mmio.data.0, mmio.data.1))))
                        case 4: return .mmioWriteOperation(address, .dword(UInt32(bytes: (mmio.data.0, mmio.data.1, mmio.data.2, mmio.data.3))))
                        case 8: return .mmioWriteOperation(address, .qword(UInt64(bytes: mmio.data)))
                        default: break
                    }
                } else {
                    switch mmio.len {
                        case 1: return .mmioReadOperation(address, .byte)
                        case 2: return .mmioReadOperation(address, .word)
                        case 4: return .mmioReadOperation(address, .dword)
                        case 8: return .mmioReadOperation(address, .qword)
                        default: break
                    }
                }
                fatalError("Cant handle MMIO exit: \(mmio)")


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
        }
        fatalError("Cant process: \(self)")
    }
}

#endif

