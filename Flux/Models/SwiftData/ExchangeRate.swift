import Foundation
import SwiftData

/// Historical FX rate for one currency pair on a specific effective date.
@Model
final class ExchangeRate {
    var id: UUID = UUID()
    var baseCurrencyCode: String = SupportedCurrency.USD.rawValue
    var quoteCurrencyCode: String = SupportedCurrency.USD.rawValue
    var rate: Decimal = 1.0
    var effectiveDate: Date = Date()
    var fetchedAt: Date = Date()
    var provider: String = "unknown"

    init(
        id: UUID = UUID(),
        baseCurrencyCode: String,
        quoteCurrencyCode: String,
        rate: Decimal,
        effectiveDate: Date,
        fetchedAt: Date = .now,
        provider: String = "unknown"
    ) {
        self.id = id
        self.baseCurrencyCode = baseCurrencyCode
        self.quoteCurrencyCode = quoteCurrencyCode
        self.rate = rate
        self.effectiveDate = effectiveDate
        self.fetchedAt = fetchedAt
        self.provider = provider
    }
}
