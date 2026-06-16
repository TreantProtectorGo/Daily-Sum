import Foundation

struct BackupPreferences: Codable, Equatable {
    var crossDevice: BackupCrossDevicePreferences
    var deviceLocal: BackupDeviceLocalPreferences
}

struct BackupCrossDevicePreferences: Codable, Equatable {
    var preferredCurrencyCode: String
    var appLanguage: AppLanguage
    var isTravelCurrencyModeEnabled: Bool?
    var travelCurrencySource: TravelCurrencySource
    var detectedTravelCurrencyCode: String?
    var manualTravelCurrencyCode: String?
    var reportsCategoryRowLimit: Int
}

struct BackupDeviceLocalPreferences: Codable, Equatable {
    var defaultTransactionAccountId: UUID?
    var rememberLastUsedTransactionAccount: Bool
    var lastUsedTransactionAccountId: UUID?
    var autoPresentAccountAfterCategorySelection: Bool
}
