import Foundation

private struct CurrencyConfig {
    let symbol: String
    let nameKey: String
    let decimalPlaces: Int
}

enum SupportedCurrency: String, Codable, CaseIterable, Hashable, Identifiable {
    case USD
    case EUR
    case GBP
    case JPY
    case CNY
    case TWD
    case HKD
    case KRW
    case SGD
    case AUD
    case CAD
    
    var id: SupportedCurrency { self }
    
    private static let configurations: [SupportedCurrency: CurrencyConfig] = [
        .USD: CurrencyConfig(symbol: "$", nameKey: "currency.USD", decimalPlaces: 2),
        .EUR: CurrencyConfig(symbol: "€", nameKey: "currency.EUR", decimalPlaces: 2),
        .GBP: CurrencyConfig(symbol: "£", nameKey: "currency.GBP", decimalPlaces: 2),
        .JPY: CurrencyConfig(symbol: "¥", nameKey: "currency.JPY", decimalPlaces: 0),
        .CNY: CurrencyConfig(symbol: "¥", nameKey: "currency.CNY", decimalPlaces: 2),
        .TWD: CurrencyConfig(symbol: "NT$", nameKey: "currency.TWD", decimalPlaces: 0),
        .HKD: CurrencyConfig(symbol: "HK$", nameKey: "currency.HKD", decimalPlaces: 2),
        .KRW: CurrencyConfig(symbol: "₩", nameKey: "currency.KRW", decimalPlaces: 0),
        .SGD: CurrencyConfig(symbol: "S$", nameKey: "currency.SGD", decimalPlaces: 2),
        .AUD: CurrencyConfig(symbol: "A$", nameKey: "currency.AUD", decimalPlaces: 2),
        .CAD: CurrencyConfig(symbol: "C$", nameKey: "currency.CAD", decimalPlaces: 2),
    ]
    
    private static let regionToCurrency: [String: SupportedCurrency] = [
        // Americas
        "US": .USD,
        "CA": .CAD,
        
        // Europe
        "GB": .GBP,
        "AT": .EUR, // Austria
        "BE": .EUR, // Belgium
        "CY": .EUR, // Cyprus
        "EE": .EUR, // Estonia
        "FI": .EUR, // Finland
        "FR": .EUR, // France
        "DE": .EUR, // Germany
        "GR": .EUR, // Greece
        "IE": .EUR, // Ireland
        "IT": .EUR, // Italy
        "LV": .EUR, // Latvia
        "LT": .EUR, // Lithuania
        "LU": .EUR, // Luxembourg
        "MT": .EUR, // Malta
        "NL": .EUR, // Netherlands
        "PT": .EUR, // Portugal
        "SK": .EUR, // Slovakia
        "SI": .EUR, // Slovenia
        "ES": .EUR, // Spain
        
        // Asia Pacific
        "JP": .JPY,
        "CN": .CNY,
        "TW": .TWD,
        "HK": .HKD,
        "MO": .HKD, // Macau uses HKD/MOP
        "KR": .KRW,
        "SG": .SGD,
        "AU": .AUD,
        "NZ": .AUD, // NZD not supported, fallback to AUD
    ]
    
    private var config: CurrencyConfig {
        Self.configurations[self]!
    }
    
    var symbol: String { config.symbol }
    
    var localizedName: String {
        AppLocalization.string(
            key: config.nameKey,
            defaultValue: rawValue
        )
    }
    
    var displayName: String { localizedName }
    
    var decimalPlaces: Int { config.decimalPlaces }
    
    static var defaultFromLocale: SupportedCurrency {
        let regionCode = Locale.current.region?.identifier ?? "US"
        return regionToCurrency[regionCode] ?? .USD
    }
}
