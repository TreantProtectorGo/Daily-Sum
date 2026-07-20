import XCTest
@testable import Flux

final class TransactionEntryAccountSelectionTests: XCTestCase {
    func testNewForeignCurrencyTransactionAllowsEverySettlementAccount() {
        let defaultAccount = Account(name: "Default USD", type: .bank, currencyCode: "USD")
        let travelAccount = Account(name: "CNY Wallet", type: .cash, currencyCode: "CNY")
        let otherAccount = Account(name: "JPY Wallet", type: .cash, currencyCode: "JPY")

        let availableAccounts = TransactionEntryAccountSelection.availableAccounts(
            from: [defaultAccount, travelAccount, otherAccount],
            existingTransaction: nil,
            isTravelTransaction: true,
            existingTravelSnapshot: nil
        )

        XCTAssertEqual(
            availableAccounts.map(\.id),
            [defaultAccount.id, travelAccount.id, otherAccount.id]
        )
    }

    func testNewForeignCurrencyTransactionPreservesAccountOrder() {
        let defaultAccount = Account(name: "HKD Default", type: .bank, currencyCode: "HKD")
        let hkdAccount = Account(name: "HKD Wallet", type: .cash, currencyCode: "HKD")
        let cnyAccount = Account(name: "CNY Wallet", type: .cash, currencyCode: "CNY")
        let usdAccount = Account(name: "USD Wallet", type: .cash, currencyCode: "USD")

        let availableAccounts = TransactionEntryAccountSelection.availableAccounts(
            from: [defaultAccount, hkdAccount, cnyAccount, usdAccount],
            existingTransaction: nil,
            isTravelTransaction: true,
            existingTravelSnapshot: nil
        )

        XCTAssertEqual(
            availableAccounts.map(\.id),
            [defaultAccount.id, hkdAccount.id, cnyAccount.id, usdAccount.id]
        )
    }

    func testNewTravelTransactionAccountOptionsRemoveDuplicateAccounts() {
        let account = Account(name: "CNY Wallet", type: .cash, currencyCode: "CNY")

        let availableAccounts = TransactionEntryAccountSelection.availableAccounts(
            from: [account, account],
            existingTransaction: nil,
            isTravelTransaction: true,
            existingTravelSnapshot: nil
        )

        XCTAssertEqual(availableAccounts.map(\.id), [account.id])
    }

    func testChangingForeignCurrencyPreservesSelectedSettlementAccount() {
        let defaultAccount = Account(name: "HKD Default", type: .bank, currencyCode: "HKD")
        let cnyAccount = Account(name: "CNY Wallet", type: .cash, currencyCode: "CNY")
        let jpyAccount = Account(name: "JPY Wallet", type: .cash, currencyCode: "JPY")

        let availableAfterCurrencyChange = TransactionEntryAccountSelection.availableAccounts(
            from: [defaultAccount, cnyAccount, jpyAccount],
            existingTransaction: nil,
            isTravelTransaction: true,
            existingTravelSnapshot: nil
        )

        let reconciledAccount = TransactionEntryAccountSelection.reconciledSelectedAccount(
            cnyAccount,
            availableAccounts: availableAfterCurrencyChange
        )

        XCTAssertEqual(
            availableAfterCurrencyChange.map(\.id),
            [defaultAccount.id, cnyAccount.id, jpyAccount.id]
        )
        XCTAssertEqual(reconciledAccount?.id, cnyAccount.id)
    }

    func testEditingForeignCurrencyTransactionKeepsOriginalSettlementCurrency() {
        let hkdAccount = Account(name: "HKD Account", type: .bank, currencyCode: "HKD")
        let usdAccount = Account(name: "USD Account", type: .bank, currencyCode: "USD")
        let transaction = Transaction(
            amount: 780,
            currencyCode: "HKD",
            type: .income,
            account: hkdAccount,
            category: nil
        )
        let snapshot = TravelTransactionSnapshot(
            travelAmount: 100,
            travelCurrencyCode: "USD",
            accountAmount: 780,
            accountCurrencyCode: "HKD",
            exchangeRate: 7.8,
            effectiveDate: .now,
            provider: "mock"
        )

        let availableAccounts = TransactionEntryAccountSelection.availableAccounts(
            from: [hkdAccount, usdAccount],
            existingTransaction: transaction,
            isTravelTransaction: true,
            existingTravelSnapshot: snapshot
        )

        XCTAssertEqual(availableAccounts.map(\.id), [hkdAccount.id])
    }
}

final class TransactionEntryCurrencySelectionTests: XCTestCase {
    func testAvailableForeignCurrenciesExcludeSettlementCurrency() {
        let currencies = TransactionEntryCurrencySelection.availableCurrencies(
            accountCurrencyCode: "hkd"
        )

        XCTAssertFalse(currencies.contains(.HKD))
        XCTAssertTrue(currencies.contains(.USD))
        XCTAssertTrue(currencies.contains(.CHF))
    }

    func testMatchingTransactionAndSettlementCurrenciesAreNotForeign() {
        XCTAssertNil(
            TransactionEntryCurrencySelection.foreignCurrencyCode(
                candidateCurrencyCode: "usd",
                accountCurrencyCode: "USD"
            )
        )
    }

    func testDifferentTransactionAndSettlementCurrenciesRemainForeign() {
        XCTAssertEqual(
            TransactionEntryCurrencySelection.foreignCurrencyCode(
                candidateCurrencyCode: "jpy",
                accountCurrencyCode: "HKD"
            ),
            "JPY"
        )
    }
}

final class TransactionEntryCurrencyConversionTests: XCTestCase {
    private let conversionID = UUID()
    private let accountID = UUID()

    func testCurrentConversionResultCanApply() {
        XCTAssertTrue(shouldApply())
    }

    func testStaleConversionIDCannotApply() {
        XCTAssertFalse(shouldApply(activeConversionID: UUID()))
    }

    func testResultForPreviousAccountCannotApply() {
        XCTAssertFalse(shouldApply(selectedAccountID: UUID()))
    }

    func testResultForPreviousCurrencyCannotApply() {
        XCTAssertFalse(shouldApply(currentInputCurrencyCode: "EUR"))
    }

    func testResultCannotOverwriteNewerAmountInput() {
        XCTAssertFalse(shouldApply(currentInputAmount: 200))
    }

    private func shouldApply(
        activeConversionID: UUID? = nil,
        selectedAccountID: UUID? = nil,
        currentInputCurrencyCode: String? = "USD",
        currentInputAmount: Decimal = 100
    ) -> Bool {
        TransactionEntryCurrencyConversion.shouldApplyResult(
            expectedConversionID: conversionID,
            activeConversionID: activeConversionID ?? conversionID,
            expectedAccountID: accountID,
            selectedAccountID: selectedAccountID ?? accountID,
            expectedInputCurrencyCode: "USD",
            currentInputCurrencyCode: currentInputCurrencyCode,
            expectedInputAmount: 100,
            currentInputAmount: currentInputAmount
        )
    }
}
