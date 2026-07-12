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
        let startOfDay = Calendar.current.startOfDay(
            for: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let earlierTransactionTime = Calendar.current.date(
            byAdding: .hour,
            value: 8,
            to: startOfDay
        )!
        let laterTransactionTime = Calendar.current.date(
            byAdding: .hour,
            value: 20,
            to: startOfDay
        )!
        let olderTransaction = Transaction(
            amount: 10,
            currencyCode: "USD",
            type: .expense,
            date: laterTransactionTime,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            account: account,
            category: category
        )
        let newerTransaction = Transaction(
            amount: 20,
            currencyCode: "USD",
            type: .expense,
            date: earlierTransactionTime,
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

    func testDateGroupSummariesExposeDailyIncomeAndExpenseTotals() async throws {
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
        let income = Transaction(
            amount: 125,
            currencyCode: "USD",
            type: .income,
            date: transactionDate,
            account: account,
            category: category
        )
        let firstExpense = Transaction(
            amount: 20,
            currencyCode: "USD",
            type: .expense,
            date: transactionDate,
            account: account,
            category: category
        )
        let secondExpense = Transaction(
            amount: 5,
            currencyCode: "USD",
            type: .expense,
            date: transactionDate,
            account: account,
            category: category
        )
        context.insert(account)
        context.insert(category)
        context.insert(income)
        context.insert(firstExpense)
        context.insert(secondExpense)
        try context.save()

        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()

        let group = try XCTUnwrap(viewModel.groupedTransactionRows.first)
        XCTAssertEqual(group.incomeTotal, 125)
        XCTAssertEqual(group.expenseTotal, 25)
        XCTAssertEqual(group.currencyCode, "USD")
    }
}
