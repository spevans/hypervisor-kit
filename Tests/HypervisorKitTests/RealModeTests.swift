import XCTest
import Foundation

import HypervisorKit


final class RealModeTests: XCTestCase {

    private var _realModeTestCode: Data? = nil
    private func realModeTestCode() throws -> Data {
        if let code = _realModeTestCode {
            return code
        }
        #if os(Linux)
        let url = URL(fileURLWithPath: "real_mode_test.bin", isDirectory: false)
        #else

        let url = URL(fileURLWithPath: "/Users/spse/Files/src/osx/HypervisorKit/real_mode_test.bin", isDirectory: false)
        #endif
        let code = try Data(contentsOf: url)
        _realModeTestCode = code
        return code
    }

    
    private func createRealModeVM() throws -> VirtualMachine {
        
        guard let vm = try? VirtualMachine() else {
            XCTFail("Cant create VM")
            throw TestError.vmCreateFail
        }
        
        guard let memRegion = try? vm.addMemory(at: 0x1000, size: 8192) else {
            XCTFail("Cant add memory region")
            throw TestError.addMemoryFail
        }

        let testCode = try realModeTestCode()
        try memRegion.loadBinary(from: testCode, atOffset: 0)

        guard let vcpu = try? vm.createVCPU() else {
            XCTFail("Cant create VCPU")
            throw TestError.vcpuCreateFail
        }
        vcpu.setupRealMode()

        return vm
    }        

    private func runTest(vcpu: VirtualMachine.VCPU, ax: UInt16, skipEPT: Bool = true) throws -> VMExit {

        print("Running VCPU with ax:", ax)

        vcpu.registers.cs.selector = 0
        vcpu.registers.cs.base = 0
        vcpu.registers.ax = ax
        vcpu.registers.rip = 0x1000

        while true {
            let vmExit = try vcpu.run()
            print("VMExit Reason:", vmExit)
            
            switch vmExit {
                default:
                    return vmExit
            }
        }
    }


    func testMMIO() throws {
        let vm = try createRealModeVM()
        let vcpu = vm.vcpus[0]
        var vmExit = try runTest(vcpu: vcpu, ax: 3)
        var count = 0
        while count < 10 && vmExit != .hlt {
            print(vmExit)
            vmExit = try vcpu.run()
            count += 1
        }
    }


    func testInstructionPrefixes() throws {
        let vm = try createRealModeVM()
        let memRegion = vm.memoryRegions[0]
        memRegion.rawBuffer.baseAddress!.advanced(by: 0x200).storeBytes(of: 0x1234, as: UInt16.self)
        let vcpu = vm.vcpus[0]
        vcpu.registers.rip = 0x1100
        vcpu.registers.rflags.trap = true
        var vmExit = try vcpu.run()
        XCTAssertEqual(vcpu.registers.rip, 0x1100)
        //XCTAssertEqual(try vcpu.vmcs.vmExitInstructionLength(), 1)
        //vcpu.registers.rip += 1
        vmExit = try vcpu.run()
        // XCTAssertEqual(try vcpu.vmcs.vmExitInstructionLength(), 1)
        //vcpu.registers.rip += 1
        vmExit = try vcpu.run()

    }


    func testHLT() throws {
        let vm = try createRealModeVM()
        let memRegion = vm.memoryRegions[0]

        dumpMemory(memRegion, offset: 0x320, count: 8)

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
        let vcpu = vm.vcpus[0]
        showRegisters(vcpu)
        var vmExit = try runTest(vcpu: vcpu, ax: 0)
        while vmExit != .hlt {
            print(vmExit)
            vmExit = try vcpu.run()
            showRegisters(vcpu)
        }

        XCTAssertEqual(vmExit, .hlt)
        dumpMemory(memRegion, offset: 0x320, count: 8)
        let ax = vcpu.registers.ax
        let word = memRegion.rawBuffer.baseAddress!.advanced(by: 0x200).load(as: UInt16.self)
        print("Word: ", String(word, radix: 16))
        print("RAX:", String(ax, radix: 16))
        XCTAssertEqual(word, 0x1235)
        XCTAssertEqual(vcpu.registers.ax, 0x1235)
        XCTAssertEqual(vcpu.registers.rip, 0x1027)

        XCTAssertEqual(dest_data.advanced(by: 0).load(as: UInt8.self), 0xaa)
        XCTAssertEqual(dest_data.advanced(by: 1).load(as: UInt8.self), 0xbb)
        XCTAssertEqual(dest_data.advanced(by: 2).load(as: UInt8.self), 0xcc)
        XCTAssertEqual(dest_data.advanced(by: 3).load(as: UInt8.self), 0xdd)

    }

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

