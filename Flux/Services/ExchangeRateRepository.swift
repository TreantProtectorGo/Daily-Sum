import Foundation
import SwiftData

@MainActor
final class ExchangeRateRepository {
    enum Error: LocalizedError {
        case missingRatePair(base: String, quote: String)

        var errorDescription: String? {
            switch self {
            case .missingRatePair(let base, let quote):
                return "No exchange rate available for \(base) to \(quote)."
            }
        }
    }

    private let context: ModelContext
    private let provider: any ExchangeRateProvider

    init(
        context: ModelContext,
        provider: any ExchangeRateProvider = FrankfurterExchangeRateProvider()
    ) {
        self.context = context
        self.provider = provider
    }

    @discardableResult
    func refreshLatestRates(
        baseCurrencyCode: String,
        quoteCurrencyCodes: [String]
    ) async throws -> Date {
        let snapshot = try await provider.fetchRates(
            baseCurrencyCode: baseCurrencyCode,
            quoteCurrencyCodes: quoteCurrencyCodes,
            on: nil
        )
        try upsert(snapshot)
        return snapshot.effectiveDate
    }

    func rate(
        from sourceCurrencyCode: String,
        to targetCurrencyCode: String,
        on date: Date,
        mode: ConversionMode
    ) async throws -> Decimal {
        let source = sourceCurrencyCode.uppercased()
        let target = targetCurrencyCode.uppercased()
        if source == target {
            return 1
        }

        let normalizedDate = normalizedDay(date)

        if let rate = try storedRate(
            baseCurrencyCode: source,
            quoteCurrencyCode: target,
            on: normalizedDate,
            mode: mode
        ) {
            return rate
        }

        if let inverseRate = try storedRate(
            baseCurrencyCode: target,
            quoteCurrencyCode: source,
            on: normalizedDate,
            mode: mode
        ), inverseRate > 0 {
            return 1 / inverseRate
        }

        let snapshot = try await provider.fetchRates(
            baseCurrencyCode: source,
            quoteCurrencyCodes: [target],
            on: mode == .historical ? normalizedDate : nil
        )
        try upsert(snapshot)

        if let rate = try storedRate(
            baseCurrencyCode: source,
            quoteCurrencyCode: target,
            on: normalizedDate,
            mode: mode
        ) {
            return rate
        }

        if let inverseRate = try storedRate(
            baseCurrencyCode: target,
            quoteCurrencyCode: source,
            on: normalizedDate,
            mode: mode
        ), inverseRate > 0 {
            return 1 / inverseRate
        }

        throw Error.missingRatePair(base: source, quote: target)
    }

    private func storedRate(
        baseCurrencyCode: String,
        quoteCurrencyCode: String,
        on date: Date,
        mode: ConversionMode
    ) throws -> Decimal? {
        var descriptor: FetchDescriptor<ExchangeRate>

        switch mode {
        case .latest:
            descriptor = FetchDescriptor<ExchangeRate>(
                predicate: #Predicate<ExchangeRate> {
                    $0.baseCurrencyCode == baseCurrencyCode &&
                    $0.quoteCurrencyCode == quoteCurrencyCode
                },
                sortBy: [SortDescriptor(\ExchangeRate.effectiveDate, order: .reverse)]
            )
        case .historical:
            var utcCalendar = Calendar(identifier: .gregorian)
            utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let nextDay = utcCalendar.date(
                byAdding: .day,
                value: 1,
                to: date
            ) ?? date
            descriptor = FetchDescriptor<ExchangeRate>(
                predicate: #Predicate<ExchangeRate> {
                    $0.baseCurrencyCode == baseCurrencyCode &&
                    $0.quoteCurrencyCode == quoteCurrencyCode &&
                    $0.effectiveDate < nextDay
                },
                sortBy: [SortDescriptor(\ExchangeRate.effectiveDate, order: .reverse)]
            )
        }

        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.rate
    }

    private func upsert(_ snapshot: ExchangeRateSnapshot) throws {
        let effectiveDate = normalizedDay(snapshot.effectiveDate)

        for (quoteCurrencyCode, rate) in snapshot.rates where rate > 0 {
            try upsertRate(
                baseCurrencyCode: snapshot.baseCurrencyCode.uppercased(),
                quoteCurrencyCode: quoteCurrencyCode.uppercased(),
                rate: rate,
                effectiveDate: effectiveDate,
                fetchedAt: .now,
                provider: snapshot.provider
            )

            let inverseRate = 1 / rate
            try upsertRate(
                baseCurrencyCode: quoteCurrencyCode.uppercased(),
                quoteCurrencyCode: snapshot.baseCurrencyCode.uppercased(),
                rate: inverseRate,
                effectiveDate: effectiveDate,
                fetchedAt: .now,
                provider: snapshot.provider
            )
        }

        try context.save()
    }

    private func upsertRate(
        baseCurrencyCode: String,
        quoteCurrencyCode: String,
        rate: Decimal,
        effectiveDate: Date,
        fetchedAt: Date,
        provider: String
    ) throws {
        var descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate<ExchangeRate> {
                $0.baseCurrencyCode == baseCurrencyCode &&
                $0.quoteCurrencyCode == quoteCurrencyCode &&
                $0.effectiveDate == effectiveDate
            }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.rate = rate
            existing.fetchedAt = fetchedAt
            existing.provider = provider
            return
        }

        context.insert(
            ExchangeRate(
                baseCurrencyCode: baseCurrencyCode,
                quoteCurrencyCode: quoteCurrencyCode,
                rate: rate,
                effectiveDate: effectiveDate,
                fetchedAt: fetchedAt,
                provider: provider
            )
        )
    }

    private func normalizedDay(_ date: Date) -> Date {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return utcCalendar.startOfDay(for: date)
    }
}
