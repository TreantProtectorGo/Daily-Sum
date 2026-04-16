import Foundation
import SwiftData

enum AccountServiceError: LocalizedError, Equatable {
    case cannotChangeCurrencyWithTravelTransactions

    var errorDescription: String? {
        switch self {
        case .cannotChangeCurrencyWithTravelTransactions:
            return AppLocalization.string(
                "account.error.travelCurrencyChangeUnsupported",
                defaultValue: "This account has travel transactions. Create a new account instead of changing its currency."
            )
        }
    }
}

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
    func fetch() throws -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Fetches accounts of a specific type
    func fetch(type: AccountType) throws -> [Account] {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.type.rawValue == typeRaw },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
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
        type: AccountType? = nil,
        currencyCode: String? = nil,
        initialBalance: Decimal? = nil,
        icon: String? = nil,
        colorHex: String? = nil,
        includeInTotal: Bool? = nil
    ) throws {
        let previousCurrencyCode = account.currencyCode

        if let currencyCode,
           currencyCode != previousCurrencyCode,
           (account.transactions ?? []).contains(where: { $0.resolvedTravelSnapshot != nil }) {
            throw AccountServiceError.cannotChangeCurrencyWithTravelTransactions
        }
        
        if let name { account.name = name }
        if let type { account.type = type }
        if let currencyCode { account.currencyCode = currencyCode }
        if let initialBalance { account.initialBalance = initialBalance }
        if let icon { account.icon = icon }
        if let colorHex { account.colorHex = colorHex }
        if let includeInTotal { account.includeInTotal = includeInTotal }
        
        if account.currencyCode != previousCurrencyCode {
            for transaction in account.transactions ?? [] {
                transaction.currencyCode = account.currencyCode
            }
        }
        
        try context.save()
    }
    
    /// Adjusts an account to a target current balance by creating a transaction delta.
    /// This preserves historical income/expense totals and auditability.
    @discardableResult
    func adjustCurrentBalance(
        _ account: Account,
        to targetBalance: Decimal,
        date: Date = .now,
        note: String? = nil
    ) throws -> Transaction? {
        let delta = targetBalance - account.currentBalance
        guard delta != .zero else { return nil }
        
        let adjustmentType: TransactionType = delta > 0 ? .income : .expense
        let adjustmentAmount = delta > 0 ? delta : -delta
        
        let transactionService = TransactionService(context: context)
        return try transactionService.create(
            amount: adjustmentAmount,
            type: adjustmentType,
            date: date,
            notes: note,
            account: account,
            category: nil
        )
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
        let accounts = try fetch()
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
        let accounts = try fetch()
        
        var result: [AccountType: Decimal] = [:]
        for account in accounts where account.includeInTotal {
            result[account.type, default: 0] += account.currentBalance
        }
        return result
    }
}
