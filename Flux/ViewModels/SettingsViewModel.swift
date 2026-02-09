import Foundation
import SwiftUI
import SwiftData

@Observable
@MainActor
final class SettingsViewModel {
    private let modelContext: ModelContext
    
    var regionalSettings = RegionalSettings.shared
    var defaultCurrencyCode: String = SupportedCurrency.defaultFromLocale.rawValue
    var defaultAccountId: UUID?
    
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
    
    var colorSchemes: [RegionalSettings.GainLossColorScheme] {
        RegionalSettings.GainLossColorScheme.allCases
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
    
    func setColorScheme(_ scheme: RegionalSettings.GainLossColorScheme?) {
        regionalSettings.colorSchemeOverride = scheme
    }
    
    func resetToRegionalDefault() {
        regionalSettings.colorSchemeOverride = nil
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
