import Foundation
import SwiftData

/// Represents a currency with exchange rate information
@Model
final class Currency {
    #Unique<Currency>([\.code])
    
    /// ISO 4217 currency code (e.g., "USD", "TWD")
    var code: String
    
    /// Exchange rate to base currency (base currency has rate 1.0)
    var exchangeRateToBase: Decimal
    
    /// Timestamp of last exchange rate update
    var lastUpdated: Date
    
    /// Whether this is the user's base currency
    var isBaseCurrency: Bool
    
    init(
        code: String,
        exchangeRateToBase: Decimal = 1.0,
        lastUpdated: Date = .now,
        isBaseCurrency: Bool = false
    ) {
        self.code = code
        self.exchangeRateToBase = exchangeRateToBase
        self.lastUpdated = lastUpdated
        self.isBaseCurrency = isBaseCurrency
    }
    
    // MARK: - Computed Properties
    
    /// Gets the supported currency enum if available
    var supportedCurrency: SupportedCurrency? {
        SupportedCurrency(rawValue: code)
    }
    
    /// Currency symbol for display
    var symbol: String {
        supportedCurrency?.symbol ?? code
    }
    
    /// Localized display name
    var displayName: String {
        supportedCurrency?.localizedName ?? code
    }
    
    /// Number of decimal places for this currency
    var decimalPlaces: Int {
        supportedCurrency?.decimalPlaces ?? 2
    }
    
    // MARK: - Conversion Methods
    
    /// Converts an amount from this currency to the base currency
    func convertToBase(_ amount: Decimal) -> Decimal {
        amount * exchangeRateToBase
    }
    
    /// Converts an amount from the base currency to this currency
    func convertFromBase(_ baseAmount: Decimal) -> Decimal {
        guard exchangeRateToBase > 0 else { return 0 }
        return baseAmount / exchangeRateToBase
    }
    
    /// Converts an amount from this currency to another currency
    func convert(_ amount: Decimal, to targetCurrency: Currency) -> Decimal {
        let baseAmount = convertToBase(amount)
        return targetCurrency.convertFromBase(baseAmount)
    }
}
