import XCTest
import SwiftData
@testable import Flux

@MainActor
final class SettingsViewModelTravelCurrencyTests: XCTestCase {
    private final class MockLocationService: TravelCurrencyLocationServicing {
        var authorizationStatusValue: TravelLocationAuthorizationStatus
        var requestAuthorizationResult: TravelLocationAuthorizationStatus
        var detectedCurrency: SupportedCurrency?
        private(set) var requestAuthorizationCallCount = 0
        private(set) var detectLocalCurrencyCallCount = 0

        init(
            authorizationStatusValue: TravelLocationAuthorizationStatus,
            requestAuthorizationResult: TravelLocationAuthorizationStatus,
            detectedCurrency: SupportedCurrency?
        ) {
            self.authorizationStatusValue = authorizationStatusValue
            self.requestAuthorizationResult = requestAuthorizationResult
            self.detectedCurrency = detectedCurrency
        }

        func authorizationStatus() -> TravelLocationAuthorizationStatus {
            authorizationStatusValue
        }

        func requestAuthorizationIfNeeded() async -> TravelLocationAuthorizationStatus {
            requestAuthorizationCallCount += 1
            authorizationStatusValue = requestAuthorizationResult
            return requestAuthorizationResult
        }

        func detectLocalCurrency() async -> SupportedCurrency? {
            detectLocalCurrencyCallCount += 1
            return detectedCurrency
        }
    }

    private var container: ModelContainer!
    private var originalTravelCurrencySource: TravelCurrencySource?
    private var originalDetectedTravelCurrencyCode: String?
    private var originalManualTravelCurrencyCode: String?

    override func setUp() async throws {
        container = try ModelContainerConfiguration.createTestContainer()
        originalTravelCurrencySource = TravelCurrencyPreference.source
        originalDetectedTravelCurrencyCode = TravelCurrencyPreference.detectedCurrencyCode
        originalManualTravelCurrencyCode = TravelCurrencyPreference.manualCurrencyCode
        TravelCurrencyPreference.source = .automatic
        TravelCurrencyPreference.detectedCurrencyCode = nil
        TravelCurrencyPreference.manualCurrencyCode = nil
    }

    override func tearDown() async throws {
        TravelCurrencyPreference.source = originalTravelCurrencySource ?? .automatic
        TravelCurrencyPreference.detectedCurrencyCode = originalDetectedTravelCurrencyCode
        TravelCurrencyPreference.manualCurrencyCode = originalManualTravelCurrencyCode
        originalTravelCurrencySource = nil
        originalDetectedTravelCurrencyCode = nil
        originalManualTravelCurrencyCode = nil
        container = nil
    }

    func testLoadingSettingsDoesNotRequestLocationPermissionWhenAutomaticIsAlreadySelected() async throws {
        let locationService = MockLocationService(
            authorizationStatusValue: .notDetermined,
            requestAuthorizationResult: .authorized,
            detectedCurrency: .HKD
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            travelCurrencyLocationService: locationService
        )

        await viewModel.loadSettings()

        XCTAssertEqual(locationService.requestAuthorizationCallCount, 0)
        XCTAssertEqual(locationService.detectLocalCurrencyCallCount, 0)
        XCTAssertNil(viewModel.detectedLocationCurrencyCode)
    }

    func testRequestTravelCurrencyLocationUpdateRequestsPermissionAndRefreshesDetectedCurrency() async throws {
        let locationService = MockLocationService(
            authorizationStatusValue: .notDetermined,
            requestAuthorizationResult: .authorized,
            detectedCurrency: .CNY
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            travelCurrencyLocationService: locationService
        )

        await viewModel.requestTravelCurrencyLocationUpdate()

        XCTAssertEqual(locationService.requestAuthorizationCallCount, 1)
        XCTAssertEqual(locationService.detectLocalCurrencyCallCount, 1)
        XCTAssertEqual(viewModel.detectedLocationCurrencyCode, "CNY")
    }
}
