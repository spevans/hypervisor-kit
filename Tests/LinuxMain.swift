//
//  LinuxMain.swift
//  HypervisorKit
//
//  Created by Simon Evans on 05/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import XCTest
import HypervisorKitTests

var tests = [XCTestCaseEntry]()
tests += HypervisorKitTests.allTests()
XCTMain(tests)
