import Foundation
import SwiftData

/// Seeds the database with default data on first launch
@MainActor
struct DefaultDataSeeder {
    let context: ModelContext
    
    /// Checks if seeding is needed and performs it
    func seedIfNeeded() async throws {
        let currencyCount = try context.fetchCount(FetchDescriptor<Currency>())
        let categoryCount = try context.fetchCount(FetchDescriptor<Category>())
        
        if currencyCount == 0 {
            try seedCurrencies()
        }
        
        if categoryCount == 0 {
            try seedCategories()
        }
        
        try context.save()
    }
    
    // MARK: - Currency Seeding
    
    private func seedCurrencies() throws {
        let defaultCurrency = SupportedCurrency.defaultFromLocale
        
        for currency in SupportedCurrency.allCases {
            let currencyModel = Currency(
                code: currency.rawValue,
                exchangeRateToBase: currency == defaultCurrency ? 1.0 : 0.0,
                lastUpdated: .now,
                isBaseCurrency: currency == defaultCurrency
            )
            context.insert(currencyModel)
        }
    }
    
    // MARK: - Category Seeding
    
    private func seedCategories() throws {
        // Expense categories
        let expenseCategories: [(key: String, icon: String, color: String)] = [
            ("category.expense.food", "fork.knife", "#FF6B6B"),
            ("category.expense.transport", "car.fill", "#4ECDC4"),
            ("category.expense.shopping", "bag.fill", "#45B7D1"),
            ("category.expense.entertainment", "tv.fill", "#96CEB4"),
            ("category.expense.bills", "doc.text.fill", "#FFEAA7"),
            ("category.expense.health", "heart.fill", "#DDA0DD"),
            ("category.expense.education", "book.fill", "#98D8C8"),
            ("category.expense.travel", "airplane", "#F7DC6F"),
            ("category.expense.groceries", "cart.fill", "#82E0AA"),
            ("category.expense.dining", "cup.and.saucer.fill", "#F8B500"),
            ("category.expense.coffee", "mug.fill", "#6F4E37"),
            ("category.expense.subscriptions", "repeat", "#9B59B6"),
            ("category.expense.housing", "house.fill", "#3498DB"),
            ("category.expense.personalCare", "figure.stand", "#E91E63"),
            ("category.expense.gifts", "gift.fill", "#E74C3C")
        ]
        
        for (key, icon, color) in expenseCategories {
            let category = Category(
                nameKey: key,
                icon: icon,
                colorHex: color,
                type: .expense,
                isSystemDefault: true
            )
            context.insert(category)
        }
        
        // Income categories
        let incomeCategories: [(key: String, icon: String, color: String)] = [
            ("category.income.salary", "banknote.fill", "#27AE60"),
            ("category.income.freelance", "laptopcomputer", "#3498DB"),
            ("category.income.investment", "chart.line.uptrend.xyaxis", "#9B59B6"),
            ("category.income.gift", "giftcard.fill", "#E74C3C"),
            ("category.income.refund", "arrow.uturn.backward.circle.fill", "#F39C12")
        ]
        
        for (key, icon, color) in incomeCategories {
            let category = Category(
                nameKey: key,
                icon: icon,
                colorHex: color,
                type: .income,
                isSystemDefault: true
            )
            context.insert(category)
        }
    }
}

// MARK: - App Initialization Extension

extension ModelContainer {
    /// Creates and seeds the container for production use
    @MainActor
    static func createAndSeed(enableCloudKit: Bool = false) async throws -> ModelContainer {
        let container = try ModelContainerConfiguration.createContainer(enableCloudKit: enableCloudKit)
        let seeder = DefaultDataSeeder(context: container.mainContext)
        try await seeder.seedIfNeeded()
        return container
    }
}
