//
//  LinuxMain.swift
//  VMMKit
//
//  Created by Simon Evans on 05/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import XCTest
import VMMKitTests

var tests = [XCTestCaseEntry]()
tests += VMMKitTests.allTests()
XCTMain(tests)