        let vm = try createRealModeVM()
        let vcpu = vm.vcpus[0]

        var vmExit = try runTest(vcpu: vcpu, ax: 1)
        for byte in bytes {
            if case let VMExit.ioOutOperation(port, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
                XCTAssertEqual(port, 0x60)
            } else {
                XCTFail("Not an OUTS")
            }
            vmExit = try vcpu.run()
        }


        for word in words {
            if case let VMExit.ioOutOperation(port, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.word(word))
                XCTAssertEqual(port, 0x60)
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            //print("RSI:", String(vcpu.registers.rsi, radix: 16))
            vmExit = try vcpu.run()
        }

        for dword in dwords {
            if case let VMExit.ioOutOperation(port, data) = vmExit {
                //print(data)
                XCTAssertEqual(data, VMExit.DataWrite.dword(dword))
                XCTAssertEqual(port, 0x60)
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = try vcpu.run()
        }

        // Test unaligned data
        for dword in unalignedDwords {
            if case let VMExit.ioOutOperation(port, data) = vmExit {
                //print(data)
                XCTAssertEqual(data, VMExit.DataWrite.dword(dword))
                XCTAssertEqual(port, 0x60)
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = try vcpu.run()
        }

        for word in unalignedWords {
            if case let VMExit.ioOutOperation(port, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.word(word))
                XCTAssertEqual(port, 0x60)
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            //print("RSI:", String(vcpu.registers.rsi, radix: 16))
            vmExit = try vcpu.run()
        }

        // Test Segment Overrides
        #if true
        for byte in csOverrideBytes {
            if case let VMExit.ioOutOperation(_, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = try vcpu.run()
        }
        #endif

        vcpu.registers.ds.selector = 0x100
        vcpu.registers.ds.base = 0x1000

        for byte in dsOverrideBytes {
            if case let VMExit.ioOutOperation(_, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
            } else {
                print("DS:", String(vcpu.registers.ds.selector, radix: 16), String(vcpu.registers.ds.base, radix: 16))
                print("CS:IP \(String(vcpu.registers.cs.base, radix: 16)):\(String(vcpu.registers.rip, radix: 16))")
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = try vcpu.run()
        }
        #if true
        for byte in esOverrideBytes {
            if case let VMExit.ioOutOperation(_, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = try vcpu.run()
        }

        for byte in fsOverrideBytes {
            if case let VMExit.ioOutOperation(_, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = try vcpu.run()
        }

        for byte in gsOverrideBytes {
            if case let VMExit.ioOutOperation(_, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = try vcpu.run()
        }

        for byte in ssOverrideBytes {
            if case let VMExit.ioOutOperation(_, data) = vmExit {
                XCTAssertEqual(data, VMExit.DataWrite.byte(byte))
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = try vcpu.run()
        }


        XCTAssertEqual(vmExit, .hlt)
        #endif

    }


    func testIn() throws {
        let vm = try createRealModeVM()
        let vcpu = vm.vcpus[0]

        var vmExit = try runTest(vcpu: vcpu, ax: 5)

        // IN 0x60, AL
        if case let VMExit.ioInOperation(port, dataRead) = vmExit {
            XCTAssertEqual(port, 0x60)
            guard VMExit.DataRead.byte == dataRead else {
                XCTFail("dataRead is not a .byte but a \(dataRead)")
                return
            }

            XCTAssertEqual(dataRead, VMExit.DataRead.byte)
            vcpu.setIn(data: VMExit.DataWrite.byte(0x12))
        }
        vmExit = try vcpu.run()
        XCTAssertEqual(vmExit, .hlt)
        XCTAssertEqual(vcpu.registers.rax, 0x12)

        // IN 0x60, AX
        vmExit = try vcpu.run()
        if case let VMExit.ioInOperation(port, dataRead) = vmExit {
            XCTAssertEqual(port, 0x60)
            guard VMExit.DataRead.word == dataRead else {
                XCTFail("dataRead is not a .word but a \(dataRead)")
                return
            }

            XCTAssertEqual(dataRead, VMExit.DataRead.word)
            vcpu.setIn(data: VMExit.DataWrite.word(0xabcd))
        }
        vmExit = try vcpu.run()
        XCTAssertEqual(vmExit, .hlt)
        XCTAssertEqual(vcpu.registers.rax, 0xABCD)

        // IN 0x60, EAX
        vmExit = try vcpu.run()
        if case let VMExit.ioInOperation(port, dataRead) = vmExit {
            XCTAssertEqual(port, 0x60)
            guard VMExit.DataRead.dword == dataRead else {
                XCTFail("dataRead is not a .dword but a \(dataRead)")
                return
            }

            XCTAssertEqual(dataRead, VMExit.DataRead.dword)
            vcpu.setIn(data: VMExit.DataWrite.dword(0xDEADC0DE))
        }
        vmExit = try vcpu.run()
        XCTAssertEqual(vmExit, .hlt)
        XCTAssertEqual(vcpu.registers.rax, 0xDEADC0DE)

    }

    func showRegisters(_ vcpu: VirtualMachine.VCPU) {
        func showReg(_ name: String, _ value: UInt16) {
            let w = hexNum(value, width: 4)
            print("\(name): \(w)", terminator: " ")
        }

        showReg("CS", vcpu.registers.cs.selector)
        showReg("SS", vcpu.registers.ss.selector)
        showReg("DS", vcpu.registers.ds.selector)
        showReg("ES", vcpu.registers.es.selector)
        showReg("FS", vcpu.registers.fs.selector)
        showReg("GS", vcpu.registers.gs.selector)
        print("FLAGS", vcpu.registers.rflags)
        showReg("IP", vcpu.registers.ip)
        showReg("AX", vcpu.registers.ax)
        showReg("BX", vcpu.registers.bx)
        showReg("CX", vcpu.registers.cx)
        showReg("DX", vcpu.registers.dx)
        showReg("DI", vcpu.registers.di)
        showReg("SI", vcpu.registers.si)
        showReg("BP", vcpu.registers.bp)
        showReg("SP", vcpu.registers.sp)
        print("")
    }


    func hexNum<T: BinaryInteger>(_ value: T, width: Int) -> String {
        let num = String(value, radix: 16)
        if num.count <= width {
            return String(repeating: "0", count: width - num.count) + num
        }
        return num
    }


    func dumpMemory(_ memory: MemoryRegion, offset: Int, count: Int) {
        let ptr = memory.rawBuffer.baseAddress!.advanced(by: offset)
        let buffer = UnsafeRawBufferPointer(start: ptr, count: count)

        var idx = 0
        print("\(hexNum(offset + idx, width: 5)): ", terminator: "")
        for byte in buffer {
            print(hexNum(byte, width: 2), terminator: " ")
            idx += 1
            if idx == count { break }
            if idx.isMultiple(of: 16) {
                print("\n\(hexNum(offset + idx, width: 5)): ", terminator: "")
            }
        }
        print("\n")
    }


    static var allTests = [
        ("testInstructionPrefixes", testInstructionPrefixes),
        ("testMMIO", testMMIO),
        ("testHLT", testHLT),
        ("testOut", testOut),
        ("testIn", testIn),
    ]
}
