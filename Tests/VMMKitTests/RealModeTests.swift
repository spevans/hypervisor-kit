//
//  RealModeTests.swift
//  VMMKit
//
//  Created by Simon Evans on 08/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import XCTest
import Foundation
import VMMKit


final class RealModeTests: XCTestCase {

    static var allTests: [(String, (RealModeTests) -> () throws -> Void)] = [
        ("testHLT", testHLT),
        ("testReadWriteMemory", testReadWriteMemory),
        ("testOut", testOut),
        ("testIn", testIn),
        // FIXME - Make these two tests useful.
        //   ("testMMIO", testMMIO),
        ("testInstructionPrefixes", testInstructionPrefixes)
    ]

    private var _realModeTestCode: Data? = nil
    private func realModeTestCode() throws -> Data {
        if _realModeTestCode == nil {
            guard let url = Bundle.module.url(forResource: "real_mode_test", withExtension: "bin") else {
                fatalError("Cannot find real_mode_test.bin test file")
            }
            _realModeTestCode = try Data(contentsOf: url)
        }
        return _realModeTestCode!
    }


    private func createRealModeVM() throws -> (VirtualMachine, VirtualMachine.VCPU) {
        let vm = try VirtualMachine(logger: logger)
        let memRegion = try vm.addMemory(at: 0x1000, size: 8192)
        let testCode = try realModeTestCode()
        try memRegion.loadBinary(from: testCode, atOffset: 0)
        let vcpu = try vm.createVCPU(startup: { $0.setupRealMode() })

        return (vm, vcpu)
    }


    private func runCPU(vcpu: VirtualMachine.VCPU, waitingFor timeinterval: DispatchTimeInterval) -> Bool {
        let group = DispatchGroup()
        group.enter()
        vcpu.completionHandler = {
            group.leave()
        }
        do {
            try vcpu.start()
        } catch {
            XCTFail("Cannot start vcpu: \(error)")
            group.leave()
            return false
        }
        let result = group.wait(timeout: .now() + timeinterval)
        return result == .success
    }


    private func runTest(vcpu: VirtualMachine.VCPU, ax: UInt16) -> Bool {
        vcpu.registers.cs.selector = 0
        vcpu.registers.cs.base = 0
        vcpu.registers.ax = ax
        vcpu.registers.rip = 0x1000

        return runCPU(vcpu: vcpu, waitingFor: .seconds(1))
    }


    func testHLT() throws {
        let (vm, vcpu) = try createRealModeVM()

        var gotHLT = false
        vcpu.vmExitHandler = { (vcpu, vmExit) -> Bool in
            XCTAssertEqual(vmExit, .hlt)
            gotHLT = (vmExit == .hlt)
            return true
        }
        XCTAssertTrue(runTest(vcpu: vcpu, ax: 0))
        XCTAssertTrue(gotHLT)
        XCTAssertTrue(vm.allVcpusShutdown())
        XCTAssertNoThrow(try vm.shutdown())
    }


    func testReadWriteMemory() throws {
        let (vm, vcpu) = try createRealModeVM()
        let memRegion = vm.memoryRegions[0]

        let src_data = memRegion.rawBuffer.baseAddress!.advanced(by: 0x320)
        XCTAssertEqual(src_data.advanced(by: 0).load(as: UInt8.self), 0xaa)
        XCTAssertEqual(src_data.advanced(by: 1).load(as: UInt8.self), 0xbb)
        XCTAssertEqual(src_data.advanced(by: 2).load(as: UInt8.self), 0xcc)
        XCTAssertEqual(src_data.advanced(by: 3).load(as: UInt8.self), 0xdd)

        let dest_data = memRegion.rawBuffer.baseAddress!.advanced(by: 0x1000)
        XCTAssertEqual(dest_data.advanced(by: 0).load(as: UInt8.self), 0)
        XCTAssertEqual(dest_data.advanced(by: 1).load(as: UInt8.self), 0)
        XCTAssertEqual(dest_data.advanced(by: 2).load(as: UInt8.self), 0)
        XCTAssertEqual(dest_data.advanced(by: 3).load(as: UInt8.self), 0)

        memRegion.rawBuffer.baseAddress!.advanced(by: 0x200).storeBytes(of: 0x1234, as: UInt16.self)

        vcpu.vmExitHandler = { (vcpu, vmExit) -> Bool in
            return (vmExit == .hlt)
        }

        XCTAssertTrue(runTest(vcpu: vcpu, ax: 1))
        vm.shutdownAllVcpus()
        let word = memRegion.rawBuffer.baseAddress!.advanced(by: 0x200).load(as: UInt16.self)
        XCTAssertEqual(word, 0x1235)

        XCTAssertEqual(dest_data.advanced(by: 0).load(as: UInt8.self), 0xaa)
        XCTAssertEqual(dest_data.advanced(by: 1).load(as: UInt8.self), 0xbb)
        XCTAssertEqual(dest_data.advanced(by: 2).load(as: UInt8.self), 0xcc)
        XCTAssertEqual(dest_data.advanced(by: 3).load(as: UInt8.self), 0xdd)
        XCTAssertTrue(vm.allVcpusShutdown())
        XCTAssertNoThrow(try vm.shutdown())
    }


