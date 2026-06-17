import Foundation
import SwiftData

/// Seeds the database with default data on first launch
@MainActor
struct DefaultDataSeeder {
    let context: ModelContext

    private let expenseCategoryDefinitions: [(key: String, icon: String, color: String)] = [
        ("category.expense.food", "carrot.fill", "#EF4444"),
        ("category.expense.home", "house.circle.fill", "#06B6D4"),
        ("category.expense.transport", "car.fill", "#14B8A6"),
        ("category.expense.shopping", "bag.fill", "#06B6D4"),
        ("category.expense.entertainment", "tv.fill", "#6366F1"),
        ("category.expense.bills", "doc.text.fill", "#64748B"),
        ("category.expense.insurance", "shield.fill", "#A855F7"),
        ("category.expense.tax", "building.columns.fill", "#F59E0B"),
        ("category.expense.health", "heart.fill", "#EC4899"),
        ("category.expense.education", "book.fill", "#3B82F6"),
        ("category.expense.upskilling", "graduationcap.fill", "#06B6D4"),
        ("category.expense.pet", "pawprint.fill", "#EF4444"),
        ("category.expense.travel", "airplane", "#F59E0B"),
        ("category.expense.groceries", "cart.fill", "#22C55E"),
        ("category.expense.dining", "fork.knife", "#F59E0B"),
        ("category.expense.coffee", "cup.and.saucer.fill", "#A16207"),
        ("category.expense.subscriptions", "repeat", "#A855F7"),
        ("category.expense.housing", "building.2.fill", "#3B82F6"),
        ("category.expense.personalCare", "shower.fill", "#F43F5E"),
        ("category.expense.gifts", "gift.fill", "#EF4444")
    ]

    private let incomeCategoryDefinitions: [(key: String, icon: String, color: String)] = [
        ("category.income.salary", "banknote.fill", "#22C55E"),
        ("category.income.bonus", "sparkles", "#22C55E"),
        ("category.income.freelance", "laptopcomputer", "#3B82F6"),
        ("category.income.interest", "percent", "#06B6D4"),
        ("category.income.governmentSubsidy", "building.2.crop.circle.fill", "#14B8A6"),
        ("category.income.secondHandSale", "tag.fill", "#06B6D4"),
        ("category.income.investment", "chart.line.uptrend.xyaxis", "#A855F7"),
        ("category.income.gift", "gift.fill", "#EF4444"),
        ("category.income.refund", "arrow.counterclockwise.circle.fill", "#F59E0B")
    ]

    private let accountTypeDefinitions: [(name: String, icon: String, color: String, legacyType: AccountType)] = [
        ("Cash", "banknote", "#22C55E", .cash),
        ("Bank Account", "building.columns", "#3B82F6", .bank),
        ("Credit Card", "creditcard", "#F59E0B", .creditCard),
        ("E-wallet", "wallet.bifold", "#06B6D4", .eWallet),
        ("Investment", "chart.line.uptrend.xyaxis", "#A855F7", .investment)
    ]
    
    /// Checks if seeding is needed and performs it
    func seedIfNeeded() async throws {
        let currencyCount = try context.fetchCount(FetchDescriptor<Currency>())
        let categoryCount = try context.fetchCount(FetchDescriptor<Category>())
        let accountTypeDefinitionCount = try context.fetchCount(FetchDescriptor<AccountTypeDefinition>())
        let accountCount = try context.fetchCount(FetchDescriptor<Account>())
        #if DEBUG
        let transactionCount = try context.fetchCount(FetchDescriptor<Transaction>())
        let budgetCount = try context.fetchCount(FetchDescriptor<Budget>())
        #endif
        
        if currencyCount == 0 {
            try seedCurrencies()
        }
        
        if categoryCount == 0 {
            try seedCategories()
        }

        if accountTypeDefinitionCount == 0 {
            try seedAccountTypeDefinitions()
        } else {
            try seedMissingDefaultAccountTypeDefinitions()
        }
        
        if accountCount == 0 {
            try seedAccounts()
        }

        try backfillAccountTypeDefinitions()
        try backfillCategorySortOrders()

        #if DEBUG
        if transactionCount == 0 {
            try seedDebugSampleTransactions()
        }
        if budgetCount == 0 {
            try seedDebugSampleBudgets()
        }
        #endif
        
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
        for (index, item) in expenseCategorySeedOrder.enumerated() {
            let category = Category(
                nameKey: item.key,
                icon: item.icon,
                colorHex: item.color,
                type: .expense,
                isSystemDefault: true,
                sortOrder: index
            )
            context.insert(category)
        }
        
        for (index, item) in incomeCategorySeedOrder.enumerated() {
            let category = Category(
                nameKey: item.key,
                icon: item.icon,
                colorHex: item.color,
                type: .income,
                isSystemDefault: true,
                sortOrder: index
            )
            context.insert(category)
        }
    }

