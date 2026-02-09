import Foundation

/// Types of financial accounts supported by the app
enum AccountType: String, Codable, CaseIterable {
    case cash
    case bank
    case creditCard
    case investment
    
    var localizedName: String {
        switch self {
        case .cash:
            String(localized: "account.type.cash", defaultValue: "Cash")
        case .bank:
            String(localized: "account.type.bank", defaultValue: "Bank Account")
        case .creditCard:
            String(localized: "account.type.creditCard", defaultValue: "Credit Card")
        case .investment:
            String(localized: "account.type.investment", defaultValue: "Investment")
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .cash: "banknote"
        case .bank: "building.columns"
        case .creditCard: "creditcard"
        case .investment: "chart.line.uptrend.xyaxis"
        }
    }
}
