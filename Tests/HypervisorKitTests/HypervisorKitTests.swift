import XCTest
import Foundation

enum TestError: Error {
case vmCreateFail
case vcpuCreateFail
case addMemoryFail
}

@testable import HypervisorKit


final class HypervisorKitTests: XCTestCase {


    func testCreateVM() throws {
        guard let vm = try? VirtualMachine() else {
            XCTFail("Cant create VM")
            throw TestError.vmCreateFail
        }
        
        guard let _ = vm.addMemory(at: 0x1000, size: 8192) else {
            throw TestError.addMemoryFail
        }
        
        guard let _ = vm.addMemory(at: 0x4000, size: 4096) else {
            throw TestError.addMemoryFail
        }
        XCTAssertEqual(vm.memoryRegions.count, 2)
    }
    
    static var allTests = [
        ("testCreateVM", testCreateVM),
    ]
}
