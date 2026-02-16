import Foundation
import SwiftUI
import SwiftData

// MARK: - User Currency Preference (Persisted)

/// Key for storing user's preferred currency in UserDefaults
private let kDefaultCurrencyCode = "flux.defaultCurrencyCode"
private let kDefaultTransactionAccountId = "flux.defaultTransactionAccountId"
private let kRememberLastUsedTransactionAccount = "flux.rememberLastUsedTransactionAccount"
private let kLastUsedTransactionAccountId = "flux.lastUsedTransactionAccountId"
private let kLastSuccessfulRateSyncDate = "flux.lastSuccessfulRateSyncDate"
private let kUseLocationDefaults = "flux.useLocationDefaults"

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
            UserDefaults.standard.object(forKey: kRememberLastUsedTransactionAccount) as? Bool ?? false
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

enum ExchangeRateSyncPreference {
    static var lastSuccessfulSyncDate: Date? {
        get {
            UserDefaults.standard.object(forKey: kLastSuccessfulRateSyncDate) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kLastSuccessfulRateSyncDate)
        }
    }
}

enum TravelCurrencyPreference {
    static let storageKey = kUseLocationDefaults

    static var useLocationDefaults: Bool {
        get {
            UserDefaults.standard.object(forKey: storageKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }
}

@Observable
@MainActor
final class SettingsViewModel {
    private let modelContext: ModelContext
    private let exchangeRateRefreshScheduler: ExchangeRateRefreshScheduler
    private let travelCurrencyLocationService: any TravelCurrencyLocationServicing
    
    var regionalSettings = RegionalSettings.shared
    
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

    var appLanguage: AppLanguage {
        didSet {
            AppLanguagePreference.language = appLanguage
        }
    }

    var useLocationDefaults: Bool {
        didSet {
            TravelCurrencyPreference.useLocationDefaults = useLocationDefaults
        }
    }
    
    var accountCount: Int = 0
    var transactionCount: Int = 0
    var categoryCount: Int = 0
    var budgetCount: Int = 0
    var isRefreshingRates = false
    
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
    
    init(
        modelContext: ModelContext,
        exchangeRateRefreshScheduler: ExchangeRateRefreshScheduler? = nil,
        travelCurrencyLocationService: (any TravelCurrencyLocationServicing)? = nil
    ) {
        self.modelContext = modelContext
        self.exchangeRateRefreshScheduler = exchangeRateRefreshScheduler
            ?? ExchangeRateRefreshScheduler()
        self.travelCurrencyLocationService = travelCurrencyLocationService
            ?? TravelCurrencyLocationService()
        // Load persisted currency preference on init
        self.defaultCurrencyCode = UserCurrencyPreference.currencyCode
        self.defaultAccountId = TransactionAccountPreference.defaultAccountId
        self.rememberLastUsedAccount = TransactionAccountPreference.rememberLastUsedAccount
        self.appLanguage = AppLanguagePreference.language
        self.useLocationDefaults = TravelCurrencyPreference.useLocationDefaults
    }
    
    func loadSettings() async {
        isLoading = true
        
        do {
            accountCount = try modelContext.fetchCount(FetchDescriptor<Account>())
            transactionCount = try modelContext.fetchCount(
                FetchDescriptor<Transaction>(
                    predicate: #Predicate<Transaction> { !$0.isRecurringTemplate }
                )
            )
            categoryCount = try modelContext.fetchCount(FetchDescriptor<Category>())
            budgetCount = try modelContext.fetchCount(FetchDescriptor<Budget>())
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
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

    func setUseLocationDefaults(_ enabled: Bool) async {
        if enabled {
            _ = await travelCurrencyLocationService.requestAuthorizationIfNeeded()
        }
        useLocationDefaults = enabled
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
