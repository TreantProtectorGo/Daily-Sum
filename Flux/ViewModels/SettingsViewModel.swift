import Foundation
import SwiftUI
import SwiftData
import UserNotifications

// MARK: - User Currency Preference (Persisted)

/// Key for storing user's preferred currency in UserDefaults
private let kDefaultCurrencyCode = "flux.defaultCurrencyCode"
private let kDefaultTransactionAccountId = "flux.defaultTransactionAccountId"
private let kRememberLastUsedTransactionAccount = "flux.rememberLastUsedTransactionAccount"
private let kLastUsedTransactionAccountId = "flux.lastUsedTransactionAccountId"
private let kAutoPresentAccountAfterCategorySelection = "flux.autoPresentAccountAfterCategorySelection"
private let kLastSuccessfulRateSyncDate = "flux.lastSuccessfulRateSyncDate"
private let kLastFailedRateSyncAttemptDate = "flux.lastFailedRateSyncAttemptDate"
private let kTravelCurrencySource = "flux.travelCurrencySource"
private let kTravelCurrencyModeEnabled = "flux.travelCurrencyModeEnabled"
private let kDetectedTravelCurrencyCode = "flux.detectedTravelCurrencyCode"
private let kManualTravelCurrencyCode = "flux.manualTravelCurrencyCode"
private let kReportsCategoryRowLimit = "flux.reports.categoryRowLimit"

/// Global accessor for user's preferred currency code
/// Use this in views that need the default currency without SettingsViewModel
enum UserCurrencyPreference {
    static let storageKey = kDefaultCurrencyCode

    static var currencyCode: String {
        get {
            UserDefaults.standard.string(forKey: storageKey)
                ?? SupportedCurrency.defaultFromLocale.rawValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }

    static var resolvedCurrencyCode: String {
        resolvedDisplayCurrencyCode(preferredCurrencyCode: currencyCode)
    }

    static var supportedCurrency: SupportedCurrency {
        SupportedCurrency(rawValue: resolvedCurrencyCode) ?? .defaultFromLocale
    }

    static func resolvedDisplayCurrencyCode(preferredCurrencyCode: String) -> String {
        if SupportedCurrency(rawValue: preferredCurrencyCode) != nil {
            return preferredCurrencyCode
        }
        return SupportedCurrency.defaultFromLocale.rawValue
    }
}

/// Global accessor for transaction account selection preferences
enum TransactionAccountPreference {
    static var defaultAccountId: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: kDefaultTransactionAccountId) else {
                return nil
            }
            return UUID(uuidString: raw)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: kDefaultTransactionAccountId)
        }
    }
    
    static var rememberLastUsedAccount: Bool {
        get {
            UserDefaults.standard.object(forKey: kRememberLastUsedTransactionAccount) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kRememberLastUsedTransactionAccount)
        }
    }
    
    static var lastUsedAccountId: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: kLastUsedTransactionAccountId) else {
                return nil
            }
            return UUID(uuidString: raw)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: kLastUsedTransactionAccountId)
        }
    }
}

enum TransactionEntryFlowPreference {
    static var autoPresentAccountAfterCategorySelection: Bool {
        get {
            UserDefaults.standard.object(forKey: kAutoPresentAccountAfterCategorySelection) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kAutoPresentAccountAfterCategorySelection)
        }
    }
}

enum ExchangeRateSyncPreference {
    static var lastSuccessfulSyncDate: Date? {
        get {
            UserDefaults.standard.object(forKey: kLastSuccessfulRateSyncDate) as? Date
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: kLastSuccessfulRateSyncDate)
            } else {
                UserDefaults.standard.removeObject(forKey: kLastSuccessfulRateSyncDate)
            }
        }
    }

    static var lastFailedAttemptDate: Date? {
        get {
            UserDefaults.standard.object(forKey: kLastFailedRateSyncAttemptDate) as? Date
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: kLastFailedRateSyncAttemptDate)
            } else {
                UserDefaults.standard.removeObject(forKey: kLastFailedRateSyncAttemptDate)
            }
        }
    }
}

