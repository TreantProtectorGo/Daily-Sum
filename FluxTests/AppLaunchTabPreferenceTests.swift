import XCTest
@testable import Flux

final class AppLaunchTabPreferenceTests: XCTestCase {
    private var originalValue: String?

    override func setUpWithError() throws {
        originalValue = UserDefaults.standard.string(
            forKey: AppLaunchTabPreference.storageKey
        )
        UserDefaults.standard.removeObject(forKey: AppLaunchTabPreference.storageKey)
    }

    override func tearDownWithError() throws {
        if let originalValue {
            UserDefaults.standard.set(
                originalValue,
                forKey: AppLaunchTabPreference.storageKey
            )
        } else {
            UserDefaults.standard.removeObject(forKey: AppLaunchTabPreference.storageKey)
        }
        originalValue = nil
    }

    func testDefaultsToDashboard() {
        XCTAssertEqual(AppLaunchTabPreference.defaultTab, .dashboard)
    }

    func testPersistsTransactionsAsDefaultTab() {
        AppLaunchTabPreference.defaultTab = .transactions

        XCTAssertEqual(AppLaunchTabPreference.defaultTab, .transactions)
    }

    func testInitialSelectedTabUsesDefaultLaunchTab() {
        AppLaunchTabPreference.defaultTab = .transactions

        XCTAssertEqual(AppLaunchTabPreference.initialSelectedTab, .transactions)
    }

    func testFallsBackToDashboardForUnsupportedStoredValue() {
        UserDefaults.standard.set("search", forKey: AppLaunchTabPreference.storageKey)

        XCTAssertEqual(AppLaunchTabPreference.defaultTab, .dashboard)
    }

    func testSupportedDefaultTabsExcludeSearch() {
        XCTAssertEqual(
            AppLaunchTabPreference.supportedTabs,
            [.dashboard, .transactions, .reports, .budgets]
        )
    }
}
