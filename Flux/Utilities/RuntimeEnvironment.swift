import Foundation

enum RuntimeEnvironment {
    nonisolated private static let cloudSyncAvailabilityFlag = "-FluxCloudSyncAvailability"
    nonisolated private static let uiTestFixtureFlag = "-FluxUITestFixture"

    nonisolated static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment["XCInjectBundleInto"] != nil { return true }
        if environment["XCTestBundlePath"] != nil { return true }
        return NSClassFromString("XCTestCase") != nil
    }

    nonisolated static var cloudSyncAvailabilityOverride: CloudSyncAvailability? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: cloudSyncAvailabilityFlag),
              arguments.indices.contains(arguments.index(after: flagIndex)) else {
            return nil
        }

        switch arguments[arguments.index(after: flagIndex)] {
        case "available":
            return CloudSyncAvailability.available
        case "noAccount":
            return CloudSyncAvailability.unavailable(.iCloudAccountRequired)
        default:
            return nil
        }
    }

    nonisolated static var uiTestFixtureName: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: uiTestFixtureFlag),
              arguments.indices.contains(arguments.index(after: flagIndex)) else {
            return nil
        }

        return arguments[arguments.index(after: flagIndex)]
    }
}
