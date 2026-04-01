import Foundation

enum RuntimeEnvironment {
    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment["XCInjectBundleInto"] != nil { return true }
        if environment["XCTestBundlePath"] != nil { return true }
        return NSClassFromString("XCTestCase") != nil
    }
}
