import XCTest
@testable import Flux

final class TravelTransactionSnapshotTests: XCTestCase {
    private struct MockQuoteProvider: CurrencyQuoteProviding {
        let convertedAmount: Decimal
        let rate: Decimal
        let effectiveDate: Date
        let provider: String

        func convertWithQuote(
            _ amount: Decimal,
            from sourceCurrencyCode: String,
            to targetCurrencyCode: String,
            on date: Date,
            mode: ConversionMode
        ) async throws -> CurrencyConversionQuote {
            CurrencyConversionQuote(
                convertedAmount: convertedAmount,
                rate: rate,
                effectiveDate: effectiveDate,
                provider: provider
            )
        }
    }

    func testBuildSnapshotStoresTravelToAccountRateDirection() async throws {
        let snapshot = try await TravelTransactionSnapshots.buildSnapshot(
            travelAmount: 3000,
            travelCurrencyCode: "JPY",
            accountCurrencyCode: "HKD",
            date: .now,
            conversionService: MockQuoteProvider(
                convertedAmount: 156.3,
                rate: 0.0521,
                effectiveDate: .now,
                provider: "mock"
            )
        )

        XCTAssertEqual(snapshot.travelAmount, 3000)
        XCTAssertEqual(snapshot.travelCurrencyCode, "JPY")
        XCTAssertEqual(snapshot.accountAmount, 156.3)
        XCTAssertEqual(snapshot.accountCurrencyCode, "HKD")
        XCTAssertEqual(snapshot.exchangeRate, 0.0521)
    }

    func testBuildSnapshotUsesIdentityRateWhenTravelAndAccountCurrenciesMatch() async throws {
        let date = Date()

        let snapshot = try await TravelTransactionSnapshots.buildSnapshot(
            travelAmount: 88.88,
            travelCurrencyCode: "CNY",
            accountCurrencyCode: "CNY",
            date: date,
            conversionService: MockQuoteProvider(
                convertedAmount: 0,
                rate: 0,
                effectiveDate: .distantPast,
                provider: "unused"
            )
        )

        XCTAssertEqual(snapshot.travelAmount, 88.88)
        XCTAssertEqual(snapshot.travelCurrencyCode, "CNY")
        XCTAssertEqual(snapshot.accountAmount, 88.88)
        XCTAssertEqual(snapshot.accountCurrencyCode, "CNY")
        XCTAssertEqual(snapshot.exchangeRate, 1)
        XCTAssertEqual(snapshot.effectiveDate, date)
        XCTAssertEqual(snapshot.provider, "identity")
    }

    func testChangingInputCurrencyUsesCurrentEditedAccountValue() async throws {
        let convertedAmount = try await
            TravelTransactionCurrencyChange.convertInputAmountPreservingAccountValue(
                currentInputAmount: 150,
                previousInputCurrencyCode: nil,
                nextInputCurrencyCode: "JPY",
                accountCurrencyCode: "HKD",
                date: .now,
                conversionService: MockQuoteProvider(
                    convertedAmount: 3_000,
                    rate: 20,
                    effectiveDate: .now,
                    provider: "mock"
                )
            )

        XCTAssertEqual(convertedAmount, 3_000)
    }

    func testClearingInputCurrencyWithoutFallbackTargetsAccountCurrency() {
        let selection = TravelTransactionCurrencySelection.resolve(
            selectedCurrencyCode: nil,
            fallbackInputCurrencyCode: nil,
            accountCurrencyCode: "hkd"
        )

        XCTAssertNil(selection.inputCurrencyCode)
        XCTAssertEqual(selection.conversionCurrencyCode, "HKD")
    }

    func testClearingInputCurrencyUsesAutomaticFallbackWhenAvailable() {
        let selection = TravelTransactionCurrencySelection.resolve(
            selectedCurrencyCode: nil,
            fallbackInputCurrencyCode: "usd",
            accountCurrencyCode: "HKD"
        )

        XCTAssertEqual(selection.inputCurrencyCode, "USD")
        XCTAssertEqual(selection.conversionCurrencyCode, "USD")
    }

    func testRecomputeLockedSnapshotUsesStoredRate() {
        let snapshot = TravelTransactionSnapshot(
            travelAmount: 3000,
            travelCurrencyCode: "JPY",
            accountAmount: 156.3,
            accountCurrencyCode: "HKD",
            exchangeRate: 0.0521,
            effectiveDate: .now,
            provider: "mock"
        )

        let recomputed = TravelTransactionSnapshots.recomputeLockedSnapshot(
            existingSnapshot: snapshot,
            updatedTravelAmount: 1200
        )

        XCTAssertEqual(recomputed.travelAmount, 1200)
        XCTAssertEqual(recomputed.accountAmount, 62.52)
        XCTAssertEqual(recomputed.exchangeRate, snapshot.exchangeRate)
    }

    func testApplySnapshotAndClearSnapshotMaintainInvariant() {
        let transaction = Transaction(
            amount: 0,
            currencyCode: "HKD",
            type: .expense,
            account: Account(name: "Card", type: .creditCard, currencyCode: "HKD")
        )
        let snapshot = TravelTransactionSnapshot(
            travelAmount: 3000,
            travelCurrencyCode: "JPY",
            accountAmount: 156.3,
            accountCurrencyCode: "HKD",
            exchangeRate: 0.0521,
            effectiveDate: .now,
            provider: "mock"
        )

        TravelTransactionSnapshots.apply(snapshot, to: transaction)
        XCTAssertTrue(TravelTransactionSnapshots.isValidSnapshotState(for: transaction))
        XCTAssertEqual(transaction.travelCurrencyCode, "JPY")
        XCTAssertEqual(transaction.amount, 156.3)

        TravelTransactionSnapshots.apply(nil, to: transaction)
        XCTAssertTrue(TravelTransactionSnapshots.isValidSnapshotState(for: transaction))
        XCTAssertNil(transaction.travelAmount)
        XCTAssertNil(transaction.travelCurrencyCode)
        XCTAssertFalse(transaction.isTravelTransaction ?? true)
    }
}