    // MARK: - Account Seeding

    private func seedAccountTypeDefinitions() throws {
        for (index, item) in accountTypeDefinitions.enumerated() {
            let definition = AccountTypeDefinition(
                name: item.name,
                icon: item.icon,
                colorHex: item.color,
                isSystemDefault: true,
                sortOrder: index,
                legacyType: item.legacyType
            )
            context.insert(definition)
        }
    }

    private func seedMissingDefaultAccountTypeDefinitions() throws {
        let definitions = try context.fetch(FetchDescriptor<AccountTypeDefinition>())

        for (index, item) in accountTypeDefinitions.enumerated() {
            if let existingDefinition = definitions.first(where: { $0.legacyType == item.legacyType }) {
                if existingDefinition.isSystemDefault {
                    existingDefinition.sortOrder = index
                }
                continue
            }

            let definition = AccountTypeDefinition(
                name: item.name,
                icon: item.icon,
                colorHex: item.color,
                isSystemDefault: true,
                sortOrder: index,
                legacyType: item.legacyType
            )
            context.insert(definition)
        }
    }
    
    private func seedAccounts() throws {
        let defaultCurrencyCode = SupportedCurrency.defaultFromLocale.rawValue
        let accountTypeMap = try accountTypeDefinitionsByLegacyType()
        
        let defaultAccounts: [(name: String, type: AccountType)] = [
            ("Cash", .cash),
            ("Bank Account", .bank),
            ("Credit Card", .creditCard)
        ]
        
        for item in defaultAccounts {
            let account = Account(
                name: item.name,
                type: item.type,
                currencyCode: defaultCurrencyCode,
                initialBalance: 0,
                typeDefinition: accountTypeMap[item.type]
            )
            context.insert(account)
        }
    }

    private func backfillAccountTypeDefinitions() throws {
        let accountTypeMap = try accountTypeDefinitionsByLegacyType()
        let accounts = try context.fetch(FetchDescriptor<Account>())

        for account in accounts where account.typeDefinition == nil {
            guard let definition = accountTypeMap[account.type] else { continue }
            account.typeDefinition = definition
            account.icon = definition.icon
            account.colorHex = definition.colorHex
        }
    }

    private func backfillCategorySortOrders() throws {
        let categories = try context.fetch(FetchDescriptor<Category>())

        for type in TransactionType.allCases {
            var typeCategories = categories.filter { $0.type == type }
            let orders = typeCategories.map(\.sortOrder)
            guard Set(orders).count != orders.count else {
                continue
            }

            let preferredOrder = categorySortRank(for: type)
            typeCategories.sort { lhs, rhs in
                let lhsRank = preferredOrder[lhs.nameKey] ?? Int.max
                let rhsRank = preferredOrder[rhs.nameKey] ?? Int.max
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }

            for (index, category) in typeCategories.enumerated() {
                category.sortOrder = index
            }
        }
    }

    private var expenseCategorySeedOrder: [(key: String, icon: String, color: String)] {
        let lookup = Dictionary(uniqueKeysWithValues: expenseCategoryDefinitions.map { ($0.key, $0) })
        return expensePreferredCategoryKeys.compactMap { lookup[$0] }
    }

    private var incomeCategorySeedOrder: [(key: String, icon: String, color: String)] {
        let lookup = Dictionary(uniqueKeysWithValues: incomeCategoryDefinitions.map { ($0.key, $0) })
        return incomePreferredCategoryKeys.compactMap { lookup[$0] }
    }

    private func categorySortRank(for type: TransactionType) -> [String: Int] {
        let keys = type == .expense ? expensePreferredCategoryKeys : incomePreferredCategoryKeys
        return Dictionary(uniqueKeysWithValues: keys.enumerated().map { ($0.element, $0.offset) })
    }

    private var expensePreferredCategoryKeys: [String] {
        [
            "category.expense.food",
            "category.expense.groceries",
            "category.expense.dining",
            "category.expense.coffee",
            "category.expense.home",
            "category.expense.housing",
            "category.expense.bills",
            "category.expense.insurance",
            "category.expense.tax",
            "category.expense.transport",
            "category.expense.travel",
            "category.expense.health",
            "category.expense.personalCare",
            "category.expense.pet",
            "category.expense.education",
            "category.expense.upskilling",
            "category.expense.shopping",
            "category.expense.entertainment",
            "category.expense.subscriptions",
            "category.expense.gifts"
        ]
    }

