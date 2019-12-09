import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(HypervisorKitTests.allTests),
        testCase(RealModeTests.allTests),
    ]
}
#endif
