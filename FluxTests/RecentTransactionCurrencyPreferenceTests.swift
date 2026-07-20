import XCTest
@testable import Flux

final class RecentTransactionCurrencyPreferenceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "RecentTransactionCurrencyPreferenceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRecordingCurrencyMovesItToFrontWithoutDuplicates() {
        RecentTransactionCurrencyPreference.record("USD", defaults: defaults)
        RecentTransactionCurrencyPreference.record("JPY", defaults: defaults)
        RecentTransactionCurrencyPreference.record("usd", defaults: defaults)

        XCTAssertEqual(
            RecentTransactionCurrencyPreference.currencyCodes(defaults: defaults),
            ["USD", "JPY"]
        )
    }

    func testRecentCurrenciesAreLimitedToThreeSupportedCodes() {
        RecentTransactionCurrencyPreference.record("USD", defaults: defaults)
        RecentTransactionCurrencyPreference.record("JPY", defaults: defaults)
        RecentTransactionCurrencyPreference.record("EUR", defaults: defaults)
        RecentTransactionCurrencyPreference.record("GBP", defaults: defaults)
        RecentTransactionCurrencyPreference.record("INVALID", defaults: defaults)

        XCTAssertEqual(
            RecentTransactionCurrencyPreference.currencyCodes(defaults: defaults),
            ["GBP", "EUR", "JPY"]
        )
    }

    func testReadingStoredValuesNormalizesAndRemovesDuplicates() {
        defaults.set(
            ["usd", "USD", "JPY", "invalid", "EUR", "GBP"],
            forKey: RecentTransactionCurrencyPreference.storageKey
        )

        XCTAssertEqual(
            RecentTransactionCurrencyPreference.currencyCodes(defaults: defaults),
            ["USD", "JPY", "EUR"]
        )
    }
}
