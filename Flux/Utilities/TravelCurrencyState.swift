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
        useLocationDefaults: Bool,
        detectedCurrencyCode: String?,
        manualTravelCurrencyCode: String?
    ) -> ResolvedTravelCurrencyState {
        let normalizedDefaultCurrencyCode = normalizedCurrencyCode(defaultCurrencyCode)
        let normalizedDetectedCurrencyCode = normalizedCurrencyCode(detectedCurrencyCode)
        let normalizedManualTravelCurrencyCode = normalizedCurrencyCode(manualTravelCurrencyCode)

        let automaticTravelCurrencyCode: String?
        if useLocationDefaults,
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
        accountCurrencyCode: String?,
        currentTravelCurrencyCode: String?,
        userOverride: Bool?
    ) -> Bool {
        guard transactionType == .expense else {
            return false
        }

        if let userOverride {
            return userOverride
        }

        guard let normalizedAccountCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(
            accountCurrencyCode
        ),
        let normalizedCurrentTravelCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(
            currentTravelCurrencyCode
        ) else {
            return false
        }

        return normalizedAccountCurrencyCode == normalizedCurrentTravelCurrencyCode
    }
}
