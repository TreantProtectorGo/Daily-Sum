import Foundation
import SwiftData

/// Service for managing Account CRUD operations
@MainActor
@Observable
final class AccountService {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Create
    
    /// Creates a new account
    @discardableResult
    func create(
        name: String,
        type: AccountType,
        currencyCode: String,
        initialBalance: Decimal = 0,
        icon: String? = nil,
        colorHex: String = "#007AFF",
        includeInTotal: Bool = true
    ) throws -> Account {
        let account = Account(
            name: name,
            type: type,
            currencyCode: currencyCode,
            initialBalance: initialBalance,
            icon: icon,
            colorHex: colorHex,
            includeInTotal: includeInTotal
        )
        context.insert(account)
        try context.save()
        return account
    }
    
    // MARK: - Read
    
    /// Fetches all accounts
    func fetch(includeArchived: Bool = false) throws -> [Account] {
        var descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.name)]
        )
        
        if !includeArchived {
            descriptor.predicate = #Predicate { !$0.isArchived }
        }
        
        return try context.fetch(descriptor)
    }
    
    /// Fetches accounts of a specific type
    func fetch(type: AccountType, includeArchived: Bool = false) throws -> [Account] {
        let typeRaw = type.rawValue
        var descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.type.rawValue == typeRaw },
            sortBy: [SortDescriptor(\.name)]
        )
        
        var results = try context.fetch(descriptor)
        
        if !includeArchived {
            results = results.filter { !$0.isArchived }
        }
        
        return results
    }
    
    /// Fetches an account by ID
    func fetch(byId id: UUID) throws -> Account? {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    // MARK: - Update
    
    /// Updates an account
    func update(
        _ account: Account,
        name: String? = nil,
        icon: String? = nil,
        colorHex: String? = nil,
        includeInTotal: Bool? = nil
    ) throws {
        if let name { account.name = name }
        if let icon { account.icon = icon }
        if let colorHex { account.colorHex = colorHex }
        if let includeInTotal { account.includeInTotal = includeInTotal }
        
        try context.save()
    }
    
    /// Archives an account (hides from main views but preserves data)
    func archive(_ account: Account) throws {
        account.isArchived = true
        try context.save()
    }
    
    /// Unarchives an account
    func unarchive(_ account: Account) throws {
        account.isArchived = false
        try context.save()
    }
    
    // MARK: - Delete
    
    /// Deletes an account and all its transactions
    func delete(_ account: Account) throws {
        context.delete(account)
        try context.save()
    }
    
    // MARK: - Aggregations
    
    /// Calculates total balance across all accounts (in base currency)
    func totalBalance(convertToBase: Bool = true) throws -> Decimal {
        let accounts = try fetch(includeArchived: false)
            .filter { $0.includeInTotal }
        
        if !convertToBase {
            // Just sum (only valid if all same currency)
            return accounts.reduce(Decimal.zero) { $0 + $1.currentBalance }
        }
        
        // Convert to base currency
        let currencies = try context.fetch(FetchDescriptor<Currency>())
        let currencyMap = Dictionary(uniqueKeysWithValues: currencies.map { ($0.code, $0) })
        
        return accounts.reduce(Decimal.zero) { sum, account in
            let balance = account.currentBalance
            if let currency = currencyMap[account.currencyCode] {
                return sum + currency.convertToBase(balance)
            }
            return sum + balance
        }
    }
    
    /// Groups accounts by type with their balances
    func balancesByType() throws -> [AccountType: Decimal] {
        let accounts = try fetch(includeArchived: false)
        
        var result: [AccountType: Decimal] = [:]
        for account in accounts where account.includeInTotal {
            result[account.type, default: 0] += account.currentBalance
        }
        return result
    }
}
