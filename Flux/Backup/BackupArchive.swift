import Foundation

struct BackupArchive: Codable, Equatable {
    /// Schema v3 makes generated-occurrence posting state and schedule-slot identity part of
    /// backup semantics.
    static let currentSchemaVersion = 3
    static let minimumSupportedSchemaVersion = 1

    var schemaVersion: Int
    var appVersion: String
    var exportedAt: Date
    var exportSourceDevice: String
    var financialData: BackupFinancialData
    var preferences: BackupPreferences
    var integrityMetadata: BackupIntegrityMetadata
}

struct BackupFinancialData: Codable, Equatable {
    var accountTypeDefinitions: [BackupAccountTypeDefinitionRecord]
    var currencies: [BackupCurrencyRecord]
    var exchangeRates: [BackupExchangeRateRecord]
    var categories: [BackupCategoryRecord]
    var accounts: [BackupAccountRecord]
    var transactions: [BackupTransactionRecord]
    var scheduledOccurrenceExceptions: [BackupScheduledOccurrenceExceptionRecord]
    var budgets: [BackupBudgetRecord]

    init(
        accountTypeDefinitions: [BackupAccountTypeDefinitionRecord] = [],
        currencies: [BackupCurrencyRecord] = [],
        exchangeRates: [BackupExchangeRateRecord] = [],
        categories: [BackupCategoryRecord] = [],
        accounts: [BackupAccountRecord] = [],
        transactions: [BackupTransactionRecord] = [],
        scheduledOccurrenceExceptions: [BackupScheduledOccurrenceExceptionRecord] = [],
        budgets: [BackupBudgetRecord] = []
    ) {
        self.accountTypeDefinitions = accountTypeDefinitions
        self.currencies = currencies
        self.exchangeRates = exchangeRates
        self.categories = categories
        self.accounts = accounts
        self.transactions = transactions
        self.scheduledOccurrenceExceptions = scheduledOccurrenceExceptions
        self.budgets = budgets
    }

    private enum CodingKeys: String, CodingKey {
        case accountTypeDefinitions, currencies, exchangeRates, categories, accounts
        case transactions, scheduledOccurrenceExceptions, budgets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountTypeDefinitions = try container.decodeIfPresent(
            [BackupAccountTypeDefinitionRecord].self,
            forKey: .accountTypeDefinitions
        ) ?? []
        currencies = try container.decode([BackupCurrencyRecord].self, forKey: .currencies)
        exchangeRates = try container.decode([BackupExchangeRateRecord].self, forKey: .exchangeRates)
        categories = try container.decode([BackupCategoryRecord].self, forKey: .categories)
        accounts = try container.decode([BackupAccountRecord].self, forKey: .accounts)
        transactions = try container.decode([BackupTransactionRecord].self, forKey: .transactions)
        scheduledOccurrenceExceptions = try container.decode(
            [BackupScheduledOccurrenceExceptionRecord].self,
            forKey: .scheduledOccurrenceExceptions
        )
        budgets = try container.decode([BackupBudgetRecord].self, forKey: .budgets)
    }
}

struct BackupAccountTypeDefinitionRecord: Codable, Equatable {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var isSystemDefault: Bool
    var sortOrder: Int
    var createdAt: Date
    var legacyTypeRawValue: String?
}

struct BackupCurrencyRecord: Codable, Equatable {
    var code: String
    var exchangeRateToBase: Decimal
    var lastUpdated: Date
    var isBaseCurrency: Bool
}

struct BackupExchangeRateRecord: Codable, Equatable {
    var id: UUID
    var baseCurrencyCode: String
    var quoteCurrencyCode: String
    var rate: Decimal
    var effectiveDate: Date
    var fetchedAt: Date
    var provider: String
}

struct BackupCategoryRecord: Codable, Equatable {
    var id: UUID
    var nameKey: String
    var icon: String
    var colorHex: String
    var type: TransactionType
    var isSystemDefault: Bool
    var sortOrder: Int? = nil
    var parentCategoryId: UUID?
}

struct BackupAccountRecord: Codable, Equatable {
    var id: UUID
    var name: String
    var type: AccountType
    var currencyCode: String
    var initialBalance: Decimal
    var icon: String
    var colorHex: String
    var includeInTotal: Bool
    var createdAt: Date
    var typeDefinitionId: UUID? = nil
}

struct BackupTransactionRecord: Codable, Equatable {
    var id: UUID
    var amount: Decimal
    var currencyCode: String
    var type: TransactionType
    var date: Date
    var createdAt: Date? = nil
    var notes: String?
    var isTravelTransaction: Bool?
    var travelAmount: Decimal?
    var travelCurrencyCode: String?
    var travelExchangeRate: Decimal?
    var travelExchangeRateEffectiveDate: Date?
    var travelExchangeRateProvider: String?
    var receiptImageData: Data?
    var isRecurringTemplate: Bool
    var recurrenceRule: RecurrenceRule?
    var schedulePlanTypeRawValue: String?
    var dueDayOfMonth: Int?
    var reminderLeadDays: Int?
    var installmentTotalCount: Int?
    var installmentSequenceNumber: Int?
    var recurringTemplateId: UUID?
    var generatedDate: Date?
    var originalScheduledOccurrenceDate: Date? = nil
    var postingStatusRawValue: String? = nil
    var accountId: UUID?
    var categoryId: UUID?
}

struct BackupScheduledOccurrenceExceptionRecord: Codable, Equatable {
    var id: UUID
    var templateId: UUID
    var occurrenceDate: Date
    var createdAt: Date
}

struct BackupBudgetRecord: Codable, Equatable {
    var id: UUID
    var limitAmount: Decimal
    var currencyCode: String
    var period: BudgetPeriod
    var alertThreshold: Decimal
    var alertsEnabled: Bool
    var alertTrackingPeriodStart: Date?
    var hasSentWarningAlertInTrackedPeriod: Bool
    var hasSentExceededAlertInTrackedPeriod: Bool
    var createdAt: Date
    var isActive: Bool
    var categoryId: UUID?
}

struct BackupRecordCounts: Codable, Equatable {
    var accountTypeDefinitions: Int? = nil
    var currencies: Int
    var exchangeRates: Int
    var categories: Int
    var accounts: Int
    var transactions: Int
    var scheduledOccurrenceExceptions: Int
    var budgets: Int
}

struct BackupIntegrityMetadata: Codable, Equatable {
    var archiveId: UUID
    var contentHash: String
    var recordCounts: BackupRecordCounts
    var createdByBuild: String?
    var compressionFormat: String?
}
