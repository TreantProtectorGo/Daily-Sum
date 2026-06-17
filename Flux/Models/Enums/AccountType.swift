import Foundation

/// Types of financial accounts supported by the app
enum AccountType: String, Codable, CaseIterable {
    case cash
    case bank
    case creditCard
    case eWallet
    case investment
    
    var localizedName: String {
        switch self {
        case .cash:
            AppLocalization.string("account.type.cash", defaultValue: "Cash")
        case .bank:
            AppLocalization.string("account.type.bank", defaultValue: "Bank Account")
        case .creditCard:
            AppLocalization.string("account.type.creditCard", defaultValue: "Credit Card")
        case .eWallet:
            AppLocalization.string("account.type.eWallet", defaultValue: "E-wallet")
        case .investment:
            AppLocalization.string("account.type.investment", defaultValue: "Investment")
        }
    }

    var defaultSeedName: String {
        switch self {
        case .cash:
            "Cash"
        case .bank:
            "Bank Account"
        case .creditCard:
            "Credit Card"
        case .eWallet:
            "E-wallet"
        case .investment:
            "Investment"
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .cash: "banknote"
        case .bank: "building.columns"
        case .creditCard: "creditcard"
        case .eWallet: "wallet.bifold"
        case .investment: "chart.line.uptrend.xyaxis"
        }
    }
}
