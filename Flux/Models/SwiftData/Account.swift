import Foundation
import SwiftData
import SwiftUI

/// A financial account (e.g., checking account, credit card, cash wallet)
@Model
final class Account {
    var id: UUID = UUID()
    
    /// User-provided account name
    var name: String = ""
    
    /// Type of account (cash, bank, credit card, investment)
    var type: AccountType = AccountType.cash

    /// User-manageable account type metadata. Falls back to `type` for legacy data.
    var typeDefinition: AccountTypeDefinition?
    
    /// ISO 4217 currency code for this account
    var currencyCode: String = SupportedCurrency.USD.rawValue
    
    /// Initial balance when the account was created (in smallest currency unit)
    var initialBalance: Decimal = 0
    
    /// SF Symbol name for the account icon
    var icon: String = AccountType.cash.defaultIcon
    
    /// Hex color string for the account
    var colorHex: String = "#007AFF"
    
    /// Whether this account is included in totals
    var includeInTotal: Bool = true
    
    /// Date the account was created
    var createdAt: Date = Date()
    
    /// All transactions for this account
    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]? = []
    
    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        currencyCode: String,
        initialBalance: Decimal = 0,
        typeDefinition: AccountTypeDefinition? = nil,
        icon: String? = nil,
        colorHex: String = "#007AFF",
        includeInTotal: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.typeDefinition = typeDefinition
        self.currencyCode = currencyCode
        self.initialBalance = initialBalance
        self.icon = icon ?? typeDefinition?.icon ?? type.defaultIcon
        self.colorHex = typeDefinition?.colorHex ?? colorHex
        self.includeInTotal = includeInTotal
        self.createdAt = createdAt
        self.transactions = []
    }
    
    // MARK: - Computed Properties
    
    /// Parses the hex color into a SwiftUI Color
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    var resolvedTypeName: String {
        typeDefinition?.name ?? type.localizedName
    }

    var resolvedTypeIcon: String {
        typeDefinition?.icon ?? type.icon
    }

    var resolvedTypeColor: Color {
        typeDefinition?.color ?? type.color
    }
    
    /// Calculates the current balance based on initial balance and transactions
    var currentBalance: Decimal {
        let now = Date.now
        let transactionSum = (transactions ?? []).reduce(Decimal.zero) { sum, transaction in
            guard !transaction.isRecurringTemplate, transaction.date <= now else {
                return sum
            }
            switch transaction.type {
            case .income:
                return sum + transaction.amount
            case .expense:
                return sum - transaction.amount
            }
        }
        return initialBalance + transactionSum
    }
    
    /// Gets the supported currency enum if available
    var supportedCurrency: SupportedCurrency? {
        SupportedCurrency(rawValue: currencyCode)
    }
    
    /// Currency symbol for display
    var currencySymbol: String {
        supportedCurrency?.symbol ?? currencyCode
    }
    
    /// Number of transactions in this account
    var transactionCount: Int {
        transactions?.count ?? 0
    }
    
    /// Most recent transaction date
    var lastTransactionDate: Date? {
        transactions?.max(by: { $0.date < $1.date })?.date
    }
}
