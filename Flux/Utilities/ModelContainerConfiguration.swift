import Foundation
import SwiftData

enum ModelContainerConfiguration {
    static let cloudKitContainerIdentifier = "iCloud.com.aegis.flux"

    static let modelTypes: [any PersistentModel.Type] = [
        Currency.self,
        ExchangeRate.self,
        Category.self,
        Account.self,
        Transaction.self,
        ScheduledOccurrenceException.self,
        Budget.self
    ]
    
    @MainActor
    static func createContainer(enableCloudKit: Bool = false) throws -> ModelContainer {
        try ensureApplicationSupportDirectoryExists()

        let schema = Schema(modelTypes)
        
        let configuration: ModelConfiguration
        if enableCloudKit {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }
        
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    @MainActor
    static func createTestContainer() throws -> ModelContainer {
        let schema = Schema(modelTypes)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    @MainActor
    static func createPreviewContainer() throws -> ModelContainer {
        let container = try createTestContainer()
        let context = container.mainContext
        
        try seedPreviewData(in: context)
        
        return container
    }
    
    @MainActor
    private static func seedPreviewData(in context: ModelContext) throws {
        let usd = Currency(code: "USD", isBaseCurrency: true)
        context.insert(usd)
        
        let food = Category(
            nameKey: "category.expense.food",
            icon: "fork.knife",
            colorHex: "#FF6B6B",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(food)
        
        let salary = Category(
            nameKey: "category.income.salary",
            icon: "banknote",
            colorHex: "#4ECDC4",
            type: .income,
            isSystemDefault: true
        )
        context.insert(salary)
        
        let wallet = Account(
            name: "Cash Wallet",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 500
        )
        context.insert(wallet)
        
        let transaction1 = Transaction(
            amount: 25.50,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            notes: "Lunch with colleagues",
            account: wallet,
            category: food
        )
        context.insert(transaction1)
        
        let transaction2 = Transaction(
            amount: 3000,
            currencyCode: "USD",
            type: .income,
            date: Calendar.current.date(byAdding: .day, value: -5, to: .now)!,
            notes: "Monthly salary",
            account: wallet,
            category: salary
        )
        context.insert(transaction2)
        
        try context.save()
    }

    private static func ensureApplicationSupportDirectoryExists() throws {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        if !fileManager.fileExists(atPath: appSupportURL.path) {
            try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        }
    }
}