enum TravelCurrencySource: String, CaseIterable, Identifiable, Codable {
    case automatic
    case manual

    var id: Self { self }
}

enum TravelCurrencyPreference {
    static let sourceStorageKey = kTravelCurrencySource
    static let modeEnabledStorageKey = kTravelCurrencyModeEnabled
    static let detectedCurrencyStorageKey = kDetectedTravelCurrencyCode
    static let manualCurrencyStorageKey = kManualTravelCurrencyCode

    static var isEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: modeEnabledStorageKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: modeEnabledStorageKey)
        }
    }

    static var source: TravelCurrencySource {
        get {
            let rawValue = UserDefaults.standard.string(forKey: sourceStorageKey)
            return TravelCurrencySource(rawValue: rawValue ?? "") ?? .automatic
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sourceStorageKey)
        }
    }

    static var detectedCurrencyCode: String? {
        get {
            TravelCurrencyState.normalizedCurrencyCode(
                UserDefaults.standard.string(forKey: detectedCurrencyStorageKey)
            )
        }
        set {
            if let normalized = TravelCurrencyState.normalizedCurrencyCode(newValue) {
                UserDefaults.standard.set(normalized, forKey: detectedCurrencyStorageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: detectedCurrencyStorageKey)
            }
        }
    }

    static var manualCurrencyCode: String? {
        get {
            TravelCurrencyState.normalizedCurrencyCode(
                UserDefaults.standard.string(forKey: manualCurrencyStorageKey)
            )
        }
        set {
            if let normalized = TravelCurrencyState.normalizedCurrencyCode(newValue) {
                UserDefaults.standard.set(normalized, forKey: manualCurrencyStorageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: manualCurrencyStorageKey)
            }
        }
    }
}

enum ReportsCategoryRowLimitPreference {
    static let storageKey = kReportsCategoryRowLimit
    static let defaultValue = 5
    static let supportedValues = [3, 5, 8, 12]

    static func normalized(_ value: Int) -> Int {
        supportedValues.contains(value) ? value : defaultValue
    }

    static var rowLimit: Int {
        get {
            normalized(
                UserDefaults.standard.object(forKey: storageKey) as? Int
                    ?? defaultValue
            )
        }
        set {
            UserDefaults.standard.set(normalized(newValue), forKey: storageKey)
        }
    }
}

enum TravelCurrencySettingSummaryFormatter {
    static func string(
        isEnabled: Bool = true,
        source: TravelCurrencySource,
        currentTravelCurrencyCode: String?,
        manualTravelCurrencyCode: String?,
        defaultCurrencyCode: String
    ) -> String {
        guard isEnabled else {
            return AppLocalization.string(
                "settings.exchangeRate.currentTravelCurrency.none",
                defaultValue: "Inactive"
            )
        }

        switch source {
        case .automatic:
            if let currentTravelCurrencyCode {
                return AppLocalization.string(
                    "settings.exchangeRate.configuration.summary.automatic",
                    defaultValue: "Automatic · %@"
                )
                .replacingOccurrences(of: "%@", with: currentTravelCurrencyCode)
            }
            return AppLocalization.string(
                "settings.exchangeRate.configuration.automatic",
                defaultValue: "Automatic"
            )
        case .manual:
            guard let manualCurrencyCode = manualTravelCurrencyCode,
                  manualCurrencyCode != defaultCurrencyCode else {
                return AppLocalization.string(
                    "settings.exchangeRate.configuration.summary.manual.unset",
                    defaultValue: "Manual (Not Set)"
                )
            }
            return AppLocalization.string(
                "settings.exchangeRate.configuration.summary.manual",
                defaultValue: "Manual · %@"
            )
            .replacingOccurrences(of: "%@", with: manualCurrencyCode)
        }
    }
}

enum TravelCurrencyManualSelection {
    static func seededManualCurrencyCode(currentTravelCurrencyCode: String?) -> String? {
        TravelCurrencyState.normalizedCurrencyCode(currentTravelCurrencyCode)
    }

