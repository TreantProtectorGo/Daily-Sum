import XCTest
@testable import Flux

final class TransactionTravelDefaultsTests: XCTestCase {
    func testMatchingCurrentTravelCurrencyDefaultsToggleOn() {
        let value = TransactionTravelDefaults.resolveIsTravelTransaction(
            transactionType: .expense,
            currentTravelCurrencyCode: "JPY",
            userOverride: nil
        )

        XCTAssertTrue(value)
    }

    func testMissingTravelCurrencyDefaultsToggleOff() {
        let value = TransactionTravelDefaults.resolveIsTravelTransaction(
            transactionType: .expense,
            currentTravelCurrencyCode: nil,
            userOverride: nil
        )

        XCTAssertFalse(value)
    }

    func testUserOverrideWinsOverAutomaticDefault() {
        let value = TransactionTravelDefaults.resolveIsTravelTransaction(
            transactionType: .expense,
            currentTravelCurrencyCode: "JPY",
            userOverride: false
        )

        XCTAssertFalse(value)
    }

    func testIncomeAllowsManualForeignCurrencyOverride() {
        let value = TransactionTravelDefaults.resolveIsTravelTransaction(
            transactionType: .income,
            currentTravelCurrencyCode: "JPY",
            userOverride: true
        )

        XCTAssertTrue(value)
    }

    func testIncomeDoesNotAutomaticallyDefaultToForeignCurrency() {
        let value = TransactionTravelDefaults.resolveIsTravelTransaction(
            transactionType: .income,
            currentTravelCurrencyCode: "JPY",
            userOverride: nil
        )

        XCTAssertFalse(value)
    }
}
