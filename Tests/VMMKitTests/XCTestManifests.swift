import XCTest
import Logging

let logger: Logger = {
    LoggingSystem.bootstrap(StreamLogHandler.standardError)
    var logger = Logger(label: "VMMKitTests")
    logger.logLevel = .debug
    return logger
}()


#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(VMMKitTests.allTests),
        testCase(RealModeTests.allTests),
    ]
}
#endif
