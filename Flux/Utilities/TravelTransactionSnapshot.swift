import Foundation

struct TravelTransactionSnapshot: Equatable {
    let travelAmount: Decimal
    let travelCurrencyCode: String
    let accountAmount: Decimal
    let accountCurrencyCode: String
    let exchangeRate: Decimal
    let effectiveDate: Date
    let provider: String
}

enum TravelTransactionRounding {
    static func round(_ amount: Decimal, currencyCode: String) -> Decimal {
        let scale = SupportedCurrency(rawValue: currencyCode)?.decimalPlaces ?? 2
        var source = amount
        var destination = Decimal()
        NSDecimalRound(&destination, &source, scale, .bankers)
        return destination
    }
}

enum TravelTransactionSnapshots {
    static func snapshot(from transaction: Transaction) -> TravelTransactionSnapshot? {
        guard transaction.isTravelTransaction == true,
              let travelAmount = transaction.travelAmount,
              let travelCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(
                transaction.travelCurrencyCode
              ),
              let exchangeRate = transaction.travelExchangeRate,
              let effectiveDate = transaction.travelExchangeRateEffectiveDate,
              let provider = transaction.travelExchangeRateProvider,
              !provider.isEmpty else {
            return nil
        }

        let accountCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(transaction.currencyCode)
            ?? transaction.currencyCode.uppercased()

        return TravelTransactionSnapshot(
            travelAmount: TravelTransactionRounding.round(
                travelAmount,
                currencyCode: travelCurrencyCode
            ),
            travelCurrencyCode: travelCurrencyCode,
            accountAmount: TravelTransactionRounding.round(
                transaction.amount,
                currencyCode: accountCurrencyCode
            ),
            accountCurrencyCode: accountCurrencyCode,
            exchangeRate: exchangeRate,
            effectiveDate: effectiveDate,
            provider: provider
        )
    }

    static func inputCurrencyCode(
        existingTransaction: Transaction?,
        isTravelTransaction: Bool,
        currentTravelCurrencyCode: String?
    ) -> String? {
        guard isTravelTransaction else {
            return nil
        }

        if let existingTransaction,
           let existingTravelCurrencyCode = snapshot(from: existingTransaction)?.travelCurrencyCode {
            return existingTravelCurrencyCode
        }

        return TravelCurrencyState.normalizedCurrencyCode(currentTravelCurrencyCode)
    }

    static func recomputeLockedSnapshot(
        existingSnapshot: TravelTransactionSnapshot,
        updatedTravelAmount: Decimal
    ) -> TravelTransactionSnapshot {
        let roundedTravelAmount = TravelTransactionRounding.round(
            updatedTravelAmount,
            currencyCode: existingSnapshot.travelCurrencyCode
        )
        let roundedAccountAmount = TravelTransactionRounding.round(
            roundedTravelAmount * existingSnapshot.exchangeRate,
            currencyCode: existingSnapshot.accountCurrencyCode
        )

        return TravelTransactionSnapshot(
            travelAmount: roundedTravelAmount,
            travelCurrencyCode: existingSnapshot.travelCurrencyCode,
            accountAmount: roundedAccountAmount,
            accountCurrencyCode: existingSnapshot.accountCurrencyCode,
            exchangeRate: existingSnapshot.exchangeRate,
            effectiveDate: existingSnapshot.effectiveDate,
            provider: existingSnapshot.provider
        )
    }

    static func buildSnapshot(
        travelAmount: Decimal,
        travelCurrencyCode: String,
        accountCurrencyCode: String,
        date: Date,
        conversionService: any CurrencyQuoteProviding
    ) async throws -> TravelTransactionSnapshot {
        let normalizedTravelCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(
            travelCurrencyCode
        ) ?? travelCurrencyCode.uppercased()
        let normalizedAccountCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(
            accountCurrencyCode
        ) ?? accountCurrencyCode.uppercased()
        let roundedTravelAmount = TravelTransactionRounding.round(
            travelAmount,
            currencyCode: normalizedTravelCurrencyCode
        )

        if normalizedTravelCurrencyCode == normalizedAccountCurrencyCode {
            return TravelTransactionSnapshot(
                travelAmount: roundedTravelAmount,
                travelCurrencyCode: normalizedTravelCurrencyCode,
                accountAmount: roundedTravelAmount,
                accountCurrencyCode: normalizedAccountCurrencyCode,
                exchangeRate: 1,
                effectiveDate: date,
                provider: "identity"
            )
        }

        let quote = try await conversionService.convertWithQuote(
            roundedTravelAmount,
            from: normalizedTravelCurrencyCode,
            to: normalizedAccountCurrencyCode,
            on: date,
            mode: .historical
        )

        return TravelTransactionSnapshot(
            travelAmount: roundedTravelAmount,
            travelCurrencyCode: normalizedTravelCurrencyCode,
            accountAmount: quote.convertedAmount,
            accountCurrencyCode: normalizedAccountCurrencyCode,
            exchangeRate: quote.rate,
            effectiveDate: quote.effectiveDate,
            provider: quote.provider
        )
    }

    static func apply(
        _ snapshot: TravelTransactionSnapshot?,
        to transaction: Transaction
    ) {
        if let snapshot {
            transaction.amount = snapshot.accountAmount
            transaction.currencyCode = snapshot.accountCurrencyCode
            transaction.isTravelTransaction = true
            transaction.travelAmount = snapshot.travelAmount
            transaction.travelCurrencyCode = snapshot.travelCurrencyCode
            transaction.travelExchangeRate = snapshot.exchangeRate
            transaction.travelExchangeRateEffectiveDate = snapshot.effectiveDate
            transaction.travelExchangeRateProvider = snapshot.provider
        } else {
            transaction.isTravelTransaction = false
            transaction.travelAmount = nil
            transaction.travelCurrencyCode = nil
            transaction.travelExchangeRate = nil
            transaction.travelExchangeRateEffectiveDate = nil
            transaction.travelExchangeRateProvider = nil
        }
    }

    static func isValidSnapshotState(for transaction: Transaction) -> Bool {
        if transaction.isTravelTransaction == true {
            return snapshot(from: transaction) != nil
        }

        return transaction.travelAmount == nil &&
            transaction.travelCurrencyCode == nil &&
            transaction.travelExchangeRate == nil &&
            transaction.travelExchangeRateEffectiveDate == nil &&
            transaction.travelExchangeRateProvider == nil
    }
}
