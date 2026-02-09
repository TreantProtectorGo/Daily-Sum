import Foundation

/// Represents the type of financial transaction
enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense
    
    var localizedName: String {
        switch self {
        case .income:
            String(localized: "transaction.type.income", defaultValue: "Income")
        case .expense:
            String(localized: "transaction.type.expense", defaultValue: "Expense")
        }
    }
}
