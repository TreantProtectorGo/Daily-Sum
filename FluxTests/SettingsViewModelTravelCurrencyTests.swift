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
    private var originalTravelCurrencyModeEnabled: Bool?
    private var originalTravelCurrencySource: TravelCurrencySource?
    private var originalDetectedTravelCurrencyCode: String?
    private var originalManualTravelCurrencyCode: String?

    override func setUp() async throws {
        container = try ModelContainerConfiguration.createTestContainer()
        originalTravelCurrencyModeEnabled = UserDefaults.standard.object(
            forKey: TravelCurrencyPreference.modeEnabledStorageKey
        ) as? Bool
        originalTravelCurrencySource = TravelCurrencyPreference.source
        originalDetectedTravelCurrencyCode = TravelCurrencyPreference.detectedCurrencyCode
        originalManualTravelCurrencyCode = TravelCurrencyPreference.manualCurrencyCode
        TravelCurrencyPreference.isEnabled = true
        TravelCurrencyPreference.source = .automatic
        TravelCurrencyPreference.detectedCurrencyCode = nil
        TravelCurrencyPreference.manualCurrencyCode = nil
    }

    override func tearDown() async throws {
        if let originalTravelCurrencyModeEnabled {
            UserDefaults.standard.set(
                originalTravelCurrencyModeEnabled,
                forKey: TravelCurrencyPreference.modeEnabledStorageKey
            )
        } else {
            UserDefaults.standard.removeObject(
                forKey: TravelCurrencyPreference.modeEnabledStorageKey
            )
        }
        TravelCurrencyPreference.source = originalTravelCurrencySource ?? .automatic
        TravelCurrencyPreference.detectedCurrencyCode = originalDetectedTravelCurrencyCode
        TravelCurrencyPreference.manualCurrencyCode = originalManualTravelCurrencyCode
        originalTravelCurrencyModeEnabled = nil
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

    func testRequestTravelCurrencyLocationUpdateDoesNothingWhenModeDisabled() async throws {
        TravelCurrencyPreference.isEnabled = false
        TravelCurrencyPreference.detectedCurrencyCode = "JPY"
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

        XCTAssertEqual(locationService.requestAuthorizationCallCount, 0)
        XCTAssertEqual(locationService.detectLocalCurrencyCallCount, 0)
        XCTAssertEqual(viewModel.detectedLocationCurrencyCode, "JPY")
        XCTAssertNil(viewModel.currentTravelCurrencyCode)
    }

    func testDisabledTravelCurrencyModeKeepsCurrentCurrencyInactive() async throws {
        TravelCurrencyPreference.isEnabled = false
        TravelCurrencyPreference.source = .automatic
        TravelCurrencyPreference.detectedCurrencyCode = "JPY"
        let locationService = MockLocationService(
            authorizationStatusValue: .authorized,
            requestAuthorizationResult: .authorized,
            detectedCurrency: .CNY
        )

        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            travelCurrencyLocationService: locationService
        )
        await viewModel.loadSettings()

        XCTAssertFalse(viewModel.isTravelCurrencyModeEnabled)
        XCTAssertEqual(locationService.detectLocalCurrencyCallCount, 0)
        XCTAssertNil(viewModel.currentTravelCurrencyCode)
        XCTAssertEqual(viewModel.travelCurrencySettingSummary, "Inactive")
    }

    func testReenablingTravelCurrencyModeRefreshesDetectedCurrency() async throws {
        TravelCurrencyPreference.isEnabled = false
        TravelCurrencyPreference.source = .automatic
        TravelCurrencyPreference.detectedCurrencyCode = nil
        let locationService = MockLocationService(
            authorizationStatusValue: .authorized,
            requestAuthorizationResult: .authorized,
            detectedCurrency: .CNY
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            travelCurrencyLocationService: locationService
        )

        await viewModel.setTravelCurrencyModeEnabled(true)

        XCTAssertTrue(viewModel.isTravelCurrencyModeEnabled)
        XCTAssertEqual(locationService.detectLocalCurrencyCallCount, 1)
        XCTAssertEqual(viewModel.detectedLocationCurrencyCode, "CNY")
    }
}
