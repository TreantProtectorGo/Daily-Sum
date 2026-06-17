import XCTest
@testable import Flux

final class TransactionEntryAccountSelectionTests: XCTestCase {
    func testNewTravelTransactionAccountOptionsIncludeDefaultAndTravelCurrencyAccountsOnly() {
        let defaultAccount = Account(name: "Default USD", type: .bank, currencyCode: "USD")
        let travelAccount = Account(name: "CNY Wallet", type: .cash, currencyCode: "CNY")
        let otherAccount = Account(name: "JPY Wallet", type: .cash, currencyCode: "JPY")

        let availableAccounts = TransactionEntryAccountSelection.availableAccounts(
            from: [defaultAccount, travelAccount, otherAccount],
            existingTransaction: nil,
            isTravelTransaction: true,
            existingTravelSnapshot: nil,
            travelInputCurrencyCode: "CNY",
            defaultAccountId: defaultAccount.id
        )

        XCTAssertEqual(availableAccounts.map(\.id), [defaultAccount.id, travelAccount.id])
    }

    func testNewTravelTransactionAccountOptionsIncludeDefaultCurrencyAndTravelCurrencyAccountsOnly() {
        let defaultAccount = Account(name: "HKD Default", type: .bank, currencyCode: "HKD")
        let hkdAccount = Account(name: "HKD Wallet", type: .cash, currencyCode: "HKD")
        let cnyAccount = Account(name: "CNY Wallet", type: .cash, currencyCode: "CNY")
        let usdAccount = Account(name: "USD Wallet", type: .cash, currencyCode: "USD")

        let availableAccounts = TransactionEntryAccountSelection.availableAccounts(
            from: [defaultAccount, hkdAccount, cnyAccount, usdAccount],
            existingTransaction: nil,
            isTravelTransaction: true,
            existingTravelSnapshot: nil,
            travelInputCurrencyCode: "CNY",
            defaultCurrencyCode: "HKD",
            defaultAccountId: defaultAccount.id
        )

        XCTAssertEqual(availableAccounts.map(\.id), [defaultAccount.id, hkdAccount.id, cnyAccount.id])
    }

    func testNewTravelTransactionAccountOptionsPreserveOriginalOrder() {
        let otherAccount = Account(name: "JPY Wallet", type: .cash, currencyCode: "JPY")
        let firstTravelAccount = Account(name: "CNY Wallet", type: .cash, currencyCode: "CNY")
        let defaultAccount = Account(name: "Default USD", type: .bank, currencyCode: "USD")
        let secondTravelAccount = Account(name: "CNY Card", type: .creditCard, currencyCode: "CNY")

        let availableAccounts = TransactionEntryAccountSelection.availableAccounts(
            from: [otherAccount, firstTravelAccount, defaultAccount, secondTravelAccount],
            existingTransaction: nil,
            isTravelTransaction: true,
            existingTravelSnapshot: nil,
            travelInputCurrencyCode: "CNY",
            defaultAccountId: defaultAccount.id
        )

        XCTAssertEqual(
            availableAccounts.map(\.id),
            [firstTravelAccount.id, defaultAccount.id, secondTravelAccount.id]
        )
    }

    func testNewTravelTransactionAccountOptionsRemoveDuplicateAccounts() {
        let account = Account(name: "CNY Wallet", type: .cash, currencyCode: "CNY")

        let availableAccounts = TransactionEntryAccountSelection.availableAccounts(
            from: [account, account],
            existingTransaction: nil,
            isTravelTransaction: true,
            existingTravelSnapshot: nil,
            travelInputCurrencyCode: "CNY",
            defaultAccountId: account.id
        )

        XCTAssertEqual(availableAccounts.map(\.id), [account.id])
    }

    func testChangingTravelCurrencyFromCNYToJPYResetsSelectedCNYAccountToDefaultAccount() {
        let defaultAccount = Account(name: "HKD Default", type: .bank, currencyCode: "HKD")
        let cnyAccount = Account(name: "CNY Wallet", type: .cash, currencyCode: "CNY")
        let jpyAccount = Account(name: "JPY Wallet", type: .cash, currencyCode: "JPY")

        let availableAfterCurrencyChange = TransactionEntryAccountSelection.availableAccounts(
            from: [defaultAccount, cnyAccount, jpyAccount],
            existingTransaction: nil,
            isTravelTransaction: true,
            existingTravelSnapshot: nil,
            travelInputCurrencyCode: "JPY",
            defaultAccountId: defaultAccount.id
        )

        let reconciledAccount = TransactionEntryAccountSelection.reconciledSelectedAccount(
            cnyAccount,
            availableAccounts: availableAfterCurrencyChange
        )

        XCTAssertEqual(availableAfterCurrencyChange.map(\.id), [defaultAccount.id, jpyAccount.id])
        XCTAssertEqual(reconciledAccount?.id, defaultAccount.id)
    }

    func testChangingTravelCurrencyFromCNYToJPYPreservesSelectedDefaultAccount() {
        let defaultAccount = Account(name: "HKD Default", type: .bank, currencyCode: "HKD")
        let cnyAccount = Account(name: "CNY Wallet", type: .cash, currencyCode: "CNY")
        let jpyAccount = Account(name: "JPY Wallet", type: .cash, currencyCode: "JPY")

        let availableAfterCurrencyChange = TransactionEntryAccountSelection.availableAccounts(
            from: [defaultAccount, cnyAccount, jpyAccount],
            existingTransaction: nil,
            isTravelTransaction: true,
            existingTravelSnapshot: nil,
            travelInputCurrencyCode: "JPY",
            defaultAccountId: defaultAccount.id
        )

        let reconciledAccount = TransactionEntryAccountSelection.reconciledSelectedAccount(
            defaultAccount,
            availableAccounts: availableAfterCurrencyChange
        )

        XCTAssertEqual(reconciledAccount?.id, defaultAccount.id)
    }
}
