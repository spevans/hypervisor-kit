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
        
        _ = try vm.addMemory(at: 0x1000, size: 8192)
        _ = try vm.addMemory(at: 0x4000, size: 4096)
        XCTAssertEqual(vm.memoryRegions.count, 2)
    }
    
    static var allTests = [
        ("testCreateVM", testCreateVM),
    ]
}
