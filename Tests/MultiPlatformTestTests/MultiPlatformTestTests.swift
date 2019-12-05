import XCTest
@testable import MultiPlatformTest

final class MultiPlatformTestTests: XCTestCase {





    func testExample() throws {

        let vm = VirtualMachine()
        /*guard  else {
         XCTFail("Cant create VM")
         return
         }*/

        guard let memRegion = vm.addMemory(at: 0, size: 8192) else {
            XCTFail("Cant add memory region")
            return
        }


        let realModeTest: [UInt8] = [  0xa1, 0x00,  0x02,  0x40, 0xf4  ]
        
        memRegion.rawBuffer.baseAddress!.copyMemory(from: realModeTest, byteCount: realModeTest.count)
        memRegion.rawBuffer.baseAddress!.advanced(by: 0x200).storeBytes(of: 0x1234, as: UInt16.self)


        guard var vcpu = try?  vm.createVCPU() else {
            XCTFail("Cant create VCPU")
            return
        }

        vcpu.registers.rip = 0
        vcpu.registers.rflags = 0x2
        vcpu.registers.rsp = 0x0

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


        print("Running VCPU")
        var finished = false
        while !finished {

            let vmExitReason = try vcpu.run()
            let exitQualification = vcpu.vmcs.exitQualification // try rvmcs(vcpuId, 0x00006400)

            print("VMExit Reason:", vmExitReason.exitReason, "qualification:", String(exitQualification!, radix: 16))


            if vmExitReason.exitReason == .eptViolation {  // EPT
                continue
            }

            if vmExitReason.exitReason ==  .hlt {
                print("Got HLT")
                let rax = vcpu.registers.rax //.readRegister(HV_X86_RAX)
                print("RAX:", String(rax, radix: 16))
                XCTAssertEqual(vcpu.registers.rax, 0x1235)
                finished = true
                break
            }

            XCTFail("Unknown exit reason: \(vmExitReason.exitReason)")
            finished = true
            break
        }
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
