import Foundation
import SwiftData

struct CurrencyConversionQuote {
    let convertedAmount: Decimal
    let rate: Decimal
    let effectiveDate: Date
    let provider: String
}

protocol CurrencyQuoteProviding {
    func convertWithQuote(
        _ amount: Decimal,
        from sourceCurrencyCode: String,
        to targetCurrencyCode: String,
        on date: Date,
        mode: ConversionMode
    ) async throws -> CurrencyConversionQuote
}

@MainActor
final class CurrencyConversionService: CurrencyQuoteProviding {
    private struct RateCacheKey: Hashable {
        let sourceCurrencyCode: String
        let targetCurrencyCode: String
        let date: Date
        let mode: ConversionMode
    }

    private let repository: ExchangeRateRepository
    private var quoteCache: [RateCacheKey: ExchangeRateQuote] = [:]

    init(context: ModelContext, repository: ExchangeRateRepository? = nil) {
        self.repository = repository ?? ExchangeRateRepository(context: context)
    }

    func convert(
        _ amount: Decimal,
        from sourceCurrencyCode: String,
        to targetCurrencyCode: String,
        on date: Date = .now,
        mode: ConversionMode = .latest
    ) async throws -> Decimal {
        try await convertWithQuote(
            amount,
            from: sourceCurrencyCode,
            to: targetCurrencyCode,
            on: date,
            mode: mode
        ).convertedAmount
    }

    func convertWithQuote(
        _ amount: Decimal,
        from sourceCurrencyCode: String,
        to targetCurrencyCode: String,
        on date: Date = .now,
        mode: ConversionMode = .latest
    ) async throws -> CurrencyConversionQuote {
        let source = sourceCurrencyCode.uppercased()
        let target = targetCurrencyCode.uppercased()
        let normalizedDate = mode == .latest ? .distantPast : normalizedDay(date)
        let cacheKey = RateCacheKey(
            sourceCurrencyCode: source,
            targetCurrencyCode: target,
            date: normalizedDate,
            mode: mode
        )

        let rateQuote: ExchangeRateQuote
        if let cached = quoteCache[cacheKey] {
            rateQuote = cached
        } else {
            rateQuote = try await repository.quote(
                from: source,
                to: target,
                on: date,
                mode: mode
            )
            quoteCache[cacheKey] = rateQuote
        }

        let converted = round(amount * rateQuote.rate, currencyCode: target)
        return CurrencyConversionQuote(
            convertedAmount: converted,
            rate: rateQuote.rate,
            effectiveDate: rateQuote.effectiveDate,
            provider: rateQuote.provider
        )
    }

    private func round(_ amount: Decimal, currencyCode: String) -> Decimal {
        let scale = SupportedCurrency(rawValue: currencyCode)?.decimalPlaces ?? 2
        var source = amount
        var destination = Decimal()
        NSDecimalRound(&destination, &source, scale, .bankers)
        return destination
    }

    private func normalizedDay(_ date: Date) -> Date {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return utcCalendar.startOfDay(for: date)
    }
}