    private var incomePreferredCategoryKeys: [String] {
        [
            "category.income.salary",
            "category.income.bonus",
            "category.income.freelance",
            "category.income.secondHandSale",
            "category.income.interest",
            "category.income.investment",
            "category.income.governmentSubsidy",
            "category.income.gift",
            "category.income.refund"
        ]
    }

    private func accountTypeDefinitionsByLegacyType() throws -> [AccountType: AccountTypeDefinition] {
        let definitions = try context.fetch(FetchDescriptor<AccountTypeDefinition>())
        return definitions.reduce(into: [:]) { result, definition in
            if let legacyType = definition.legacyType {
                result[legacyType] = definition
            }
        }
    }

    // MARK: - Debug Sample Transaction Seeding

    #if DEBUG
    private func seedDebugSampleTransactions() throws {
        let accounts = try context.fetch(FetchDescriptor<Account>())
        guard let account = accounts.first else { return }

        let categories = try context.fetch(FetchDescriptor<Category>())
        let salary = category(
            matching: "category.income.salary",
            type: .income,
            in: categories
        )
        let freelance = category(
            matching: "category.income.freelance",
            type: .income,
            in: categories
        )
        let dining = category(
            matching: "category.expense.dining",
            type: .expense,
            in: categories
        )
        let groceries = category(
            matching: "category.expense.groceries",
            type: .expense,
            in: categories
        )
        let housing = category(
            matching: "category.expense.housing",
            type: .expense,
            in: categories
        )

        let samples: [(monthOffset: Int, day: Int, amount: Decimal, type: TransactionType, notes: String, category: Category?)] = [
            (-5, 5, 28600, .income, "Sample salary", salary),
            (-5, 8, 4200, .expense, "Sample rent", housing),
            (-5, 15, 920, .expense, "Sample groceries", groceries),
            (-4, 5, 29200, .income, "Sample salary", salary),
            (-4, 12, 1380, .expense, "Sample dining", dining),
            (-3, 5, 29500, .income, "Sample salary", salary),
            (-3, 18, 1680, .expense, "Sample groceries", groceries),
            (-2, 5, 30100, .income, "Sample salary", salary),
            (-2, 21, 2350, .expense, "Sample dining", dining),
            (-1, 5, 31000, .income, "Sample salary", salary),
            (-1, 11, 5200, .income, "Sample freelance", freelance),
            (-1, 22, 4100, .expense, "Sample rent", housing),
            (0, 5, 31800, .income, "Sample salary", salary),
            (0, 14, 1850, .expense, "Sample dining", dining),
            (0, 20, 2400, .expense, "Sample groceries", groceries)
        ]

        for sample in samples {
            let transaction = Transaction(
                amount: sample.amount,
                currencyCode: account.currencyCode,
                type: sample.type,
                date: sampleDate(monthOffset: sample.monthOffset, day: sample.day),
                notes: sample.notes,
                account: account,
                category: sample.category
            )
            context.insert(transaction)
        }
    }

    private func seedDebugSampleBudgets() throws {
        let categories = try context.fetch(FetchDescriptor<Category>())
        let dining = category(
            matching: "category.expense.dining",
            type: .expense,
            in: categories
        )
        let groceries = category(
            matching: "category.expense.groceries",
            type: .expense,
            in: categories
        )
        let housing = category(
            matching: "category.expense.housing",
            type: .expense,
            in: categories
        )

        let samples: [(limit: Decimal, category: Category?)] = [
            (3000, dining),
            (5000, groceries),
            (5200, housing)
        ]

        for sample in samples {
            let budget = Budget(
                limitAmount: sample.limit,
                currencyCode: SupportedCurrency.defaultFromLocale.rawValue,
                period: .monthly,
                category: sample.category
            )
            context.insert(budget)
        }
    }

    private func category(
        matching key: String,
        type: TransactionType,
        in categories: [Category]
    ) -> Category? {
        categories.first { $0.nameKey == key && $0.type == type }
            ?? categories.first { $0.type == type }
    }

    private func sampleDate(monthOffset: Int, day: Int) -> Date {
        let calendar = Calendar.current
        let now = Date.now
        let shifted = calendar.date(byAdding: .month, value: monthOffset, to: now) ?? now
        var components = calendar.dateComponents([.year, .month], from: shifted)
        components.day = day
        components.hour = 12
        return calendar.date(from: components) ?? shifted
    }
    #endif
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
