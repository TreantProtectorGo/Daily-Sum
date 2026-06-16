import XCTest
@testable import Flux

@MainActor
final class TravelCurrencyPreferenceRefresherTests: XCTestCase {
    private final class MockLocationService: TravelCurrencyLocationServicing {
        var authorizationStatusValue: TravelLocationAuthorizationStatus
        var detectedCurrency: SupportedCurrency?
        private(set) var detectLocalCurrencyCallCount = 0

        init(
            authorizationStatusValue: TravelLocationAuthorizationStatus,
            detectedCurrency: SupportedCurrency?
        ) {
            self.authorizationStatusValue = authorizationStatusValue
            self.detectedCurrency = detectedCurrency
        }

        func authorizationStatus() -> TravelLocationAuthorizationStatus {
            authorizationStatusValue
        }

        func requestAuthorizationIfNeeded() async -> TravelLocationAuthorizationStatus {
            authorizationStatusValue
        }

        func detectLocalCurrency() async -> SupportedCurrency? {
            detectLocalCurrencyCallCount += 1
            return detectedCurrency
        }
    }

    private var originalTravelCurrencyModeEnabled: Bool?
    private var originalDetectedTravelCurrencyCode: String?

    override func setUp() async throws {
        originalTravelCurrencyModeEnabled = TravelCurrencyPreference.isEnabled
        originalDetectedTravelCurrencyCode = TravelCurrencyPreference.detectedCurrencyCode
        TravelCurrencyPreference.isEnabled = true
        TravelCurrencyPreference.detectedCurrencyCode = nil
    }

    override func tearDown() async throws {
        TravelCurrencyPreference.isEnabled = originalTravelCurrencyModeEnabled ?? true
        TravelCurrencyPreference.detectedCurrencyCode = originalDetectedTravelCurrencyCode
        originalTravelCurrencyModeEnabled = nil
        originalDetectedTravelCurrencyCode = nil
    }

    func testRefreshUpdatesDetectedCurrencyWhenLocationIsAuthorized() async {
        let locationService = MockLocationService(
            authorizationStatusValue: .authorized,
            detectedCurrency: .HKD
        )
        let refresher = TravelCurrencyPreferenceRefresher(locationService: locationService)

        await refresher.refreshDetectedTravelCurrency()

        XCTAssertEqual(TravelCurrencyPreference.detectedCurrencyCode, "HKD")
        XCTAssertEqual(locationService.detectLocalCurrencyCallCount, 1)
    }

    func testRefreshKeepsExistingDetectedCurrencyWhenLocationIsNotAuthorized() async {
        TravelCurrencyPreference.detectedCurrencyCode = "CNY"
        let locationService = MockLocationService(
            authorizationStatusValue: .denied,
            detectedCurrency: .HKD
        )
        let refresher = TravelCurrencyPreferenceRefresher(locationService: locationService)

        await refresher.refreshDetectedTravelCurrency()

        XCTAssertEqual(TravelCurrencyPreference.detectedCurrencyCode, "CNY")
        XCTAssertEqual(locationService.detectLocalCurrencyCallCount, 0)
    }

    func testRefreshDoesNotUpdateDetectedCurrencyWhenModeIsDisabled() async {
        TravelCurrencyPreference.isEnabled = false
        TravelCurrencyPreference.detectedCurrencyCode = "CNY"
        let locationService = MockLocationService(
            authorizationStatusValue: .authorized,
            detectedCurrency: .HKD
        )
        let refresher = TravelCurrencyPreferenceRefresher(locationService: locationService)

        await refresher.refreshDetectedTravelCurrency()

        XCTAssertEqual(TravelCurrencyPreference.detectedCurrencyCode, "CNY")
        XCTAssertEqual(locationService.detectLocalCurrencyCallCount, 0)
    }
}
