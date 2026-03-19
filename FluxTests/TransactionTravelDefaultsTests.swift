import XCTest
@testable import Flux

final class TransactionTravelDefaultsTests: XCTestCase {
    func testMatchingCurrentTravelCurrencyDefaultsToggleOn() {
        let value = TransactionTravelDefaults.resolveIsTravelTransaction(
            transactionType: .expense,
            accountCurrencyCode: "JPY",
            currentTravelCurrencyCode: "JPY",
            userOverride: nil
        )

        XCTAssertTrue(value)
    }

    func testDifferentCurrencyDefaultsToggleOff() {
        let value = TransactionTravelDefaults.resolveIsTravelTransaction(
            transactionType: .expense,
            accountCurrencyCode: "USD",
            currentTravelCurrencyCode: "JPY",
            userOverride: nil
        )

        XCTAssertFalse(value)
    }

    func testUserOverrideWinsOverAutomaticDefault() {
        let value = TransactionTravelDefaults.resolveIsTravelTransaction(
            transactionType: .expense,
            accountCurrencyCode: "JPY",
            currentTravelCurrencyCode: "JPY",
            userOverride: false
        )

        XCTAssertFalse(value)
    }

    func testIncomeNeverDefaultsToTravelTransaction() {
        let value = TransactionTravelDefaults.resolveIsTravelTransaction(
            transactionType: .income,
            accountCurrencyCode: "JPY",
            currentTravelCurrencyCode: "JPY",
            userOverride: true
        )

        XCTAssertFalse(value)
    }
}
