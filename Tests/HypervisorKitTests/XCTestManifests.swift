//
//  XCTestManifests.swift
//  HypervisorKit
//
//  Created by Simon Evans on 05/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import XCTest
import Logging

let logger: Logger = {
    LoggingSystem.bootstrap(StreamLogHandler.standardError)
    var logger = Logger(label: "HypervisorKitTests")
    logger.logLevel = .debug
    return logger
}()


#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(HypervisorKitTests.allTests),
        testCase(RealModeTests.allTests),
    ]
}
#endif
