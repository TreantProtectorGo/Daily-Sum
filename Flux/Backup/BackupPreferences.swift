import Foundation

struct BackupPreferences: Codable, Equatable {
    var crossDevice: BackupCrossDevicePreferences
    var deviceLocal: BackupDeviceLocalPreferences
}

struct BackupCrossDevicePreferences: Codable, Equatable {
    var preferredCurrencyCode: String
    var appLanguageCode: String
    var travelCurrencySource: String
    var detectedTravelCurrencyCode: String?
    var manualTravelCurrencyCode: String?
    var reportsCategoryRowLimit: Int
    var showUpcomingScheduledTransactions: Bool
}

struct BackupDeviceLocalPreferences: Codable, Equatable {
    var defaultTransactionAccountId: UUID?
    var rememberLastUsedTransactionAccount: Bool
    var lastUsedTransactionAccountId: UUID?
    var autoPresentAccountAfterCategorySelection: Bool
}