    static func availableCurrencies(defaultCurrencyCode: String) -> [SupportedCurrency] {
        let normalizedDefaultCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(
            defaultCurrencyCode
        )
        return SupportedCurrency.allCases.filter { currency in
            currency.rawValue != normalizedDefaultCurrencyCode
        }
    }
}

@Observable
@MainActor
final class SettingsViewModel {
    private let modelContext: ModelContext
    private let exchangeRateRefreshScheduler: ExchangeRateRefreshScheduler
    private let travelCurrencyLocationService: any TravelCurrencyLocationServicing
    private let backupExportService: any BackupExportServicing
    private let backupImportService: any BackupImportServicing
    private let backupFileStore: any BackupFileStoring
    private let backupCreationDebounceInterval: TimeInterval
    private let now: () -> Date
    private var cloudSyncSettingsStore: any CloudSyncSettingsStoring
    private var isSynchronizingCloudSyncState = false
    private var pendingManagedBackupRestoreData: Data?
    private var lastManagedBackupCreatedAt: Date?

    /// User's selected default currency - persisted to UserDefaults
    var defaultCurrencyCode: String {
        didSet {
            UserCurrencyPreference.currencyCode = defaultCurrencyCode
        }
    }

    var defaultAccountId: UUID? {
        didSet {
            TransactionAccountPreference.defaultAccountId = defaultAccountId
        }
    }

    var rememberLastUsedAccount: Bool {
        didSet {
            TransactionAccountPreference.rememberLastUsedAccount = rememberLastUsedAccount
        }
    }

    var autoPresentAccountAfterCategorySelection: Bool {
        didSet {
            TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection = autoPresentAccountAfterCategorySelection
        }
    }

    var appLanguage: AppLanguage {
        didSet {
            AppLanguagePreference.language = appLanguage
        }
    }

    var appTheme: AppTheme {
        didSet {
            AppThemePreference.theme = appTheme
        }
    }

    var appLaunchTab: AppTab {
        didSet {
            AppLaunchTabPreference.defaultTab = appLaunchTab
        }
    }

    var travelCurrencySource: TravelCurrencySource {
        didSet {
            TravelCurrencyPreference.source = travelCurrencySource
        }
    }

    var isTravelCurrencyModeEnabled: Bool {
        didSet {
            TravelCurrencyPreference.isEnabled = isTravelCurrencyModeEnabled
        }
    }

    var detectedTravelCurrencyCode: String? {
        didSet {
            TravelCurrencyPreference.detectedCurrencyCode = detectedTravelCurrencyCode
        }
    }

    var manualTravelCurrencyCode: String? {
        didSet {
            TravelCurrencyPreference.manualCurrencyCode = manualTravelCurrencyCode
        }
    }

    var reportsCategoryRowLimit: Int {
        didSet {
            ReportsCategoryRowLimitPreference.rowLimit = reportsCategoryRowLimit
        }
    }

    var automaticBackupFrequency: AutomaticBackupFrequency {
        didSet {
            AutomaticBackupPreference.frequency = automaticBackupFrequency
        }
    }

    var backupRetentionLimit: BackupRetentionLimit {
        didSet {
            AutomaticBackupPreference.retentionLimit = backupRetentionLimit
            pruneAutomaticBackupsToRetentionLimit()
        }
    }

    var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    var accountCount: Int = 0
    var transactionCount: Int = 0
    var categoryCount: Int = 0
    var budgetCount: Int = 0
    var isRefreshingRates = false
    var isPreparingBackupExport = false
    var preparedBackupArchive: BackupArchive?
    var backupExportErrorMessage: String?
    var backupFiles: [BackupFileSummary] = []
    var isLoadingBackupFiles = false
    var backupFileListErrorMessage: String?
    var lastCreatedBackupFile: BackupFileSummary?
    var isPreparingBackupRestorePreview = false
    var preparedBackupRestorePreview: BackupImportPreflightSummary?
    var backupRestorePreviewErrorMessage: String?
    var isApplyingBackupRestore = false
    var appliedBackupImportReport: ImportReport?
    var backupRestoreApplyErrorMessage: String?
    private(set) var selectedBackupRestoreMode: BackupRestoreMode = .replace
    private(set) var selectedBackupRestoreScope: BackupRestoreScope = .financialDataAndAllPreferences
    var isCloudSyncEnabled = false {
        didSet {
            guard !isSynchronizingCloudSyncState else { return }
            guard oldValue != isCloudSyncEnabled else { return }

            cloudSyncSettingsStore.isCloudSyncEnabled = isCloudSyncEnabled
            syncCloudSyncStateFromStore()
        }
    }
    private(set) var cloudSyncStatus: CloudSyncStatus = .disabled

