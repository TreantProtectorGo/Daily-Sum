import Foundation
import SwiftData

/// A financial transaction (income or expense)
@Model
final class Transaction {
    #Unique<Transaction>([\.id])
    
    var id: UUID
    
    /// Transaction amount (always positive, type determines direction)
    /// Stored as Decimal with up to 4 decimal places for precision
    var amount: Decimal
    
    /// ISO 4217 currency code (denormalized from account for query performance)
    var currencyCode: String
    
    /// Whether this is income or expense
    var type: TransactionType
    
    /// Transaction date/time in UTC
    var date: Date
    
    /// Optional user notes
    var notes: String?
    
    /// Optional receipt image data (stored as binary)
    @Attribute(.externalStorage)
    var receiptImageData: Data?
    
    /// Whether this is a recurring transaction template
    var isRecurringTemplate: Bool
    
    /// Recurrence rule if this is a recurring transaction
    var recurrenceRule: RecurrenceRule?
    
    /// Reference to the template if this was generated from a recurring transaction
    var recurringTemplateId: UUID?
    
    /// Date when this instance was generated (for recurring transactions)
    var generatedDate: Date?
    
    /// The account this transaction belongs to
    @Relationship(deleteRule: .nullify)
    var account: Account?
    
    /// The category for this transaction
    @Relationship(deleteRule: .nullify)
    var category: Category?
    
    init(
        id: UUID = UUID(),
        amount: Decimal,
        currencyCode: String,
        type: TransactionType,
        date: Date = .now,
        notes: String? = nil,
        receiptImageData: Data? = nil,
        isRecurringTemplate: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        recurringTemplateId: UUID? = nil,
        generatedDate: Date? = nil,
        account: Account? = nil,
        category: Category? = nil
    ) {
        self.id = id
        self.amount = amount
        self.currencyCode = currencyCode
        self.type = type
        self.date = date
        self.notes = notes
        self.receiptImageData = receiptImageData
        self.isRecurringTemplate = isRecurringTemplate
        self.recurrenceRule = recurrenceRule
        self.recurringTemplateId = recurringTemplateId
        self.generatedDate = generatedDate
        self.account = account
        self.category = category
    }
    
    // MARK: - Computed Properties
    
    /// Signed amount (negative for expenses)
    var signedAmount: Decimal {
        switch type {
        case .income: amount
        case .expense: -amount
        }
    }
    
    /// Whether this transaction was auto-generated from a template
    var isGeneratedFromRecurring: Bool {
        recurringTemplateId != nil
    }
    
    /// Currency symbol for display
    var currencySymbol: String {
        SupportedCurrency(rawValue: currencyCode)?.symbol ?? currencyCode
    }
    
    /// Whether this transaction has a receipt attached
    var hasReceipt: Bool {
        receiptImageData != nil
    }
    
    // MARK: - Factory Methods
    
    /// Creates a new transaction instance from a recurring template
    static func fromTemplate(_ template: Transaction, forDate date: Date) -> Transaction {
        Transaction(
            amount: template.amount,
            currencyCode: template.currencyCode,
            type: template.type,
            date: date,
            notes: template.notes,
            isRecurringTemplate: false,
            recurringTemplateId: template.id,
            generatedDate: .now,
            account: template.account,
            category: template.category
        )
    }
}

// MARK: - Transaction Queries

extension Transaction {
    /// Predicate for transactions in a date range
    static func inDateRange(from start: Date, to end: Date) -> Predicate<Transaction> {
        #Predicate<Transaction> { transaction in
            transaction.date >= start && transaction.date < end &&
            !transaction.isRecurringTemplate
        }
    }
    
    /// Predicate for transactions of a specific type
    static func ofType(_ type: TransactionType) -> Predicate<Transaction> {
        let typeRaw = type.rawValue
        return #Predicate<Transaction> { transaction in
            transaction.type.rawValue == typeRaw && !transaction.isRecurringTemplate
        }
    }
    
    /// Predicate for recurring templates only
    static var recurringTemplates: Predicate<Transaction> {
        #Predicate<Transaction> { $0.isRecurringTemplate }
    }
}
