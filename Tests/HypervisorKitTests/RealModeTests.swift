import XCTest
import Foundation

@testable import HypervisorKit


final class RealModeTests: XCTestCase {


    private var _realModeTestCode: Data? = nil
    private func realModeTestCode() throws -> Data {
        if let code = _realModeTestCode {
            return code
        }
        let url = URL(fileURLWithPath: "real_mode_test.bin", isDirectory: false)
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
        vcpu.registers.rflags = 0x2
        vcpu.registers.rsp = 0x0
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


        
    private func runTest(vcpu: VirtualMachine.VCPU, ax: UInt16, skipEPT: Bool = true) throws -> VMXExit {

            print("Running VCPU with ax:", ax)

            vcpu.registers.rax = UInt64(ax)
            vcpu.registers.rip = 0x1000

            var seenEPT = false
            while true {
            
                guard let vmExit = try? vcpu.run() else {
                    XCTFail("VCPU Run failed")
                    throw HVError.vmRunError
            }
            
            print("VMExit Reason:", vmExit.exitReason)            
            
            switch vmExit.exitReason {
                case .eptViolation:
                    // Can happen at startup on macOS
                    if !skipEPT { return vmExit }
                    if seenEPT {
                        XCTFail("Got 2nd EPT violation")
                        throw HVError.vmRunError
                    }
                    seenEPT = true

                default:
                    return vmExit
                }
            }
    }

    func testHLT() throws {
        let vm = try createRealModeVM()
        let memRegion = vm.memoryRegions[0]
        memRegion.rawBuffer.baseAddress!.advanced(by: 0x200).storeBytes(of: 0x1234, as: UInt16.self)
        let vcpu = vm.vcpus[0]
        let vmExit = try runTest(vcpu: vcpu, ax: 0)

        XCTAssertEqual(vmExit.exitReason, .hlt)
        let rax = vcpu.registers.rax //.readRegister(HV_X86_RAX)
        print("RAX:", String(rax, radix: 16))
        XCTAssertEqual(vcpu.registers.rax, 0x1235)        
    }

    func testOut() throws {
        let vm = try createRealModeVM()
        let vcpu = vm.vcpus[0]
        let vmExit = try runTest(vcpu: vcpu, ax: 1)
        XCTAssertEqual(vmExit.exitReason, .ioInstruction)
    }
    
    static var allTests = [
        ("testHLT", testHLT),
        ("testOut", testOut),
    ]
}
