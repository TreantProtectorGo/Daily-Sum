import Foundation
import SwiftData

/// Service for managing Transaction CRUD operations
@MainActor
@Observable
final class TransactionService {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Create
    
    /// Creates a new transaction
    @discardableResult
    func create(
        amount: Decimal,
        type: TransactionType,
        date: Date = .now,
        notes: String? = nil,
        account: Account,
        category: Category?,
        receiptImageData: Data? = nil
    ) throws -> Transaction {
        let transaction = Transaction(
            amount: amount,
            currencyCode: account.currencyCode,
            type: type,
            date: date,
            notes: notes,
            receiptImageData: receiptImageData,
            account: account,
            category: category
        )
        context.insert(transaction)
        try context.save()
        return transaction
    }
    
    /// Creates a recurring transaction template
    @discardableResult
    func createRecurring(
        amount: Decimal,
        type: TransactionType,
        startDate: Date,
        recurrenceRule: RecurrenceRule,
        notes: String? = nil,
        account: Account,
        category: Category?
    ) throws -> Transaction {
        let template = Transaction(
            amount: amount,
            currencyCode: account.currencyCode,
            type: type,
            date: startDate,
            notes: notes,
            isRecurringTemplate: true,
            recurrenceRule: recurrenceRule,
            account: account,
            category: category
        )
        context.insert(template)
        try context.save()
        return template
    }
    
    // MARK: - Read
    
    /// Fetches all transactions (excluding templates) with optional filters
    func fetch(
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        type: TransactionType? = nil,
        account: Account? = nil,
        category: Category? = nil,
        limit: Int? = nil,
        sortDescending: Bool = true
    ) throws -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: sortDescending ? .reverse : .forward)]
        )
        
        // Build predicate
        var predicates: [Predicate<Transaction>] = [
            #Predicate { !$0.isRecurringTemplate }
        ]
        
        if let startDate {
            predicates.append(#Predicate { $0.date >= startDate })
        }
        
        if let endDate {
            predicates.append(#Predicate { $0.date < endDate })
        }
        
        if let type {
            let typeRaw = type.rawValue
            predicates.append(#Predicate { $0.type.rawValue == typeRaw })
        }
        
        if let account {
            let accountId = account.id
            predicates.append(#Predicate { $0.account?.id == accountId })
        }
        
        if let category {
            let categoryId = category.id
            predicates.append(#Predicate { $0.category?.id == categoryId })
        }
        
        // Combine predicates manually (SwiftData limitation)
        // For MVP, we'll use a simpler approach
        descriptor.predicate = #Predicate<Transaction> { !$0.isRecurringTemplate }
        
        if let limit {
            descriptor.fetchLimit = limit
        }
        
        var results = try context.fetch(descriptor)
        
        // Apply additional filters in memory (workaround for complex predicates)
        if let startDate {
            results = results.filter { $0.date >= startDate }
        }
        if let endDate {
            results = results.filter { $0.date < endDate }
        }
        if let type {
            results = results.filter { $0.type == type }
        }
        if let account {
            results = results.filter { $0.account?.id == account.id }
        }
        if let category {
            results = results.filter { $0.category?.id == category.id }
        }
        
        return results
    }
    
    /// Fetches a transaction by ID
    func fetch(byId id: UUID) throws -> Transaction? {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    /// Fetches all recurring templates
    func fetchRecurringTemplates() throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.isRecurringTemplate },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }
    
    // MARK: - Update
    
    /// Updates a transaction
    func update(
        _ transaction: Transaction,
        amount: Decimal? = nil,
        type: TransactionType? = nil,
        date: Date? = nil,
        notes: String? = nil,
        category: Category? = nil,
        receiptImageData: Data? = nil
    ) throws {
        if let amount { transaction.amount = amount }
        if let type { transaction.type = type }
        if let date { transaction.date = date }
        if let notes { transaction.notes = notes }
        if let category { transaction.category = category }
        if let receiptImageData { transaction.receiptImageData = receiptImageData }
        
        try context.save()
    }
    
    // MARK: - Delete
    
    /// Deletes a transaction
    func delete(_ transaction: Transaction) throws {
        context.delete(transaction)
        try context.save()
    }
    
    /// Deletes multiple transactions
    func delete(_ transactions: [Transaction]) throws {
        for transaction in transactions {
            context.delete(transaction)
        }
        try context.save()
    }
    
    // MARK: - Aggregations
    
    /// Calculates total for transactions in a date range
    func total(
        from startDate: Date,
        to endDate: Date,
        type: TransactionType? = nil,
        account: Account? = nil
    ) throws -> Decimal {
        let transactions = try fetch(
            from: startDate,
            to: endDate,
            type: type,
            account: account
        )
        
        return transactions.reduce(Decimal.zero) { sum, tx in
            sum + tx.signedAmount
        }
    }
    
    /// Groups transactions by category for a date range
    func groupedByCategory(
        from startDate: Date,
        to endDate: Date,
        type: TransactionType
    ) throws -> [Category: Decimal] {
        let transactions = try fetch(from: startDate, to: endDate, type: type)
        
        var grouped: [Category: Decimal] = [:]
        for transaction in transactions {
            if let category = transaction.category {
                grouped[category, default: 0] += transaction.amount
            }
        }
        return grouped
    }
}
