import Foundation

struct ResolvedTravelCurrencyState: Equatable {
    let detectedLocationCurrencyCode: String?
    let currentTravelCurrencyCode: String?
}

enum TravelCurrencyState {
    static func normalizedCurrencyCode(_ currencyCode: String?) -> String? {
        guard let currencyCode else { return nil }
        let normalized = currencyCode.uppercased()
        guard SupportedCurrency(rawValue: normalized) != nil else {
            return nil
        }
        return normalized
    }

    static func resolve(
        defaultCurrencyCode: String,
        source: TravelCurrencySource,
        detectedCurrencyCode: String?,
        manualTravelCurrencyCode: String?
    ) -> ResolvedTravelCurrencyState {
        let normalizedDefaultCurrencyCode = normalizedCurrencyCode(defaultCurrencyCode)
        let normalizedDetectedCurrencyCode = normalizedCurrencyCode(detectedCurrencyCode)
        let normalizedManualTravelCurrencyCode = normalizedCurrencyCode(manualTravelCurrencyCode)

        let automaticTravelCurrencyCode: String?
        if source == .automatic,
           normalizedDetectedCurrencyCode != nil,
           normalizedDetectedCurrencyCode != normalizedDefaultCurrencyCode {
            automaticTravelCurrencyCode = normalizedDetectedCurrencyCode
        } else {
            automaticTravelCurrencyCode = nil
        }

        let currentTravelCurrencyCode: String?
        if let normalizedManualTravelCurrencyCode {
            if normalizedManualTravelCurrencyCode == normalizedDefaultCurrencyCode {
                currentTravelCurrencyCode = nil
            } else {
                currentTravelCurrencyCode = normalizedManualTravelCurrencyCode
            }
        } else {
            currentTravelCurrencyCode = automaticTravelCurrencyCode
        }

        return ResolvedTravelCurrencyState(
            detectedLocationCurrencyCode: normalizedDetectedCurrencyCode,
            currentTravelCurrencyCode: currentTravelCurrencyCode
        )
    }
}

enum TransactionTravelDefaults {
    static func resolveIsTravelTransaction(
        transactionType: TransactionType,
        currentTravelCurrencyCode: String?,
        userOverride: Bool?
    ) -> Bool {
        guard transactionType == .expense else {
            return false
        }

        if let userOverride {
            return userOverride
        }

        return TravelCurrencyState.normalizedCurrencyCode(
            currentTravelCurrencyCode
        ) != nil
    }
}
