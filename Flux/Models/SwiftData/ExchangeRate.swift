import Foundation
import SwiftData

/// Historical FX rate for one currency pair on a specific effective date.
@Model
final class ExchangeRate {
    #Unique<ExchangeRate>([\.baseCurrencyCode, \.quoteCurrencyCode, \.effectiveDate])

    var id: UUID
    var baseCurrencyCode: String
    var quoteCurrencyCode: String
    var rate: Decimal
    var effectiveDate: Date
    var fetchedAt: Date
    var provider: String

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
