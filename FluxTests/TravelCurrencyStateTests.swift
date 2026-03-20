import XCTest
@testable import Flux

final class TravelCurrencyStateTests: XCTestCase {
    func testManualSourceWithoutManualCurrencyStaysInactive() {
        let state = TravelCurrencyState.resolve(
            defaultCurrencyCode: "USD",
            source: .manual,
            detectedCurrencyCode: "KRW",
            manualTravelCurrencyCode: nil
        )

        XCTAssertEqual(state.detectedLocationCurrencyCode, "KRW")
        XCTAssertNil(state.currentTravelCurrencyCode)
    }

    func testManualSelectionSeedKeepsCurrentTravelCurrencyOnly() {
        XCTAssertNil(
            TravelCurrencyManualSelection.seededManualCurrencyCode(
                currentTravelCurrencyCode: nil
            )
        )
        XCTAssertEqual(
            TravelCurrencyManualSelection.seededManualCurrencyCode(
                currentTravelCurrencyCode: "jpy"
            ),
            "JPY"
        )
    }

    func testManualSelectionOptionsExcludeDefaultCurrency() {
        let currencies = TravelCurrencyManualSelection.availableCurrencies(
            defaultCurrencyCode: "USD"
        )

        XCTAssertFalse(currencies.contains(SupportedCurrency.USD))
        XCTAssertTrue(currencies.contains(SupportedCurrency.JPY))
    }

    func testManualOverrideWinsOverDetectedCurrency() {
        let state = TravelCurrencyState.resolve(
            defaultCurrencyCode: "USD",
            source: .automatic,
            detectedCurrencyCode: "KRW",
            manualTravelCurrencyCode: "JPY"
        )

        XCTAssertEqual(state.detectedLocationCurrencyCode, "KRW")
        XCTAssertEqual(state.currentTravelCurrencyCode, "JPY")
    }

    func testMatchingDetectedAndDefaultCurrencyClearsCurrentTravelCurrency() {
        let state = TravelCurrencyState.resolve(
            defaultCurrencyCode: "USD",
            source: .automatic,
            detectedCurrencyCode: "USD",
            manualTravelCurrencyCode: nil
        )

        XCTAssertEqual(state.detectedLocationCurrencyCode, "USD")
        XCTAssertNil(state.currentTravelCurrencyCode)
    }

    func testManualSourceKeepsDetectedCurrencyButUsesManualCurrentTravelCurrency() {
        let state = TravelCurrencyState.resolve(
            defaultCurrencyCode: "USD",
            source: .manual,
            detectedCurrencyCode: "KRW",
            manualTravelCurrencyCode: "JPY"
        )

        XCTAssertEqual(state.detectedLocationCurrencyCode, "KRW")
        XCTAssertEqual(state.currentTravelCurrencyCode, "JPY")
    }
}
