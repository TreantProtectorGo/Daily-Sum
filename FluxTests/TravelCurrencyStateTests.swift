import XCTest
@testable import Flux

final class TravelCurrencyStateTests: XCTestCase {
    func testManualOverrideWinsOverDetectedCurrency() {
        let state = TravelCurrencyState.resolve(
            defaultCurrencyCode: "USD",
            useLocationDefaults: true,
            detectedCurrencyCode: "KRW",
            manualTravelCurrencyCode: "JPY"
        )

        XCTAssertEqual(state.detectedLocationCurrencyCode, "KRW")
        XCTAssertEqual(state.currentTravelCurrencyCode, "JPY")
    }

    func testMatchingDetectedAndDefaultCurrencyClearsCurrentTravelCurrency() {
        let state = TravelCurrencyState.resolve(
            defaultCurrencyCode: "USD",
            useLocationDefaults: true,
            detectedCurrencyCode: "USD",
            manualTravelCurrencyCode: nil
        )

        XCTAssertEqual(state.detectedLocationCurrencyCode, "USD")
        XCTAssertNil(state.currentTravelCurrencyCode)
    }

    func testDisabledLocationDefaultsKeepsDetectedCurrencyButNoCurrentTravelCurrency() {
        let state = TravelCurrencyState.resolve(
            defaultCurrencyCode: "USD",
            useLocationDefaults: false,
            detectedCurrencyCode: "KRW",
            manualTravelCurrencyCode: nil
        )

        XCTAssertEqual(state.detectedLocationCurrencyCode, "KRW")
        XCTAssertNil(state.currentTravelCurrencyCode)
    }
}
