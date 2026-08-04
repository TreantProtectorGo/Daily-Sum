import SwiftData
import XCTest
@testable import Flux

@MainActor
final class TransactionServiceTests: XCTestCase {
    func testDetachedPendingScheduledOccurrenceIsExcludedUntilConfirmed() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let currencyCode = UserCurrencyPreference.resolvedCurrencyCode
        let account = Account(
            name: "Salary",
            type: .bank,
            currencyCode: currencyCode,
            initialBalance: 100
        )
        let category = Category(
            nameKey: "Salary",
            icon: "banknote.fill",
            colorHex: "#34C759",
            type: .income,
            isSystemDefault: false
        )
        let pending = Transaction(
            amount: 55,
            currencyCode: currencyCode,
            type: .income,
            date: .now,
            recurringTemplateId: UUID(),
            generatedDate: .now,
            postingStatus: .pending,
            account: account,
            category: category
        )
        context.insert(account)
        context.insert(category)
        context.insert(pending)
        try context.save()

        pending.recurringTemplateId = nil
        try context.save()

        let service = TransactionService(context: context)
        XCTAssertFalse(pending.isGeneratedFromRecurring)
        XCTAssertTrue(pending.isPendingScheduledOccurrence)
        XCTAssertEqual(account.currentBalance, 100)
        XCTAssertTrue(try service.fetch().isEmpty)

        let reports = ReportsViewModel(modelContext: context)
        reports.selectedPeriod = .all
        await reports.loadReports()
        XCTAssertEqual(reports.totalIncome, 0)

        try service.confirmScheduledOccurrence(pending)

        XCTAssertFalse(pending.isPendingScheduledOccurrence)
        XCTAssertEqual(account.currentBalance, 155)
        XCTAssertEqual(try service.fetch().map(\.id), [pending.id])

        await reports.loadReports()
        XCTAssertEqual(reports.totalIncome, 55)
    }

    func testPendingPostingStatusDoesNotTurnTemplateIntoOccurrence() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let template = Transaction(
            amount: 100,
            currencyCode: "HKD",
            type: .income,
            date: .now,
            isRecurringTemplate: true,
            recurrenceRule: .monthly,
            postingStatus: .pending
        )
        context.insert(template)
        try context.save()

        XCTAssertFalse(template.isPendingScheduledOccurrence)
        XCTAssertFalse(template.isPosted)
        XCTAssertTrue(try TransactionService(context: context).fetch().isEmpty)
    }

    func testLegacyGeneratedOccurrenceWithoutPostingStatusRemainsPosted() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(
            name: "Legacy",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 100
        )
        let legacyOccurrence = Transaction(
            amount: 25,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            recurringTemplateId: UUID(),
            generatedDate: .now,
            account: account
        )
        context.insert(account)
        context.insert(legacyOccurrence)
        try context.save()

        XCTAssertNil(legacyOccurrence.postingStatusRawValue)
        XCTAssertEqual(legacyOccurrence.postingStatus, .posted)
        XCTAssertTrue(legacyOccurrence.isPosted)
        XCTAssertEqual(account.currentBalance, 75)
        XCTAssertEqual(try TransactionService(context: context).fetch().map(\.id), [legacyOccurrence.id])
    }

    func testEditingGeneratedOccurrenceDoesNotModifyTemplateOrSibling() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Cash", type: .cash, currencyCode: "USD")
        let template = Transaction(
            amount: 40,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            isRecurringTemplate: true,
            recurrenceRule: .monthly,
            recurringTemplateId: nil,
            account: account
        )
        let selectedOccurrence = Transaction.fromTemplate(template, forDate: .now)
        let siblingDate = Calendar.current.date(byAdding: .month, value: 1, to: .now)!
        let siblingOccurrence = Transaction.fromTemplate(template, forDate: siblingDate)
        context.insert(account)
        context.insert(template)
        context.insert(selectedOccurrence)
        context.insert(siblingOccurrence)
        try context.save()

        let editedDate = Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        try TransactionService(context: context).update(
            selectedOccurrence,
            amount: 45,
            date: editedDate,
            notes: "Actual amount"
        )

        XCTAssertEqual(selectedOccurrence.amount, 45)
        XCTAssertEqual(selectedOccurrence.date, editedDate)
        XCTAssertEqual(selectedOccurrence.notes, "Actual amount")
        XCTAssertTrue(selectedOccurrence.isPendingScheduledOccurrence)
        XCTAssertEqual(template.amount, 40)
        XCTAssertEqual(siblingOccurrence.amount, 40)
        XCTAssertEqual(siblingOccurrence.date, siblingDate)
        XCTAssertTrue(siblingOccurrence.isPendingScheduledOccurrence)
    }

    func testPendingScheduledExpenseDoesNotConsumeBudgetUntilConfirmed() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let category = Category(
            nameKey: "Gym",
            icon: "dumbbell.fill",
            colorHex: "#14B8A6",
            type: .expense,
            isSystemDefault: false
        )
        let account = Account(name: "Card", type: .creditCard, currencyCode: "USD")
        let budget = Budget(
            limitAmount: 100,
            currencyCode: "USD",
            period: .monthly,
            category: category
        )
        let pending = Transaction(
            amount: 40,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            recurringTemplateId: UUID(),
            postingStatus: .pending,
            account: account,
            category: category
        )
        context.insert(category)
        context.insert(account)
        context.insert(budget)
        context.insert(pending)
        try context.save()

        let budgetService = BudgetService(context: context)
        let pendingStatus = try await budgetService.status(for: budget)
        XCTAssertEqual(pendingStatus.spent, 0)

        try TransactionService(context: context).confirmScheduledOccurrence(pending)

        let confirmedStatus = try await budgetService.status(for: budget)
        XCTAssertEqual(confirmedStatus.spent, 40)
    }

    func testGroupsTransactionTotalsByStableCategoryID() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Cash", type: .cash, currencyCode: "USD")
        let food = Category(
            nameKey: "Food",
            icon: "fork.knife",
            colorHex: "#FF9500",
            type: .expense
        )
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        context.insert(account)
        context.insert(food)
        context.insert(Transaction(
            amount: 12,
            currencyCode: "USD",
            type: .expense,
            date: date,
            account: account,
            category: food
        ))
        context.insert(Transaction(
            amount: 8,
            currencyCode: "USD",
            type: .expense,
            date: date,
            account: account,
            category: food
        ))
        try context.save()

        let service = TransactionService(context: context)
        let grouped = try service.groupedByCategory(
            from: date.addingTimeInterval(-1),
            to: date.addingTimeInterval(1),
            type: .expense
        )

        XCTAssertEqual(grouped, [food.id: 20])
    }
}
