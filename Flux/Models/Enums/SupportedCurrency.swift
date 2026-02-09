import Foundation

/// ISO 4217 currency codes supported by the app
enum SupportedCurrency: String, Codable, CaseIterable, Hashable, Identifiable {
    case USD
    case TWD
    case CNY
    
    var id: SupportedCurrency { self }
    
    var symbol: String {
        switch self {
        case .USD: "$"
        case .TWD: "NT$"
        case .CNY: "¥"
        }
    }

    var flag: String {
        switch self {
        case .USD: "🇺🇸"
        case .TWD: "🇹🇼"
        case .CNY: "🇨🇳"
        }
    }
    
    var localizedName: String {
        switch self {
        case .USD:
            String(localized: "currency.USD", defaultValue: "US Dollar")
        case .TWD:
            String(localized: "currency.TWD", defaultValue: "New Taiwan Dollar")
        case .CNY:
            String(localized: "currency.CNY", defaultValue: "Chinese Yuan")
        }
    }

    var displayName: String {
        localizedName
    }
    
    /// Number of decimal places for this currency (standard)
    var decimalPlaces: Int {
        switch self {
        case .USD: 2
        case .TWD: 0  // TWD typically doesn't use decimals
        case .CNY: 2
        }
    }
    
    /// Returns the default currency based on device locale
    static var defaultFromLocale: SupportedCurrency {
        let regionCode = Locale.current.region?.identifier ?? "US"
        switch regionCode {
        case "TW": return .TWD
        case "CN", "HK", "MO": return .CNY
        default: return .USD
        }
    }
}
