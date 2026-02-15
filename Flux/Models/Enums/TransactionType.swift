import Foundation

/// Represents the type of financial transaction
enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense
    
    var localizedName: String {
        switch self {
        case .income:
            AppLocalization.string("transaction.type.income", defaultValue: "Income")
        case .expense:
            AppLocalization.string("transaction.type.expense", defaultValue: "Expense")
        }
    }
}
