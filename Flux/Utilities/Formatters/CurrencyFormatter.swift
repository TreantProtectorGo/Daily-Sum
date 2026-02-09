import Foundation
import SwiftUI

/// Utility for formatting currency amounts according to locale and currency settings
struct CurrencyFormatter {
    /// Shared instance for convenience
    static let shared = CurrencyFormatter()
    
    /// Formats an amount with the specified currency code
    func format(
        _ amount: Decimal,
        currencyCode: String,
        locale: Locale = .current,
        showSign: Bool = false
    ) -> String {
        let formatStyle = Decimal.FormatStyle.Currency(
            code: currencyCode,
            locale: locale
        )
        
        var formatted = amount.formatted(formatStyle)
        
        if showSign && amount > 0 {
            formatted = "+" + formatted
        }
        
        return formatted
    }
    
    /// Formats an amount using the supported currency enum
    func format(
        _ amount: Decimal,
        currency: SupportedCurrency,
        locale: Locale = .current,
        showSign: Bool = false
    ) -> String {
        format(amount, currencyCode: currency.rawValue, locale: locale, showSign: showSign)
    }
    
    /// Formats an amount as a signed value with gain/loss coloring
    func attributedFormat(
        _ amount: Decimal,
        currencyCode: String,
        regionalSettings: RegionalSettings = .shared,
        locale: Locale = .current
    ) -> AttributedString {
        let formatted = format(amount, currencyCode: currencyCode, locale: locale, showSign: true)
        var attributed = AttributedString(formatted)
        attributed.foregroundColor = regionalSettings.color(for: amount)
        return attributed
    }
    
    /// Converts and formats an amount from one currency to another
    func formatConverted(
        amount: Decimal,
        from sourceCurrency: Currency,
        to targetCurrency: Currency,
        locale: Locale = .current
    ) -> String {
        let baseAmount = sourceCurrency.convertToBase(amount)
        let convertedAmount = targetCurrency.convertFromBase(baseAmount)
        return format(convertedAmount, currencyCode: targetCurrency.code, locale: locale)
    }
    
    /// Formats a compact version for limited space (e.g., "1.2K", "3.5M")
    func formatCompact(
        _ amount: Decimal,
        currencyCode: String,
        locale: Locale = .current
    ) -> String {
        let number = NSDecimalNumber(decimal: amount).doubleValue
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        
        let absNumber = abs(number)
        let sign = number < 0 ? "-" : ""
        
        let (divisor, suffix): (Double, String) = switch absNumber {
        case 1_000_000_000...:
            (1_000_000_000, "B")
        case 1_000_000...:
            (1_000_000, "M")
        case 1_000...:
            (1_000, "K")
        default:
            (1, "")
        }
        
        let scaledNumber = absNumber / divisor
        formatter.maximumFractionDigits = scaledNumber < 10 ? 1 : 0
        formatter.minimumFractionDigits = 0
        
        if let formatted = formatter.string(from: NSNumber(value: scaledNumber)) {
            // Insert suffix before currency symbol if at end, or after if at start
            return sign + formatted + suffix
        }
        
        return format(amount, currencyCode: currencyCode, locale: locale)
    }
}

// MARK: - View Extension for Currency

extension View {
    /// Applies a currency-formatted text with appropriate gain/loss coloring
    func currencyColored(_ amount: Decimal) -> some View {
        self.foregroundStyle(RegionalSettings.shared.color(for: amount))
    }
}

// MARK: - Text Extension

extension Text {
    /// Creates a Text view with currency formatting
    init(
        currency amount: Decimal,
        code: String,
        showSign: Bool = false
    ) {
        let formatted = CurrencyFormatter.shared.format(
            amount,
            currencyCode: code,
            showSign: showSign
        )
        self.init(formatted)
    }
}
