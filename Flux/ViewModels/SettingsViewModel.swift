import Foundation
import SwiftUI
import SwiftData

// MARK: - User Currency Preference (Persisted)

/// Key for storing user's preferred currency in UserDefaults
private let kDefaultCurrencyCode = "flux.defaultCurrencyCode"
private let kDefaultTransactionAccountId = "flux.defaultTransactionAccountId"
private let kRememberLastUsedTransactionAccount = "flux.rememberLastUsedTransactionAccount"
private let kLastUsedTransactionAccountId = "flux.lastUsedTransactionAccountId"

/// Global accessor for user's preferred currency code
/// Use this in views that need the default currency without SettingsViewModel
enum UserCurrencyPreference {
    static var currencyCode: String {
        get {
            UserDefaults.standard.string(forKey: kDefaultCurrencyCode) 
                ?? SupportedCurrency.defaultFromLocale.rawValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kDefaultCurrencyCode)
        }
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

@Observable
@MainActor
final class SettingsViewModel {
    private let modelContext: ModelContext
    
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
    
    var accountCount: Int = 0
    var transactionCount: Int = 0
    var categoryCount: Int = 0
    var budgetCount: Int = 0
    
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
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Load persisted currency preference on init
        self.defaultCurrencyCode = UserCurrencyPreference.currencyCode
        self.defaultAccountId = TransactionAccountPreference.defaultAccountId
        self.rememberLastUsedAccount = TransactionAccountPreference.rememberLastUsedAccount
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
    
    func clearAllData() async throws {
        try modelContext.delete(model: Transaction.self)
        try modelContext.delete(model: Budget.self)
        try modelContext.delete(model: Account.self)
        try modelContext.delete(model: Category.self)
        try modelContext.delete(model: Currency.self)
        
        let seeder = DefaultDataSeeder(context: modelContext)
        try await seeder.seedIfNeeded()
        
        await loadSettings()
    }
}
