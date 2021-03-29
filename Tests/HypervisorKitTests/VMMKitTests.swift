//
//  HypervisorKitTests.swift
//  HypervisorKit
//
//  Created by Simon Evans on 08/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import XCTest
import Foundation

@testable import HypervisorKit


final class HypervisorKitTests: XCTestCase {

    func testCreateVM() throws {
        let vm: VirtualMachine
        do {
            vm = try VirtualMachine(logger: logger)
        } catch {
            XCTFail("Failed to create VM: \(error)")
            return
        }
        XCTAssertNoThrow(try vm.addMemory(at: 0x1000, size: 8192))
        XCTAssertNoThrow(try vm.addMemory(at: 0x4000, size: 4096))
        let vcpu = try vm.addVCPU()
        XCTAssertEqual(vm.memoryRegions.count, 2)
        XCTAssertTrue(vcpu.shutdown())
        XCTAssertNoThrow(try vm.shutdown())
    }

    static var allTests: [(String, (HypervisorKitTests) -> () throws -> Void)] = [
        ("testCreateVM", testCreateVM),
    ]
}
