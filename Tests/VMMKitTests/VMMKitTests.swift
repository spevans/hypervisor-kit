//
//  VMMKitTests.swift
//  VMMKit
//
//  Created by Simon Evans on 08/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import XCTest
import Foundation

@testable import VMMKit


final class VMMKitTests: XCTestCase {

    func testCreateVM() throws {
        let vm = try VirtualMachine(logger: logger)
        _ = try vm.addMemory(at: 0x1000, size: 8192)
        _ = try vm.addMemory(at: 0x4000, size: 4096)
        let vcpu = try vm.createVCPU(startup: { $0.setupRealMode() })
        XCTAssertEqual(vm.memoryRegions.count, 2)
        XCTAssertTrue(vcpu.shutdown())
        XCTAssertNoThrow(try vm.shutdown())
    }

    static var allTests: [(String, (VMMKitTests) -> () throws -> Void)] = [
        ("testCreateVM", testCreateVM),
    ]
}
