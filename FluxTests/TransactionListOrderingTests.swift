import XCTest
import SwiftData
@testable import Flux

@MainActor
final class TransactionListOrderingTests: XCTestCase {
    func testSameDayTransactionsShowNewestCreatedFirst() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Cash", type: .cash, currencyCode: "USD")
        let category = Category(
            nameKey: "Food",
            icon: "fork.knife",
            colorHex: "#FF9500",
            type: .expense
        )
        let transactionDate = Date(timeIntervalSince1970: 1_700_000_000)
        let olderTransaction = Transaction(
            amount: 10,
            currencyCode: "USD",
            type: .expense,
            date: transactionDate,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            account: account,
            category: category
        )
        let newerTransaction = Transaction(
            amount: 20,
            currencyCode: "USD",
            type: .expense,
            date: transactionDate,
            createdAt: Date(timeIntervalSince1970: 1_800_000_100),
            account: account,
            category: category
        )
        context.insert(account)
        context.insert(category)
        context.insert(olderTransaction)
        context.insert(newerTransaction)
        try context.save()

        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()

        XCTAssertEqual(viewModel.groupedTransactionRows.count, 1)
        XCTAssertEqual(
            viewModel.groupedTransactionRows[0].rows.map(\.id),
            [newerTransaction.id, olderTransaction.id]
        )
    }
}