    #if false
    func testMMIO() throws {
        let (vm, vcpu) = try createRealModeVM()

        var count = 0
        var vmExits: [VMExit] = []
        vmExits.reserveCapacity(10)
        vcpu.vmExitHandler = { (vcpu, vmExit) -> Bool in
            vmExits.append(vmExit)
            count += 1
            return (count >= 10 || vmExit == .hlt)  // true == finish
        }
        XCTAssertTrue(runTest(vcpu: vcpu, ax: 3))
        XCTAssertEqual(count, 10)
        XCTAssertTrue(vm.allVcpusShutdown())
        XCTAssertNoThrow(try vm.shutdown())
    }
    #endif


    func testOut() throws {

        let bytes: [UInt8] = [
            0x12, 0x34, 0x56, 0x78,
            0x11, 0x22, 0x33, 0x44,
            0x00, 0x00, 0x00, 0x01,
            0xaa, 0xbb, 0xcc, 0xdd,
            0xfe, 0xdc, 0xba, 0x98,
            0x55, 0xaa, 0xcc, 0xdd,
        ]

        let words: [UInt16] = [
            0xddcc, 0xaa55,
            0x98ba, 0xdcfe,
            0xddcc, 0xbbaa,
            0x0100, 0x0000,
            0x4433, 0x2211,
            0x7856, 0x3412,
        ]

        let dwords: [UInt32] = [
            0x78563412,
            0x44332211,
            0x01000000,
            0xddccbbaa,
            0x98badcfe,
            0xddccaa55,
        ]

        let unalignedDwords: [UInt32] = [
            0x11785634,
            0x00443322,
            0xaa010000,
            0xfeddccbb,
            0x5598badc,
        ]

        let unalignedWords: [UInt16] = [
            0xbadc, 0xfedd,
            0xccbb, 0xaa01,
            0x0000, 0x0044,
            0x3322, 0x1178,
            0x5634, 0x1290,
        ]

        let csOverrideBytes: [UInt8] = [
            0x12, 0x34, 0x56, 0x78,
        ]

        let dsOverrideBytes: [UInt8] = [
            0x11, 0x22, 0x33, 0x44,
        ]

        let esOverrideBytes: [UInt8] = [
            0x00, 0x00, 0x00, 0x01,
        ]

        let fsOverrideBytes: [UInt8] = [
            0xaa, 0xbb, 0xcc, 0xdd,
        ]

        let gsOverrideBytes: [UInt8] = [
            0xfe, 0xdc, 0xba, 0x98,
        ]

        let ssOverrideBytes: [UInt8] = [
            0x55, 0xaa, 0xcc, 0xdd,
        ]

        let (vm, vcpu) = try createRealModeVM()


        var vmExits: [VMExit] = []
        vmExits.reserveCapacity(100)

        vcpu.vmExitHandler = { (vcpu, vmExit) -> Bool in
            vmExits.append(vmExit)
            return (vmExit == .hlt)
        }

        XCTAssertTrue(runTest(vcpu: vcpu, ax: 2))
        XCTAssertEqual(vmExits.count, 82)


        var vmExit = vmExits.removeFirst()
        for byte in bytes {
            if case let VMExit.ioOutOperation(port, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
                XCTAssertEqual(port, 0x60)
            } else {
                XCTFail("Not an OUTS")
            }
            vmExit = vmExits.removeFirst()
        }


        for word in words {
            if case let VMExit.ioOutOperation(port, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.word(word))
                XCTAssertEqual(port, 0x60)
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = vmExits.removeFirst()
        }

        for dword in dwords {
            if case let VMExit.ioOutOperation(port, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.dword(dword))
                XCTAssertEqual(port, 0x60)
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = vmExits.removeFirst()
        }

        // Test unaligned data
        for dword in unalignedDwords {
            if case let VMExit.ioOutOperation(port, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.dword(dword))
                XCTAssertEqual(port, 0x60)
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = vmExits.removeFirst()
        }

        for word in unalignedWords {
            if case let VMExit.ioOutOperation(port, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.word(word))
                XCTAssertEqual(port, 0x60)
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = vmExits.removeFirst()
        }

        // Test Segment Overrides
        #if true
        for byte in csOverrideBytes {
            if case let VMExit.ioOutOperation(_, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = vmExits.removeFirst()
        }
        #endif

        vcpu.registers.ds.selector = 0x100
        vcpu.registers.ds.base = 0x1000

        for byte in dsOverrideBytes {
            if case let VMExit.ioOutOperation(_, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
            } else {
                logger.trace("DS: \(String(vcpu.registers.ds.selector, radix: 16)) \(String(vcpu.registers.ds.base, radix: 16))")
                logger.trace("CS:IP \(String(vcpu.registers.cs.base, radix: 16)):\(String(vcpu.registers.rip, radix: 16))")
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = vmExits.removeFirst()
        }
        #if true
        for byte in esOverrideBytes {
            if case let VMExit.ioOutOperation(_, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = vmExits.removeFirst()
        }

        for byte in fsOverrideBytes {
            if case let VMExit.ioOutOperation(_, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = vmExits.removeFirst()
        }

        for byte in gsOverrideBytes {
            if case let VMExit.ioOutOperation(_, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = vmExits.removeFirst()
        }

        for byte in ssOverrideBytes {
            if case let VMExit.ioOutOperation(_, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = vmExits.removeFirst()
        }

        XCTAssertEqual(vmExit, .hlt)
        #endif

        XCTAssertTrue(vm.allVcpusShutdown())
        XCTAssertNoThrow(try vm.shutdown())
    }


    func testIn() throws {
        let (vm, vcpu) = try createRealModeVM()

        var testNumber = 1
        vcpu.vmExitHandler = { (vcpu, vmExit) -> Bool in

            if case let VMExit.ioInOperation(port, dataRead) = vmExit {
                switch testNumber {
                    case 1:     // IN 0x60, AL
                        XCTAssertEqual(port, 0x60)
                        guard VMExit.DataRead.byte == dataRead else {
                            XCTFail("dataRead is not a .byte but a \(dataRead)")
                            return true
                        }
                        XCTAssertEqual(dataRead, VMExit.DataRead.byte, "IN 0x60, AL")
                        vcpu.setIn(data: VMExit.DataWrite.byte(0x12))

                    case 2:     // IN 0x60, AX
                        XCTAssertEqual(port, 0x60)
                        guard VMExit.DataRead.word == dataRead else {
                            XCTFail("dataRead is not a .word but a \(dataRead)")
                            return true
                        }
                        XCTAssertEqual(dataRead, VMExit.DataRead.word)
                        vcpu.setIn(data: VMExit.DataWrite.word(0xabcd))

                    case 3:     // IN 0x60, EAX
                        XCTAssertEqual(port, 0x60)
                        guard VMExit.DataRead.dword == dataRead else {
                            XCTFail("dataRead is not a .dword but a \(dataRead)")
                            return true
                        }
                        XCTAssertEqual(dataRead, VMExit.DataRead.dword)
                        vcpu.setIn(data: VMExit.DataWrite.dword(0xDEADC0DE))

                    default:
                        XCTFail("Unexpected testNumber: \(testNumber)")
                        return true
                }

                return false    // Keep going, dont finish yet
            }

            if vmExit == .hlt {
                switch testNumber {
                    case 1:
                        XCTAssertEqual(vcpu.registers.rax, 0x12)

                    case 2:
                        XCTAssertEqual(vcpu.registers.rax, 0xABCD)

                    case 3:
                        XCTAssertEqual(vcpu.registers.rax, 0xDEADC0DE)
                        // All tests are now complete, so no more exits required
                        return true

                    default:
                        XCTFail("Unexpected testNumber: \(testNumber)")
                        return true
                }
                testNumber += 1
                return false
            }

            XCTFail("Unexpected vmExit: \(vmExit)")
            return true
        }

        XCTAssertTrue(runTest(vcpu: vcpu, ax: 3))
        XCTAssertEqual(testNumber, 3)

        XCTAssertTrue(vm.allVcpusShutdown())
        XCTAssertNoThrow(try vm.shutdown())
    }


    func testInstructionPrefixes() throws {
        let (vm, vcpu) = try createRealModeVM()
        let memRegion = vm.memoryRegions[0]
        memRegion.rawBuffer.baseAddress!.advanced(by: 0x200).storeBytes(of: 0x1234, as: UInt16.self)
        vcpu.registers.rip = 0x1100
        vcpu.registers.rflags.trap = true

        var vmExit: VMExit?
        vcpu.vmExitHandler = { (vcpu, _vmExit) -> Bool in
            vmExit = _vmExit
            return true
        }
        XCTAssertTrue(runCPU(vcpu: vcpu, waitingFor: .seconds(1)))


        XCTAssertEqual(vcpu.registers.rip, 0x1100)
        XCTAssertNotNil(vmExit)
        //XCTAssertEqual(try vcpu.vmcs.vmExitInstructionLength(), 1)
        //vcpu.registers.rip += 1
        // XCTAssertEqual(try vcpu.vmcs.vmExitInstructionLength(), 1)
        //vcpu.registers.rip += 1

        XCTAssertTrue(vm.allVcpusShutdown())
        XCTAssertNoThrow(try vm.shutdown())
    }
}
