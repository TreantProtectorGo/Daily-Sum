import Foundation
import SwiftData
import SwiftUI

/// A financial account (e.g., checking account, credit card, cash wallet)
@Model
final class Account {
    #Unique<Account>([\.id])
    
    var id: UUID
    
    /// User-provided account name
    var name: String
    
    /// Type of account (cash, bank, credit card, investment)
    var type: AccountType
    
    /// ISO 4217 currency code for this account
    var currencyCode: String
    
    /// Initial balance when the account was created (in smallest currency unit)
    var initialBalance: Decimal
    
    /// SF Symbol name for the account icon
    var icon: String
    
    /// Hex color string for the account
    var colorHex: String
    
    /// Whether this account is included in totals
    var includeInTotal: Bool
    
    /// Date the account was created
    var createdAt: Date
    
    /// All transactions for this account
    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]
    
    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        currencyCode: String,
        initialBalance: Decimal = 0,
        icon: String? = nil,
        colorHex: String = "#007AFF",
        includeInTotal: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.currencyCode = currencyCode
        self.initialBalance = initialBalance
        self.icon = icon ?? type.defaultIcon
        self.colorHex = colorHex
        self.includeInTotal = includeInTotal
        self.createdAt = createdAt
        self.transactions = []
    }
    
    // MARK: - Computed Properties
    
    /// Parses the hex color into a SwiftUI Color
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
    
    /// Calculates the current balance based on initial balance and transactions
    var currentBalance: Decimal {
        let now = Date.now
        let transactionSum = transactions.reduce(Decimal.zero) { sum, transaction in
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
        transactions.count
    }
    
    /// Most recent transaction date
    var lastTransactionDate: Date? {
        transactions.max(by: { $0.date < $1.date })?.date
    }
}