    var isLoading = false
    var errorMessage: String?
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var availableCurrencies: [SupportedCurrency] {
        SupportedCurrency.allCases
    }

    var availableTravelCurrencies: [SupportedCurrency] {
        TravelCurrencyManualSelection.availableCurrencies(
            defaultCurrencyCode: defaultCurrencyCode
        )
    }

    var availableLaunchTabs: [AppTab] {
        AppLaunchTabPreference.supportedTabs
    }

    var exchangeRateProviderName: String {
        exchangeRateRefreshScheduler.providerName
    }

    var lastSuccessfulRateSyncDate: Date? {
        ExchangeRateSyncPreference.lastSuccessfulSyncDate
    }

    var isExchangeRateSyncStale: Bool {
        exchangeRateRefreshScheduler.shouldRefresh(
            lastSuccessfulSyncDate: lastSuccessfulRateSyncDate
        )
    }

    private var resolvedTravelCurrencyState: ResolvedTravelCurrencyState {
        TravelCurrencyState.resolve(
            defaultCurrencyCode: defaultCurrencyCode,
            isEnabled: isTravelCurrencyModeEnabled,
            source: travelCurrencySource,
            detectedCurrencyCode: detectedTravelCurrencyCode,
            manualTravelCurrencyCode: manualTravelCurrencyCode
        )
    }

    var detectedLocationCurrencyCode: String? {
        resolvedTravelCurrencyState.detectedLocationCurrencyCode
    }

    var detectedLocationCurrencyDisplayText: String {
        if let detectedLocationCurrencyCode {
            return detectedLocationCurrencyCode
        }

        if travelCurrencySource == .automatic,
           travelCurrencyLocationService.authorizationStatus() != .authorized {
            return AppLocalization.string(
                "settings.exchangeRate.locationNotEnabled",
                defaultValue: "Location Not Enabled"
            )
        }

        return AppLocalization.string(
            "settings.exchangeRate.detectedCurrency.none",
            defaultValue: "Not Detected"
        )
    }

    var currentTravelCurrencyCode: String? {
        resolvedTravelCurrencyState.currentTravelCurrencyCode
    }

    var travelCurrencySettingSummary: String {
        TravelCurrencySettingSummaryFormatter.string(
            isEnabled: isTravelCurrencyModeEnabled,
            source: travelCurrencySource,
            currentTravelCurrencyCode: currentTravelCurrencyCode,
            manualTravelCurrencyCode: manualTravelCurrencyCode,
            defaultCurrencyCode: defaultCurrencyCode
        )
    }

