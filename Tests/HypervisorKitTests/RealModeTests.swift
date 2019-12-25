import XCTest
import Foundation

@testable import HypervisorKit


final class RealModeTests: XCTestCase {


    private var _realModeTestCode: Data? = nil
    private func realModeTestCode() throws -> Data {
        if let code = _realModeTestCode {
            return code
        }
        #if os(Linux)
        let url = URL(fileURLWithPath: "real_mode_test.bin", isDirectory: false)
        #else
        let url = URL(fileURLWithPath: "/Users/spse/src//HypervisorKit/real_mode_test.bin", isDirectory: false)
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
        
        guard let memRegion = vm.addMemory(at: 0x1000, size: 8192) else {
            XCTFail("Cant add memory region")
            throw TestError.addMemoryFail
        }


        let testCode = try realModeTestCode()
        testCode.copyBytes(to: memRegion.rawBuffer)
                
        guard let vcpu = try? vm.createVCPU() else {
            XCTFail("Cant create VCPU")
            throw TestError.vcpuCreateFail
        }
        
        vcpu.registers.rip = 0x1000
        vcpu.registers.rflags = CPU.RFLAGS()
        vcpu.registers.rsp = 0x1FFE
        vcpu.registers.rax = 0x0
        
        vcpu.registers.cs.selector = 0
        vcpu.registers.cs.limit = 0xffff
        vcpu.registers.cs.accessRights = 0x9b
        vcpu.registers.cs.base = 0
        
        vcpu.registers.ds.selector = 0
        vcpu.registers.ds.limit = 0xffff
        vcpu.registers.ds.accessRights = 0x93
        vcpu.registers.ds.base = 0
        
        vcpu.registers.es.selector = 0
        vcpu.registers.es.limit = 0xffff
        vcpu.registers.es.accessRights = 0x93
        vcpu.registers.es.base = 0
        
        vcpu.registers.fs.selector = 0
        vcpu.registers.fs.limit = 0xffff
        vcpu.registers.fs.accessRights = 0x93
        vcpu.registers.fs.base = 0
        
        vcpu.registers.gs.selector = 0
        vcpu.registers.gs.limit = 0xffff
        vcpu.registers.gs.accessRights = 0x93
        vcpu.registers.gs.base = 0
        
        vcpu.registers.ss.selector = 0
        vcpu.registers.ss.limit = 0xffff
        vcpu.registers.ss.accessRights = 0x93
        vcpu.registers.ds.base = 0
        
        vcpu.registers.tr.selector = 0
        vcpu.registers.tr.limit = 0
        vcpu.registers.tr.accessRights = 0x83
        vcpu.registers.tr.base = 0
        
        vcpu.registers.ldtr.selector = 0
        vcpu.registers.ldtr.limit = 0
        vcpu.registers.ldtr.accessRights = 0x10000
        vcpu.registers.ldtr.base = 0
        
        vcpu.registers.gdtrBase = 0
        vcpu.registers.gdtrLimit = 0
        vcpu.registers.idtrBase = 0
        vcpu.registers.idtrLimit = 0
        
        vcpu.registers.cr0 = CPU.CR0Register(0x20).value
        vcpu.registers.cr3 = CPU.CR3Register(0).value
        vcpu.registers.cr4 = CPU.CR4Register(0x2000).value
        return vm
    }        


        
    private func runTest(vcpu: VirtualMachine.VCPU, ax: UInt16, skipEPT: Bool = true) throws -> VMExit {

            print("Running VCPU with ax:", ax)

            vcpu.registers.rax = UInt64(ax)
            vcpu.registers.rip = 0x1000

            while true {
            
                guard let vmExit = try? vcpu.run() else {
                    XCTFail("VCPU Run failed")
                    throw HVError.vmRunError
            }
            
            print("VMExit Reason:", vmExit)
            
            switch vmExit {
                default:
                    return vmExit
                }
            }
    }

/*
    func testBadMemoryRead() throws {
        let vm = try createRealModeVM()
        let vcpu = vm.vcpus[0]
        let vmExit = try runTest(vcpu: vcpu, ax: 3)

        XCTAssertEqual(vmExit, .hlt)
        let rax = vcpu.registers.rax //.readRegister(HV_X86_RAX)
        XCTAssertEqual(try? vcpu.vmcs.guestRIP(), 0x100d)
    }
*/



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
        memRegion.rawBuffer.baseAddress!.advanced(by: 0x200).storeBytes(of: 0x1234, as: UInt16.self)
        let vcpu = vm.vcpus[0]
        let vmExit = try runTest(vcpu: vcpu, ax: 0)

