import Foundation
import SwiftData

@MainActor
final class ExchangeRateRefreshScheduler {
    private let refreshInterval: TimeInterval
    private let provider: any ExchangeRateProvider

    init(
        refreshInterval: TimeInterval = 60 * 60 * 24,
        provider: (any ExchangeRateProvider)? = nil
    ) {
        self.refreshInterval = refreshInterval
        self.provider = provider ?? FrankfurterExchangeRateProvider()
    }

    var providerName: String {
        provider.providerName
    }

    func shouldRefresh(
        lastSuccessfulSyncDate: Date?,
        now: Date = .now
    ) -> Bool {
        guard let lastSuccessfulSyncDate else { return true }
        return now.timeIntervalSince(lastSuccessfulSyncDate) >= refreshInterval
    }

    @discardableResult
    func refreshLatestRatesIfNeeded(
        context: ModelContext,
        baseCurrencyCode: String,
        now: Date = .now,
        force: Bool = false
    ) async throws -> Bool {
        let normalizedBaseCurrencyCode = UserCurrencyPreference.resolvedDisplayCurrencyCode(
            preferredCurrencyCode: baseCurrencyCode
        )

        if !force && !shouldRefresh(
            lastSuccessfulSyncDate: ExchangeRateSyncPreference.lastSuccessfulSyncDate,
            now: now
        ) {
            return false
        }

        let quoteCurrencyCodes = SupportedCurrency.allCases
            .map(\.rawValue)
            .filter { $0 != normalizedBaseCurrencyCode }

        guard !quoteCurrencyCodes.isEmpty else {
            ExchangeRateSyncPreference.lastSuccessfulSyncDate = now
            return false
        }

        let repository = ExchangeRateRepository(
            context: context,
            provider: provider
        )
        _ = try await repository.refreshLatestRates(
            baseCurrencyCode: normalizedBaseCurrencyCode,
            quoteCurrencyCodes: quoteCurrencyCodes
        )

        ExchangeRateSyncPreference.lastSuccessfulSyncDate = now
        return true
    }
}
