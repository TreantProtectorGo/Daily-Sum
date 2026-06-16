import XCTest
@testable import Flux

@MainActor
final class CloudSyncSettingsStoreTests: XCTestCase {
    func testEnablementChangePostsDidChangeNotification() {
        let defaults = makeIsolatedDefaults()
        let store = CloudSyncSettingsStore(
            userDefaults: defaults,
            availabilityProvider: { .available }
        )

        let expectation = expectation(
            forNotification: CloudSyncSettingsStore.didChangeNotification,
            object: nil
        )

        store.isCloudSyncEnabled = true

        wait(for: [expectation], timeout: 1.0)
    }

    func testStatusReportsEnabledWhenAvailableAndPreferenceEnabled() {
        let defaults = makeIsolatedDefaults()
        let store = CloudSyncSettingsStore(
            userDefaults: defaults,
            availabilityProvider: { .available }
        )

        store.isCloudSyncEnabled = true

        XCTAssertTrue(store.isCloudSyncEnabled)
        XCTAssertEqual(store.status, .enabled)
    }

    func testStatusReportsUnavailableWhenICloudAccountIsMissing() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: CloudSyncSettingsStore.storageKey)
        let store = CloudSyncSettingsStore(
            userDefaults: defaults,
            availabilityProvider: { .unavailable(.iCloudAccountRequired) }
        )

        XCTAssertTrue(store.isCloudSyncEnabled)
        XCTAssertEqual(store.status, .unavailable(.iCloudAccountRequired))
    }

    func testCrossDevicePreferencesRoundTripIndependentlyFromRestoreFlow() {
        let defaults = makeIsolatedDefaults()
        let store = CloudSyncSettingsStore(
            userDefaults: defaults,
            availabilityProvider: { .available }
        )

        let originalCurrencyCode = UserCurrencyPreference.currencyCode
        let originalLanguage = AppLanguagePreference.language
        let originalTravelCurrencyModeEnabled = TravelCurrencyPreference.isEnabled
        let originalTravelCurrencySource = TravelCurrencyPreference.source
        let originalDetectedCurrencyCode = TravelCurrencyPreference.detectedCurrencyCode
        let originalManualCurrencyCode = TravelCurrencyPreference.manualCurrencyCode
        let originalReportsCategoryRowLimit = ReportsCategoryRowLimitPreference.rowLimit

        defer {
            UserCurrencyPreference.currencyCode = originalCurrencyCode
            AppLanguagePreference.language = originalLanguage
            TravelCurrencyPreference.isEnabled = originalTravelCurrencyModeEnabled
            TravelCurrencyPreference.source = originalTravelCurrencySource
            TravelCurrencyPreference.detectedCurrencyCode = originalDetectedCurrencyCode
            TravelCurrencyPreference.manualCurrencyCode = originalManualCurrencyCode
            ReportsCategoryRowLimitPreference.rowLimit = originalReportsCategoryRowLimit
        }

        let preferences = BackupCrossDevicePreferences(
            preferredCurrencyCode: "EUR",
            appLanguage: .traditionalChinese,
            isTravelCurrencyModeEnabled: false,
            travelCurrencySource: .manual,
            detectedTravelCurrencyCode: "JPY",
            manualTravelCurrencyCode: "EUR",
            reportsCategoryRowLimit: 8
        )

        store.applyCrossDevicePreferences(preferences)

        XCTAssertEqual(store.currentCrossDevicePreferences(), preferences)
    }

    func testCrossDevicePreferencesRemainAccessibleWhenCloudUnavailable() {
        let defaults = makeIsolatedDefaults()
        let store = CloudSyncSettingsStore(
            userDefaults: defaults,
            availabilityProvider: { .unavailable(.iCloudAccountRequired) }
        )

        let originalCurrencyCode = UserCurrencyPreference.currencyCode
        let originalLanguage = AppLanguagePreference.language
        let originalTravelCurrencyModeEnabled = TravelCurrencyPreference.isEnabled
        let originalTravelCurrencySource = TravelCurrencyPreference.source
        let originalDetectedCurrencyCode = TravelCurrencyPreference.detectedCurrencyCode
        let originalManualCurrencyCode = TravelCurrencyPreference.manualCurrencyCode
        let originalReportsCategoryRowLimit = ReportsCategoryRowLimitPreference.rowLimit

        defer {
            UserCurrencyPreference.currencyCode = originalCurrencyCode
            AppLanguagePreference.language = originalLanguage
            TravelCurrencyPreference.isEnabled = originalTravelCurrencyModeEnabled
            TravelCurrencyPreference.source = originalTravelCurrencySource
            TravelCurrencyPreference.detectedCurrencyCode = originalDetectedCurrencyCode
            TravelCurrencyPreference.manualCurrencyCode = originalManualCurrencyCode
            ReportsCategoryRowLimitPreference.rowLimit = originalReportsCategoryRowLimit
        }

        let preferences = BackupCrossDevicePreferences(
            preferredCurrencyCode: "EUR",
            appLanguage: .english,
            isTravelCurrencyModeEnabled: false,
            travelCurrencySource: .manual,
            detectedTravelCurrencyCode: "USD",
            manualTravelCurrencyCode: "JPY",
            reportsCategoryRowLimit: 8
        )

        store.applyCrossDevicePreferences(preferences)

        XCTAssertEqual(store.status, .unavailable(.iCloudAccountRequired))
        XCTAssertEqual(store.currentCrossDevicePreferences(), preferences)
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "CloudSyncSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
