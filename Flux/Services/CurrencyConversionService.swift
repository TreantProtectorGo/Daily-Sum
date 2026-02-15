import Foundation
import SwiftData

@MainActor
final class CurrencyConversionService {
    private struct RateCacheKey: Hashable {
        let sourceCurrencyCode: String
        let targetCurrencyCode: String
        let date: Date
        let mode: ConversionMode
    }

    private let repository: ExchangeRateRepository
    private var rateCache: [RateCacheKey: Decimal] = [:]

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
        let source = sourceCurrencyCode.uppercased()
        let target = targetCurrencyCode.uppercased()
        let normalizedDate = mode == .latest ? .distantPast : normalizedDay(date)
        let cacheKey = RateCacheKey(
            sourceCurrencyCode: source,
            targetCurrencyCode: target,
            date: normalizedDate,
            mode: mode
        )

        let rate: Decimal
        if let cached = rateCache[cacheKey] {
            rate = cached
        } else {
            rate = try await repository.rate(
                from: source,
                to: target,
                on: date,
                mode: mode
            )
            rateCache[cacheKey] = rate
        }

        let converted = amount * rate
        return round(converted, currencyCode: target)
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
