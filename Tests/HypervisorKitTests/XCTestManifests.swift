import XCTest
import Logging

let logger: Logger = {
    LoggingSystem.bootstrap(StreamLogHandler.standardError)
    var logger = Logger(label: "HypervisorKitTests")
    logger.logLevel = .trace
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
