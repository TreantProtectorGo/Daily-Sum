import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ExchangeCalculatorViewModel {
    private let conversionService: any CurrencyQuoteProviding
    private let locationService: any TravelCurrencyLocationServicing
    private let preferredCurrencyCode: String
    private let useLocationDefaults: Bool
    private let debounceDuration: Duration

    private var conversionTask: Task<Void, Never>?
    private var hasInitializedDefaults = false

    var amount: Decimal = 1
    var fromCurrencyCode: String
    var toCurrencyCode: String

    var convertedAmount: Decimal?
    var exchangeRate: Decimal?
    var effectiveDate: Date?
    var provider: String?

    var isLoading = false
    var errorMessage: String?

    init(
        modelContext: ModelContext,
        conversionService: (any CurrencyQuoteProviding)? = nil,
        locationService: (any TravelCurrencyLocationServicing)? = nil,
        preferredCurrencyCode: String? = nil,
        useLocationDefaults: Bool? = nil,
        debounceDuration: Duration = .milliseconds(300)
    ) {
        self.conversionService = conversionService ?? CurrencyConversionService(context: modelContext)
        self.locationService = locationService ?? TravelCurrencyLocationService()
        let resolvedPreferredCurrencyCode = preferredCurrencyCode
            ?? UserCurrencyPreference.resolvedCurrencyCode
        self.preferredCurrencyCode = UserCurrencyPreference.resolvedDisplayCurrencyCode(
            preferredCurrencyCode: resolvedPreferredCurrencyCode
        )
        self.useLocationDefaults = useLocationDefaults
            ?? TravelCurrencyPreference.useLocationDefaults
        self.debounceDuration = debounceDuration

        self.fromCurrencyCode = self.preferredCurrencyCode
        self.toCurrencyCode = "USD"
    }

    func initializeDefaults() async {
        guard !hasInitializedDefaults else {
            return
        }
        hasInitializedDefaults = true

        fromCurrencyCode = preferredCurrencyCode

        var targetCurrencyCode = "USD"
        if useLocationDefaults,
           locationService.authorizationStatus() == .authorized,
           let detected = await locationService.detectLocalCurrency(),
           detected.rawValue != fromCurrencyCode {
            targetCurrencyCode = detected.rawValue
        }

        toCurrencyCode = resolvedTargetCurrency(
            sourceCurrencyCode: fromCurrencyCode,
            targetCurrencyCode: targetCurrencyCode
        )

        scheduleCalculation()
    }

    func scheduleCalculation() {
        startCalculation(debounced: true)
    }

    func retry() {
        startCalculation(debounced: false)
    }

    func swapCurrencies() {
        (fromCurrencyCode, toCurrencyCode) = (toCurrencyCode, fromCurrencyCode)
        scheduleCalculation()
    }

    private func startCalculation(debounced: Bool) {
        conversionTask?.cancel()

        let amount = self.amount
        let sourceCurrencyCode = fromCurrencyCode.uppercased()
        let targetCurrencyCode = toCurrencyCode.uppercased()

        guard !sourceCurrencyCode.isEmpty, !targetCurrencyCode.isEmpty else {
            return
        }

        conversionTask = Task { [weak self] in
            guard let self else { return }

            if debounced {
                try? await Task.sleep(for: debounceDuration)
                guard !Task.isCancelled else { return }
            }

            await performCalculation(
                amount: amount,
                sourceCurrencyCode: sourceCurrencyCode,
                targetCurrencyCode: targetCurrencyCode
            )
        }
    }

    private func performCalculation(
        amount: Decimal,
        sourceCurrencyCode: String,
        targetCurrencyCode: String
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let quote = try await conversionService.convertWithQuote(
                amount,
                from: sourceCurrencyCode,
                to: targetCurrencyCode,
                on: .now,
                mode: .latest
            )

            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            convertedAmount = quote.convertedAmount
            exchangeRate = quote.rate
            effectiveDate = quote.effectiveDate
            provider = quote.provider
        } catch is CancellationError {
            return
        } catch {
            convertedAmount = nil
            exchangeRate = nil
            effectiveDate = nil
            provider = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func resolvedTargetCurrency(
        sourceCurrencyCode: String,
        targetCurrencyCode: String
    ) -> String {
        guard sourceCurrencyCode == targetCurrencyCode else {
            return targetCurrencyCode
        }

        return SupportedCurrency.allCases
            .first(where: { $0.rawValue != sourceCurrencyCode })?
            .rawValue
            ?? targetCurrencyCode
    }
}
