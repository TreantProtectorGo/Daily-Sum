import Foundation
import SwiftData

@MainActor
final class ExchangeRateRefreshScheduler {
    private let refreshInterval: TimeInterval
    private let failureRetryInterval: TimeInterval
    private let provider: any ExchangeRateProvider

    init(
        refreshInterval: TimeInterval = 60 * 60 * 24,
        failureRetryInterval: TimeInterval = 60 * 30,
        provider: (any ExchangeRateProvider)? = nil
    ) {
        self.refreshInterval = refreshInterval
        self.failureRetryInterval = failureRetryInterval
        self.provider = provider ?? HKMAExchangeRateProvider()
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

    func shouldRetryAfterFailure(
        lastFailedAttemptDate: Date?,
        now: Date = .now
    ) -> Bool {
        guard let lastFailedAttemptDate else { return true }
        return now.timeIntervalSince(lastFailedAttemptDate) >= failureRetryInterval
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

        if !force && !shouldRetryAfterFailure(
            lastFailedAttemptDate: ExchangeRateSyncPreference.lastFailedAttemptDate,
            now: now
        ) {
            return false
        }

        let quoteCurrencyCodes = SupportedCurrency.allCases
            .map(\.rawValue)
            .filter { $0 != normalizedBaseCurrencyCode }

        guard !quoteCurrencyCodes.isEmpty else {
            ExchangeRateSyncPreference.lastSuccessfulSyncDate = now
            ExchangeRateSyncPreference.lastFailedAttemptDate = nil
            return false
        }

        let repository = ExchangeRateRepository(
            context: context,
            provider: provider
        )
        do {
            _ = try await repository.refreshLatestRates(
                baseCurrencyCode: normalizedBaseCurrencyCode,
                quoteCurrencyCodes: quoteCurrencyCodes
            )

            ExchangeRateSyncPreference.lastSuccessfulSyncDate = now
            ExchangeRateSyncPreference.lastFailedAttemptDate = nil
            return true
        } catch {
            ExchangeRateSyncPreference.lastFailedAttemptDate = now
            throw error
        }
    }
}