    var reminderStatusText: String {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            AppLocalization.string("settings.reminders.enabled", defaultValue: "Enabled")
        case .denied:
            AppLocalization.string("settings.reminders.denied", defaultValue: "Denied")
        case .notDetermined:
            AppLocalization.string("settings.reminders.notDetermined", defaultValue: "Not Requested")
        @unknown default:
            AppLocalization.string("settings.reminders.unknown", defaultValue: "Unknown")
        }
    }

    var allNotificationsEnabled: Bool {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            true
        case .denied, .notDetermined:
            false
        @unknown default:
            false
        }
    }

    var cloudSyncStatusTitle: String {
        switch cloudSyncStatus {
        case .enabled:
            AppLocalization.string("settings.cloudSync.status.on", defaultValue: "On")
        case .disabled:
            AppLocalization.string("settings.cloudSync.status.off", defaultValue: "Off")
        case .unavailable:
            AppLocalization.string(
                "settings.cloudSync.status.needsAttention",
                defaultValue: "Needs Attention"
            )
        }
    }

    var cloudSyncStatusMessage: String {
        switch cloudSyncStatus {
        case .enabled:
            AppLocalization.string(
                "settings.cloudSync.message.on",
                defaultValue: "Changes sync through iCloud."
            )
        case .disabled:
            AppLocalization.string(
                "settings.cloudSync.message.off",
                defaultValue: "Sync is currently off."
            )
        case .unavailable(.iCloudAccountRequired):
            AppLocalization.string(
                "settings.cloudSync.message.signInRequired",
                defaultValue: "Sign in to iCloud in Settings, then return here to enable sync."
            )
        }
    }

    var cloudSyncRequiresAttention: Bool {
        if case .unavailable = cloudSyncStatus {
            return true
        }
        return false
    }

    var backupExportSummaryText: String? {
        guard let preparedBackupArchive else { return nil }
        return backupSummaryText(
            sourceDevice: preparedBackupArchive.exportSourceDevice,
            recordCounts: preparedBackupArchive.integrityMetadata.recordCounts
        )
    }

    var backupRestorePreviewSummaryText: String? {
        guard let preparedBackupRestorePreview else { return nil }
        return backupSummaryText(
            sourceDevice: preparedBackupRestorePreview.exportSourceDevice,
            recordCounts: preparedBackupRestorePreview.recordCounts
        )
    }

    var appliedBackupImportSummaryText: String? {
        guard let appliedBackupImportReport else { return nil }
        let summary = appliedBackupImportReport.summary
        return AppLocalization.formatted(
            "settings.backup.import.summary",
            defaultValue: "Imported %1$lld, updated %2$lld, skipped %3$lld, failed %4$lld",
            Int64(summary.importedCount),
            Int64(summary.updatedCount),
            Int64(summary.skippedCount),
            Int64(summary.failedCount)
        )
    }

    private func backupSummaryText(
        sourceDevice: String,
        recordCounts: BackupRecordCounts
    ) -> String {
        AppLocalization.formatted(
            "settings.backup.summary",
            defaultValue: "%1$@, %2$lld accounts, %3$lld transactions",
            sourceDevice,
            Int64(recordCounts.accounts),
            Int64(recordCounts.transactions)
        )
    }

    enum NotificationSettingsAction: Equatable {
        case none
        case openSystemSettings
    }
    
    init(
        modelContext: ModelContext,
        exchangeRateRefreshScheduler: ExchangeRateRefreshScheduler? = nil,
        travelCurrencyLocationService: (any TravelCurrencyLocationServicing)? = nil,
        backupExportService: (any BackupExportServicing)? = nil,
        backupImportService: (any BackupImportServicing)? = nil,
        backupFileStore: (any BackupFileStoring)? = nil,
        cloudSyncSettingsStore: (any CloudSyncSettingsStoring)? = nil,
        backupCreationDebounceInterval: TimeInterval = 2,
        now: @escaping () -> Date = Date.init
    ) {
        self.modelContext = modelContext
        self.exchangeRateRefreshScheduler = exchangeRateRefreshScheduler
            ?? ExchangeRateRefreshScheduler()
        self.travelCurrencyLocationService = travelCurrencyLocationService
            ?? TravelCurrencyLocationService()
        self.backupExportService = backupExportService
            ?? BackupExportService(context: modelContext)
        self.backupImportService = backupImportService
            ?? BackupImportService(restoreSessionMarkerStore: RestoreSessionMarkerStore())
        self.backupFileStore = backupFileStore
            ?? BackupFileStore()
        self.backupCreationDebounceInterval = backupCreationDebounceInterval
        self.now = now
        self.cloudSyncSettingsStore = cloudSyncSettingsStore
            ?? CloudSyncSettingsStore()
        // Load persisted currency preference on init
        self.defaultCurrencyCode = UserCurrencyPreference.currencyCode
        self.defaultAccountId = TransactionAccountPreference.defaultAccountId
        self.rememberLastUsedAccount = TransactionAccountPreference.rememberLastUsedAccount
        self.autoPresentAccountAfterCategorySelection = TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection
        self.appLanguage = AppLanguagePreference.language
        self.appTheme = AppThemePreference.theme
        self.appLaunchTab = AppLaunchTabPreference.defaultTab
        self.isTravelCurrencyModeEnabled = TravelCurrencyPreference.isEnabled
        self.travelCurrencySource = TravelCurrencyPreference.source
        self.detectedTravelCurrencyCode = TravelCurrencyPreference.detectedCurrencyCode
        self.manualTravelCurrencyCode = TravelCurrencyPreference.manualCurrencyCode
        self.reportsCategoryRowLimit = ReportsCategoryRowLimitPreference.rowLimit
        self.automaticBackupFrequency = AutomaticBackupPreference.frequency
        self.backupRetentionLimit = AutomaticBackupPreference.retentionLimit
        syncCloudSyncStateFromStore()
    }

    func prepareBackupExport() {
        isPreparingBackupExport = true
        backupExportErrorMessage = nil
        preparedBackupArchive = nil

        defer {
            isPreparingBackupExport = false
        }

        do {
            preparedBackupArchive = try backupExportService.makeBackupArchive()
        } catch {
            backupExportErrorMessage = error.localizedDescription
        }
    }

    func loadBackupFiles() {
        isLoadingBackupFiles = true
        backupFileListErrorMessage = nil

        defer {
            isLoadingBackupFiles = false
        }

        do {
            backupFiles = try backupFileStore.listBackups()
        } catch {
            backupFiles = []
            backupFileListErrorMessage = error.localizedDescription
        }
    }

    func createManagedBackup() {
        let requestedAt = now()
        guard !isPreparingBackupExport else {
            return
        }
        guard !isDuplicateManagedBackupRequest(at: requestedAt) else {
            return
        }

        isPreparingBackupExport = true
        backupExportErrorMessage = nil
        preparedBackupArchive = nil
        lastCreatedBackupFile = nil

        defer {
            isPreparingBackupExport = false
        }

        do {
            let archive = try backupExportService.makeBackupArchive()
            let backupFile = try backupFileStore.writeBackupArchive(archive)
            preparedBackupArchive = archive
            lastCreatedBackupFile = backupFile
            backupFiles = try backupFileStore.listBackups()
            lastManagedBackupCreatedAt = now()
        } catch {
            backupExportErrorMessage = error.localizedDescription
        }
    }

    func deleteManagedBackup(_ backup: BackupFileSummary) {
        backupFileListErrorMessage = nil

        do {
            try backupFileStore.deleteBackup(backup)
            backupFiles = try backupFileStore.listBackups()
            clearRestoreStateIfNeeded(deletedBackup: backup)

            if lastCreatedBackupFile == backup {
                lastCreatedBackupFile = nil
                preparedBackupArchive = nil
            }
        } catch {
            backupFileListErrorMessage = error.localizedDescription
        }
    }

    func prepareBackupRestorePreview(
        from data: Data,
        mode: BackupRestoreMode,
        scope: BackupRestoreScope
    ) {
        isPreparingBackupRestorePreview = true
        backupRestorePreviewErrorMessage = nil
        preparedBackupRestorePreview = nil

        defer {
            isPreparingBackupRestorePreview = false
        }

        do {
            preparedBackupRestorePreview = try backupImportService.prepareImport(
                data: data,
                mode: mode,
                scope: scope
            )
        } catch {
            backupRestorePreviewErrorMessage = error.localizedDescription
        }
    }

    func prepareManagedBackupRestorePreview(from backup: BackupFileSummary) {
        do {
            let data = try backupFileStore.readBackupData(for: backup)
            pendingManagedBackupRestoreData = data
            prepareBackupRestorePreview(
                from: data,
                mode: selectedBackupRestoreMode,
                scope: selectedBackupRestoreScope
            )

            if backupRestorePreviewErrorMessage != nil {
                pendingManagedBackupRestoreData = nil
            }
        } catch {
            pendingManagedBackupRestoreData = nil
            preparedBackupRestorePreview = nil
            backupRestorePreviewErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func prepareManagedBackupRestoreConfirmation(from backup: BackupFileSummary) -> Bool {
        prepareManagedBackupRestorePreview(from: backup)
        return backupRestorePreviewErrorMessage == nil
    }

    func applyBackupRestore(
        from data: Data,
        mode: BackupRestoreMode,
        scope: BackupRestoreScope
    ) {
        isApplyingBackupRestore = true
        backupRestoreApplyErrorMessage = nil
        appliedBackupImportReport = nil

        defer {
            isApplyingBackupRestore = false
        }

        do {
            appliedBackupImportReport = try backupImportService.applyImport(
                data: data,
                mode: mode,
                scope: scope,
                context: modelContext
            )
            invalidatePreparedBackupRestorePreview()
            reloadPreferenceStateFromStorage()
            try refreshDataCounts()
            if mode == .replace {
                AppModelReload.request()
            }
        } catch {
            backupRestoreApplyErrorMessage = error.localizedDescription
        }
    }

    func applyPreparedManagedBackupRestore() {
        guard let pendingManagedBackupRestoreData else { return }

        applyBackupRestore(
            from: pendingManagedBackupRestoreData,
            mode: selectedBackupRestoreMode,
            scope: selectedBackupRestoreScope
        )

        if backupRestoreApplyErrorMessage == nil {
            self.pendingManagedBackupRestoreData = nil
        }
    }

    func loadSettings() async {
        isLoading = true
        
        do {
            try refreshDataCounts()
            await refreshReminderAuthorizationStatus()
            await refreshTravelCurrencyState()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }

    private func reloadPreferenceStateFromStorage() {
        defaultCurrencyCode = UserCurrencyPreference.currencyCode
        defaultAccountId = TransactionAccountPreference.defaultAccountId
        rememberLastUsedAccount = TransactionAccountPreference.rememberLastUsedAccount
        autoPresentAccountAfterCategorySelection =
            TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection
        appLanguage = AppLanguagePreference.language
        appTheme = AppThemePreference.theme
        appLaunchTab = AppLaunchTabPreference.defaultTab
        isTravelCurrencyModeEnabled = TravelCurrencyPreference.isEnabled
        travelCurrencySource = TravelCurrencyPreference.source
        detectedTravelCurrencyCode = TravelCurrencyPreference.detectedCurrencyCode
        manualTravelCurrencyCode = TravelCurrencyPreference.manualCurrencyCode
        reportsCategoryRowLimit = ReportsCategoryRowLimitPreference.rowLimit
        automaticBackupFrequency = AutomaticBackupPreference.frequency
        backupRetentionLimit = AutomaticBackupPreference.retentionLimit
    }

    private func pruneAutomaticBackupsToRetentionLimit() {
        backupFileListErrorMessage = nil

        do {
            let scheduler = AutomaticBackupScheduler(
                backupExportService: backupExportService,
                backupFileStore: backupFileStore,
                now: now
            )
            try scheduler.pruneAutomaticBackups(limit: backupRetentionLimit)
            backupFiles = try backupFileStore.listBackups()
        } catch {
            backupFileListErrorMessage = error.localizedDescription
        }
    }

    private func invalidatePreparedBackupRestorePreview() {
        preparedBackupRestorePreview = nil
        backupRestorePreviewErrorMessage = nil
    }

    private func clearRestoreStateIfNeeded(deletedBackup backup: BackupFileSummary) {
        guard preparedBackupRestorePreview?.archiveId == backup.archiveId else {
            return
        }

        pendingManagedBackupRestoreData = nil
        invalidatePreparedBackupRestorePreview()
    }

    private func isDuplicateManagedBackupRequest(at requestedAt: Date) -> Bool {
        guard let lastManagedBackupCreatedAt else {
            return false
        }

        return requestedAt.timeIntervalSince(lastManagedBackupCreatedAt) < backupCreationDebounceInterval
    }

    private func syncCloudSyncStateFromStore() {
        isSynchronizingCloudSyncState = true
        isCloudSyncEnabled = cloudSyncSettingsStore.isCloudSyncEnabled
        cloudSyncStatus = cloudSyncSettingsStore.status
        isSynchronizingCloudSyncState = false
    }

    private func refreshDataCounts() throws {
        accountCount = try modelContext.fetchCount(FetchDescriptor<Account>())
        transactionCount = try modelContext.fetchCount(
            FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { !$0.isRecurringTemplate }
            )
        )
        categoryCount = try modelContext.fetchCount(FetchDescriptor<Category>())
        budgetCount = try modelContext.fetchCount(FetchDescriptor<Budget>())
    }

    func refreshExchangeRates(force: Bool = true) async {
        isRefreshingRates = true
        defer { isRefreshingRates = false }

        do {
            _ = try await exchangeRateRefreshScheduler.refreshLatestRatesIfNeeded(
                context: modelContext,
                baseCurrencyCode: defaultCurrencyCode,
                force: force
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setTravelCurrencySource(_ source: TravelCurrencySource) async {
        if source == .automatic {
            _ = await travelCurrencyLocationService.requestAuthorizationIfNeeded()
        }
        travelCurrencySource = source

        switch source {
        case .automatic:
            manualTravelCurrencyCode = nil
            await refreshTravelCurrencyState()
        case .manual:
            if manualTravelCurrencyCode == nil {
                manualTravelCurrencyCode = TravelCurrencyManualSelection.seededManualCurrencyCode(
                    currentTravelCurrencyCode: currentTravelCurrencyCode
                )
            }
            await refreshTravelCurrencyState()
        }
    }

    func setTravelCurrencyModeEnabled(_ isEnabled: Bool) async {
        isTravelCurrencyModeEnabled = isEnabled
        guard isEnabled else { return }

        await refreshTravelCurrencyState()
    }

    func setManualTravelCurrencyCode(_ currencyCode: String?) {
        manualTravelCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(currencyCode)
    }

    func requestTravelCurrencyLocationUpdate() async {
        guard isTravelCurrencyModeEnabled else { return }

        _ = await travelCurrencyLocationService.requestAuthorizationIfNeeded()
        await refreshTravelCurrencyState()
    }

    func refreshTravelCurrencyState() async {
        guard isTravelCurrencyModeEnabled else { return }

        let refresher = TravelCurrencyPreferenceRefresher(
            locationService: travelCurrencyLocationService
        )
        detectedTravelCurrencyCode = await refresher.refreshDetectedTravelCurrency()
    }

    func refreshReminderAuthorizationStatus() async {
        let status = await UNUserNotificationCenter.current().authorizationStatusValue()
        notificationAuthorizationStatus = status
    }

    func requestReminderAuthorization() async {
        let scheduler = TransactionReminderScheduler(context: modelContext)
        do {
            _ = try await scheduler.requestAuthorizationIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshReminderAuthorizationStatus()
    }

    func setAllNotificationsEnabled(_ isEnabled: Bool) async -> NotificationSettingsAction {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return isEnabled ? .none : .openSystemSettings
        case .denied:
            return .openSystemSettings
        case .notDetermined:
            guard isEnabled else { return .none }
            await requestReminderAuthorization()
            return .none
        @unknown default:
            return .none
        }
    }
    
    func clearAllData() async throws {
        try modelContext.delete(model: Transaction.self)
        try modelContext.delete(model: Budget.self)
        try modelContext.delete(model: Account.self)
        try modelContext.delete(model: Category.self)
        try modelContext.delete(model: Currency.self)
        try modelContext.delete(model: ExchangeRate.self)
        ExchangeRateSyncPreference.lastSuccessfulSyncDate = nil
        
        let seeder = DefaultDataSeeder(context: modelContext)
        try await seeder.seedIfNeeded()
        
        await loadSettings()
    }
}
