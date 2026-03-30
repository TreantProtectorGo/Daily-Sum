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

    /// Whether this transaction should be treated as a travel transaction.
    var isTravelTransaction: Bool?

    /// Original travel-side amount entered by the user.
    var travelAmount: Decimal?

    /// Original travel-side ISO 4217 currency code.
    var travelCurrencyCode: String?

    /// Account currency amount for one unit of travel currency.
    var travelExchangeRate: Decimal?

    /// Date of the locked exchange rate snapshot.
    var travelExchangeRateEffectiveDate: Date?

    /// Exchange-rate provider used to create the snapshot.
    var travelExchangeRateProvider: String?
    
    /// Optional receipt image data (stored as binary)
    @Attribute(.externalStorage)
    var receiptImageData: Data?
    
    /// Whether this is a scheduled transaction template
    var isRecurringTemplate: Bool
    
    /// Recurrence rule if this is a scheduled transaction template
    var recurrenceRule: RecurrenceRule?

    /// Stored raw value for scheduled plan type.
    var schedulePlanTypeRawValue: String?

    /// Monthly due day anchor used by scheduled templates (1...31)
    var dueDayOfMonth: Int?

    /// Reminder lead time in days for scheduled plans
    var reminderLeadDays: Int?

    /// Legacy installment metadata kept for migration compatibility.
    var installmentTotalCount: Int?

    /// Legacy installment sequence kept for migration compatibility.
    var installmentSequenceNumber: Int?

    /// Reference to the template if this was generated from a scheduled transaction
    var recurringTemplateId: UUID?
    
    /// Date when this instance was generated (for scheduled transactions)
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
        isTravelTransaction: Bool? = nil,
        travelAmount: Decimal? = nil,
        travelCurrencyCode: String? = nil,
        travelExchangeRate: Decimal? = nil,
        travelExchangeRateEffectiveDate: Date? = nil,
        travelExchangeRateProvider: String? = nil,
        receiptImageData: Data? = nil,
        isRecurringTemplate: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        schedulePlanType: SchedulePlanType? = nil,
        dueDayOfMonth: Int? = nil,
        reminderLeadDays: Int? = nil,
        installmentTotalCount: Int? = nil,
        installmentSequenceNumber: Int? = nil,
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
        self.isTravelTransaction = isTravelTransaction
        self.travelAmount = travelAmount
        self.travelCurrencyCode = travelCurrencyCode
        self.travelExchangeRate = travelExchangeRate
        self.travelExchangeRateEffectiveDate = travelExchangeRateEffectiveDate
        self.travelExchangeRateProvider = travelExchangeRateProvider
        self.receiptImageData = receiptImageData
        self.isRecurringTemplate = isRecurringTemplate
        self.recurrenceRule = recurrenceRule
        self.schedulePlanTypeRawValue = schedulePlanType?.rawValue
        self.dueDayOfMonth = dueDayOfMonth
        self.reminderLeadDays = reminderLeadDays
        self.installmentTotalCount = installmentTotalCount
        self.installmentSequenceNumber = installmentSequenceNumber
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

    var resolvedSchedulePlanType: SchedulePlanType? {
        if let schedulePlanType {
            return schedulePlanType
        }
        if isRecurringTemplate || isGeneratedFromRecurring {
            return .recurring
        }
        return nil
    }

    var isUpcoming: Bool {
        date > .now
    }

    var isFutureGeneratedScheduled: Bool {
        isGeneratedFromRecurring && isUpcoming
    }

    var schedulePlanType: SchedulePlanType? {
        get {
            guard let schedulePlanTypeRawValue else { return nil }
            return SchedulePlanType(rawValue: schedulePlanTypeRawValue)
        }
        set {
            schedulePlanTypeRawValue = newValue?.rawValue
        }
    }

    /// Currency symbol for display
    var currencySymbol: String {
        SupportedCurrency(rawValue: currencyCode)?.symbol ?? currencyCode
    }

    var resolvedTravelSnapshot: TravelTransactionSnapshot? {
        TravelTransactionSnapshots.snapshot(from: self)
    }
    
    /// Whether this transaction has a receipt attached
    var hasReceipt: Bool {
        receiptImageData != nil
    }
    
    // MARK: - Factory Methods
    
    /// Creates a new transaction instance from a scheduled template
    static func fromTemplate(
        _ template: Transaction,
        forDate date: Date,
        installmentSequenceNumber: Int? = nil
    ) -> Transaction {
        Transaction(
            amount: template.amount,
            currencyCode: template.currencyCode,
            type: template.type,
            date: date,
            notes: template.notes,
            isTravelTransaction: template.isTravelTransaction,
            travelAmount: template.travelAmount,
            travelCurrencyCode: template.travelCurrencyCode,
            travelExchangeRate: template.travelExchangeRate,
            travelExchangeRateEffectiveDate: template.travelExchangeRateEffectiveDate,
            travelExchangeRateProvider: template.travelExchangeRateProvider,
            isRecurringTemplate: false,
            recurrenceRule: template.recurrenceRule,
            schedulePlanType: template.resolvedSchedulePlanType,
            dueDayOfMonth: template.dueDayOfMonth,
            reminderLeadDays: template.reminderLeadDays,
            installmentTotalCount: template.installmentTotalCount,
            installmentSequenceNumber: installmentSequenceNumber,
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
