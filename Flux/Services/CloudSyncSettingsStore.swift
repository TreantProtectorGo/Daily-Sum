import Foundation

enum CloudSyncUnavailableReason: String, Equatable {
    case iCloudAccountRequired
}

enum CloudSyncAvailability: Equatable {
    case available
    case unavailable(CloudSyncUnavailableReason)
}

enum CloudSyncStatus: Equatable {
    case enabled
    case disabled
    case unavailable(CloudSyncUnavailableReason)
}

@MainActor
protocol CloudSyncSettingsStoring {
    var isCloudSyncEnabled: Bool { get set }
    var status: CloudSyncStatus { get }

    func currentCrossDevicePreferences() -> BackupCrossDevicePreferences
    func applyCrossDevicePreferences(_ preferences: BackupCrossDevicePreferences)
}

@MainActor
final class CloudSyncSettingsStore: CloudSyncSettingsStoring {
    static let storageKey = "flux.cloudSyncEnabled"
    static let didChangeNotification = Notification.Name("flux.cloudSyncSettingsDidChange")

    private let userDefaults: UserDefaults
    private let availabilityProvider: () -> CloudSyncAvailability

    init(
        userDefaults: UserDefaults = .standard,
        availabilityProvider: @escaping () -> CloudSyncAvailability = {
            if let override = RuntimeEnvironment.cloudSyncAvailabilityOverride {
                return override
            }
            return FileManager.default.ubiquityIdentityToken == nil
                ? CloudSyncAvailability.unavailable(.iCloudAccountRequired)
                : CloudSyncAvailability.available
        }
    ) {
        self.userDefaults = userDefaults
        self.availabilityProvider = availabilityProvider
    }

    var isCloudSyncEnabled: Bool {
        get { userDefaults.bool(forKey: Self.storageKey) }
        set {
            let previousValue = userDefaults.bool(forKey: Self.storageKey)
            guard previousValue != newValue else { return }

            userDefaults.set(newValue, forKey: Self.storageKey)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    var status: CloudSyncStatus {
        switch availabilityProvider() {
        case .available:
            return isCloudSyncEnabled ? .enabled : .disabled
        case let .unavailable(reason):
            return .unavailable(reason)
        }
    }

    func currentCrossDevicePreferences() -> BackupCrossDevicePreferences {
        BackupCrossDevicePreferences(
            preferredCurrencyCode: UserCurrencyPreference.currencyCode,
            appLanguage: AppLanguagePreference.language,
            isTravelCurrencyModeEnabled: TravelCurrencyPreference.isEnabled,
            travelCurrencySource: TravelCurrencyPreference.source,
            detectedTravelCurrencyCode: TravelCurrencyPreference.detectedCurrencyCode,
            manualTravelCurrencyCode: TravelCurrencyPreference.manualCurrencyCode,
            reportsCategoryRowLimit: ReportsCategoryRowLimitPreference.rowLimit
        )
    }

    func applyCrossDevicePreferences(_ preferences: BackupCrossDevicePreferences) {
        UserCurrencyPreference.currencyCode = preferences.preferredCurrencyCode
        AppLanguagePreference.language = preferences.appLanguage
        TravelCurrencyPreference.isEnabled = preferences.isTravelCurrencyModeEnabled ?? true
        TravelCurrencyPreference.source = preferences.travelCurrencySource
        TravelCurrencyPreference.detectedCurrencyCode = preferences.detectedTravelCurrencyCode
        TravelCurrencyPreference.manualCurrencyCode = preferences.manualTravelCurrencyCode
        ReportsCategoryRowLimitPreference.rowLimit = preferences.reportsCategoryRowLimit
    }
}