        XCTAssertEqual(vmExit, .hlt)
        let rax = vcpu.registers.rax //.readRegister(HV_X86_RAX)
        print("RAX:", String(rax, radix: 16))
        XCTAssertEqual(vcpu.registers.rax, 0x1235)
        XCTAssertEqual(vcpu.registers.rip, 0x100d)
//        XCTAssertEqual(try? vcpu.vmcs.guestRIP(), 0x100d)
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
            if case let VMExit.ioOutOperation(operation) = vmExit {
                XCTAssertEqual(operation.data, VMExit.IOOutOperation.Data.byte(byte))
                XCTAssertEqual(operation.port, 0x60)
            } else {
                XCTFail("Not an OUTS")
            }
            vmExit = try vcpu.run()
        }


        for word in words {
            if case let VMExit.ioOutOperation(operation) = vmExit {
                XCTAssertEqual(operation.data, VMExit.IOOutOperation.Data.word(word))
                XCTAssertEqual(operation.port, 0x60)
            } else {
                XCTFail("Not an OUTS")
            }
            //print("RSI:", String(vcpu.registers.rsi, radix: 16))
            vmExit = try vcpu.run()
        }

        for dword in dwords {
            if case let VMExit.ioOutOperation(operation) = vmExit {
                //print(operation.data)
                XCTAssertEqual(operation.data, VMExit.IOOutOperation.Data.dword(dword))
                XCTAssertEqual(operation.port, 0x60)
            } else {
                XCTFail("Not an OUTS")
            }
            vmExit = try vcpu.run()
        }

        // Test unaligned data
        for dword in unalignedDwords {
            if case let VMExit.ioOutOperation(operation) = vmExit {
                //print(operation.data)
                XCTAssertEqual(operation.data, VMExit.IOOutOperation.Data.dword(dword))
                XCTAssertEqual(operation.port, 0x60)
            } else {
                XCTFail("Not an OUTS")
            }
            vmExit = try vcpu.run()
        }

        for word in unalignedWords {
            if case let VMExit.ioOutOperation(operation) = vmExit {
                XCTAssertEqual(operation.data, VMExit.IOOutOperation.Data.word(word))
                XCTAssertEqual(operation.port, 0x60)
            } else {
                XCTFail("Not an OUTS")
            }
            //print("RSI:", String(vcpu.registers.rsi, radix: 16))
            vmExit = try vcpu.run()
        }

        // Test Segment Overrides
        #if true
        for byte in csOverrideBytes {
            if case let VMExit.ioOutOperation(operation) = vmExit {
                XCTAssertEqual(operation.data, VMExit.IOOutOperation.Data.byte(byte))
            } else {
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = try vcpu.run()
        }
        #endif

        vcpu.registers.ds.selector = 0x100
        vcpu.registers.ds.base = 0x1000

        for byte in dsOverrideBytes {
            if case let VMExit.ioOutOperation(operation) = vmExit {
                XCTAssertEqual(operation.data, VMExit.IOOutOperation.Data.byte(byte))
            } else {
                print("DS:", String(vcpu.registers.ds.selector, radix: 16), String(vcpu.registers.ds.base, radix: 16))
                print("CS:IP \(String(vcpu.registers.cs.base, radix: 16)):\(String(vcpu.registers.rip, radix: 16))")
                XCTFail("Not an OUTS: \(vmExit)")
            }
            vmExit = try vcpu.run()
        }
        #if true
        for byte in esOverrideBytes {
            if case let VMExit.ioOutOperation(operation) = vmExit {
                XCTAssertEqual(operation.data, VMExit.IOOutOperation.Data.byte(byte))
            } else {
                XCTFail("Not an OUTS")
            }
            vmExit = try vcpu.run()
        }

        for byte in fsOverrideBytes {
            if case let VMExit.ioOutOperation(operation) = vmExit {
                XCTAssertEqual(operation.data, VMExit.IOOutOperation.Data.byte(byte))
            } else {
                XCTFail("Not an OUTS")
            }
            vmExit = try vcpu.run()
        }

        for byte in gsOverrideBytes {
            if case let VMExit.ioOutOperation(operation) = vmExit {
                XCTAssertEqual(operation.data, VMExit.IOOutOperation.Data.byte(byte))
            } else {
                XCTFail("Not an OUTS")
            }
            vmExit = try vcpu.run()
        }

        for byte in ssOverrideBytes {
            if case let VMExit.ioOutOperation(operation) = vmExit {
                XCTAssertEqual(operation.data, VMExit.IOOutOperation.Data.byte(byte))
            } else {
                XCTFail("Not an OUTS")
            }
            vmExit = try vcpu.run()
        }


        XCTAssertEqual(vmExit, .hlt)
        #endif

    }
    
    static var allTests = [
        ("testInstructionPrefixes", testInstructionPrefixes),
        //("testBadMemoryRead", testBadMemoryRead),
       // ("testHLT", testHLT),
        ("testOut", testOut),
    ]
}