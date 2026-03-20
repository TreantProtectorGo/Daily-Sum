//
//  FluxTests.swift
//  FluxTests
//
//  Created by Wing - on 9/2/2026.
//

import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import Flux

final class FluxTests: XCTestCase {
    private static let showUpcomingScheduledMigrationKey =
        "flux.showUpcomingScheduledTransactions.defaultVisibleMigrationCompleted"
    private var originalPreferredCurrencyCode: String?
    private var originalTravelCurrencySource: String?
    private var originalDetectedTravelCurrencyCode: String?
    private var originalManualTravelCurrencyCode: String?
    private var originalShowUpcomingScheduled: Bool?
    private var originalShowUpcomingScheduledMigration: Bool?

    override func setUpWithError() throws {
        originalPreferredCurrencyCode = UserDefaults.standard.string(
            forKey: UserCurrencyPreference.storageKey
        )
        originalTravelCurrencySource = UserDefaults.standard.string(
            forKey: TravelCurrencyPreference.sourceStorageKey
        )
        originalDetectedTravelCurrencyCode = UserDefaults.standard.string(
            forKey: TravelCurrencyPreference.detectedCurrencyStorageKey
        )
        originalManualTravelCurrencyCode = UserDefaults.standard.string(
            forKey: TravelCurrencyPreference.manualCurrencyStorageKey
        )
        originalShowUpcomingScheduled = UserDefaults.standard.object(
            forKey: TransactionListPreference.showUpcomingScheduledStorageKey
        ) as? Bool
        originalShowUpcomingScheduledMigration = UserDefaults.standard.object(
            forKey: Self.showUpcomingScheduledMigrationKey
        ) as? Bool
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.set(
            originalPreferredCurrencyCode,
            forKey: UserCurrencyPreference.storageKey
        )
        if let originalTravelCurrencySource {
            UserDefaults.standard.set(
                originalTravelCurrencySource,
                forKey: TravelCurrencyPreference.sourceStorageKey
            )
        } else {
            UserDefaults.standard.removeObject(forKey: TravelCurrencyPreference.sourceStorageKey)
        }

        UserDefaults.standard.set(
            originalDetectedTravelCurrencyCode,
            forKey: TravelCurrencyPreference.detectedCurrencyStorageKey
        )
        UserDefaults.standard.set(
            originalManualTravelCurrencyCode,
            forKey: TravelCurrencyPreference.manualCurrencyStorageKey
        )

        if let originalShowUpcomingScheduled {
            UserDefaults.standard.set(
                originalShowUpcomingScheduled,
                forKey: TransactionListPreference.showUpcomingScheduledStorageKey
            )
        } else {
            UserDefaults.standard.removeObject(
                forKey: TransactionListPreference.showUpcomingScheduledStorageKey
            )
        }

        if let originalShowUpcomingScheduledMigration {
            UserDefaults.standard.set(
                originalShowUpcomingScheduledMigration,
                forKey: Self.showUpcomingScheduledMigrationKey
            )
        } else {
            UserDefaults.standard.removeObject(
                forKey: Self.showUpcomingScheduledMigrationKey
            )
        }
    }

    func testTravelCurrencyPreferencePersistsSource() {
        TravelCurrencyPreference.source = .manual
        XCTAssertEqual(TravelCurrencyPreference.source, .manual)

        TravelCurrencyPreference.source = .automatic
        XCTAssertEqual(TravelCurrencyPreference.source, .automatic)
    }

    func testTravelCurrencyPreferencePersistsDetectedAndManualCurrencyCodes() {
        TravelCurrencyPreference.detectedCurrencyCode = "KRW"
        TravelCurrencyPreference.manualCurrencyCode = "JPY"

        XCTAssertEqual(TravelCurrencyPreference.detectedCurrencyCode, "KRW")
        XCTAssertEqual(TravelCurrencyPreference.manualCurrencyCode, "JPY")

        TravelCurrencyPreference.manualCurrencyCode = nil
        XCTAssertNil(TravelCurrencyPreference.manualCurrencyCode)
    }

    @MainActor
    func testTravelCurrencySettingsSummaryUsesAutomaticCurrentCurrency() throws {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }
        AppLanguagePreference.language = .english

        XCTAssertEqual(
            TravelCurrencySettingSummaryFormatter.string(
                source: .automatic,
                currentTravelCurrencyCode: "KRW",
                manualTravelCurrencyCode: nil,
                defaultCurrencyCode: "USD"
            ),
            "Automatic (Current: KRW)"
        )
    }

    @MainActor
    func testTravelCurrencySettingsSummaryUsesManualCurrency() throws {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }
        AppLanguagePreference.language = .english

        XCTAssertEqual(
            TravelCurrencySettingSummaryFormatter.string(
                source: .manual,
                currentTravelCurrencyCode: "JPY",
                manualTravelCurrencyCode: "JPY",
                defaultCurrencyCode: "USD"
            ),
            "Manual: JPY"
        )
    }

    @MainActor
    func testTravelCurrencySettingsSummaryUsesManualUnsetState() throws {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }
        AppLanguagePreference.language = .english

        XCTAssertEqual(
            TravelCurrencySettingSummaryFormatter.string(
                source: .manual,
                currentTravelCurrencyCode: nil,
                manualTravelCurrencyCode: nil,
                defaultCurrencyCode: "USD"
            ),
            "Manual (Not Set)"
        )
    }

    func testTransactionAccountPreferencePersistsValues() throws {
        let originalDefaultAccountId = TransactionAccountPreference.defaultAccountId
        let originalRememberLastUsed = TransactionAccountPreference.rememberLastUsedAccount
        let originalLastUsedAccountId = TransactionAccountPreference.lastUsedAccountId
        
        defer {
            TransactionAccountPreference.defaultAccountId = originalDefaultAccountId
            TransactionAccountPreference.rememberLastUsedAccount = originalRememberLastUsed
            TransactionAccountPreference.lastUsedAccountId = originalLastUsedAccountId
        }
        
        let accountId = UUID()
        
        TransactionAccountPreference.defaultAccountId = accountId
        TransactionAccountPreference.rememberLastUsedAccount = true
        TransactionAccountPreference.lastUsedAccountId = accountId
        
        XCTAssertEqual(TransactionAccountPreference.defaultAccountId, accountId)
        XCTAssertTrue(TransactionAccountPreference.rememberLastUsedAccount)
        XCTAssertEqual(TransactionAccountPreference.lastUsedAccountId, accountId)
    }

    func testTransactionListPreferencePersistsShowUpcomingScheduled() {
        let originalValue = UserDefaults.standard.object(
            forKey: TransactionListPreference.showUpcomingScheduledStorageKey
        ) as? Bool
        defer {
            if let originalValue {
                UserDefaults.standard.set(
                    originalValue,
                    forKey: TransactionListPreference.showUpcomingScheduledStorageKey
                )
            } else {
                UserDefaults.standard.removeObject(
                    forKey: TransactionListPreference.showUpcomingScheduledStorageKey
                )
            }
        }

        TransactionListPreference.showUpcomingScheduled = false
        XCTAssertFalse(TransactionListPreference.showUpcomingScheduled)

        TransactionListPreference.showUpcomingScheduled = true
        XCTAssertTrue(TransactionListPreference.showUpcomingScheduled)
    }

    func testTransactionListPreferenceMigratesLegacyHiddenUpcomingToVisibleByDefault() {
        UserDefaults.standard.set(
            false,
            forKey: TransactionListPreference.showUpcomingScheduledStorageKey
        )
        UserDefaults.standard.removeObject(
            forKey: Self.showUpcomingScheduledMigrationKey
        )

        XCTAssertTrue(TransactionListPreference.showUpcomingScheduled)
        XCTAssertEqual(
            UserDefaults.standard.object(
                forKey: TransactionListPreference.showUpcomingScheduledStorageKey
            ) as? Bool,
            true
        )
        XCTAssertEqual(
            UserDefaults.standard.object(
                forKey: Self.showUpcomingScheduledMigrationKey
            ) as? Bool,
            true
        )
    }

    func testTransactionRowSnapshotPromptsScheduledDeleteOnlyForFutureGeneratedDay() {
        let account = Account(name: "Test", type: .cash, currencyCode: "USD")

        let futureGenerated = Transaction(
            amount: 10,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 1, to: .now)!,
            recurringTemplateId: UUID(),
            account: account
        )
        let todayGenerated = Transaction(
            amount: 12,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            recurringTemplateId: UUID(),
            account: account
        )
        let futureManual = Transaction(
            amount: 20,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 1, to: .now)!,
            account: account
        )

        XCTAssertTrue(TransactionRowSnapshot(transaction: futureGenerated).shouldPromptScheduledDelete)
        XCTAssertFalse(TransactionRowSnapshot(transaction: todayGenerated).shouldPromptScheduledDelete)
        XCTAssertFalse(TransactionRowSnapshot(transaction: futureManual).shouldPromptScheduledDelete)
    }

    func testTransactionRowSnapshotIncludesTravelTransactionFlag() {
        let account = Account(name: "Travel Card", type: .creditCard, currencyCode: "JPY")
        let transaction = Transaction(
            amount: 1200,
            currencyCode: "JPY",
            type: .expense,
            date: .now,
            isTravelTransaction: true,
            account: account
        )

        XCTAssertTrue(TransactionRowSnapshot(transaction: transaction).isTravelTransaction)
    }

    @MainActor
    func testTravelBadgeDoesNotIncreaseTransactionRowHeight() {
        let account = Account(name: "Cash", type: .cash, currencyCode: "USD")
        let category = Category(
            nameKey: "category.expense.food",
            icon: "fork.knife",
            colorHex: "#FF3B30",
            type: .expense,
            isSystemDefault: true
        )

        let standardTransaction = Transaction(
            amount: 42,
            currencyCode: "USD",
            type: .expense,
            notes: "Hi",
            account: account,
            category: category
        )
        let travelTransaction = Transaction(
            amount: 42,
            currencyCode: "USD",
            type: .expense,
            notes: "Hi",
            isTravelTransaction: true,
            account: account,
            category: category
        )

        let standardHeight = measuredHeight(
            for: TransactionRowView(snapshot: TransactionRowSnapshot(transaction: standardTransaction))
        )
        let travelHeight = measuredHeight(
            for: TransactionRowView(snapshot: TransactionRowSnapshot(transaction: travelTransaction))
        )

        XCTAssertEqual(travelHeight, standardHeight, accuracy: 1)
    }

    func testProgrammaticTransactionTypeChangeKeepsExistingCategorySelection() {
        let category = Category(
            nameKey: "category.income.salary",
            icon: "banknote",
            colorHex: "#34C759",
            type: .income,
            isSystemDefault: true
        )

        let resolvedCategory = TransactionEntryCategorySelection.resolvedCategory(
            currentCategory: category,
            previousType: .expense,
            nextType: .income,
            changeSource: .programmatic
        )

        XCTAssertEqual(resolvedCategory?.id, category.id)
    }

    func testUserTransactionTypeChangeClearsCategorySelection() {
        let category = Category(
            nameKey: "category.expense.food",
            icon: "fork.knife",
            colorHex: "#FF3B30",
            type: .expense,
            isSystemDefault: true
        )

        let resolvedCategory = TransactionEntryCategorySelection.resolvedCategory(
            currentCategory: category,
            previousType: .expense,
            nextType: .income,
            changeSource: .userSelection
        )

        XCTAssertNil(resolvedCategory)
    }

    func testTransactionEntryValidationRequiresCategoryToSave() {
        let account = Account(name: "Cash", type: .cash, currencyCode: "USD")
        let category = Category(
            nameKey: "category.expense.food",
            icon: "fork.knife",
            colorHex: "#FF3B30",
            type: .expense,
            isSystemDefault: true
        )

        XCTAssertTrue(
            TransactionEntryFormValidation.canSave(
                amount: 12.34,
                selectedAccount: account,
                selectedCategory: category
            )
        )
        XCTAssertFalse(
            TransactionEntryFormValidation.canSave(
                amount: 12.34,
                selectedAccount: account,
                selectedCategory: nil
            )
        )
        XCTAssertFalse(
            TransactionEntryFormValidation.canSave(
                amount: 0,
                selectedAccount: account,
                selectedCategory: category
            )
        )
        XCTAssertFalse(
            TransactionEntryFormValidation.canSave(
                amount: 12.34,
                selectedAccount: nil,
                selectedCategory: category
            )
        )
    }

    func testProgrammaticTypeChangeClearsTravelTransactionForIncome() {
        let resolvedCategory = TransactionEntryCategorySelection.resolvedCategory(
            currentCategory: nil,
            previousType: .expense,
            nextType: .income,
            changeSource: .programmatic
        )

        XCTAssertNil(resolvedCategory)
        XCTAssertFalse(
            TransactionTravelDefaults.resolveIsTravelTransaction(
                transactionType: .income,
                accountCurrencyCode: "JPY",
                currentTravelCurrencyCode: "JPY",
                userOverride: true
            )
        )
    }

    func testExistingTransactionCannotEditTransactionType() {
        let account = Account(name: "Cash", type: .cash, currencyCode: "USD")
        let transaction = Transaction(
            amount: 10,
            currencyCode: "USD",
            type: .expense,
            account: account,
            category: nil
        )

        XCTAssertFalse(
            TransactionEntryTypeEditing.canEditType(existingTransaction: transaction)
        )
        XCTAssertTrue(
            TransactionEntryTypeEditing.canEditType(existingTransaction: nil)
        )
    }

    func testTransactionEntryNavigationTitleUsesCreateAndEditModes() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }
        AppLanguagePreference.language = .english

        let account = Account(name: "Cash", type: .cash, currencyCode: "USD")
        let transaction = Transaction(
            amount: 10,
            currencyCode: "USD",
            type: .expense,
            account: account,
            category: nil
        )

        XCTAssertEqual(
            TransactionEntryPresentation.navigationTitle(
                existingTransaction: nil,
                transactionType: .expense
            ),
            "Add Transaction"
        )
        XCTAssertEqual(
            TransactionEntryPresentation.navigationTitle(
                existingTransaction: transaction,
                transactionType: .expense
            ),
            "Edit Expense"
        )
        XCTAssertEqual(
            TransactionEntryPresentation.navigationTitle(
                existingTransaction: transaction,
                transactionType: .income
            ),
            "Edit Income"
        )
    }

    @MainActor
    func testIsSourceRecurringTransactionOnlyTrueForTemplateStartDayOccurrence() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Source Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let templateDate = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        let template = Transaction(
            amount: 80,
            currencyCode: "USD",
            type: .expense,
            date: templateDate,
            notes: "Plan",
            isRecurringTemplate: true,
            recurrenceRule: .monthly,
            schedulePlanType: .recurring,
            dueDayOfMonth: Calendar.current.component(.day, from: templateDate),
            reminderLeadDays: 1,
            account: account,
            category: nil
        )
        context.insert(template)

        let sourceOccurrence = Transaction(
            amount: 80,
            currencyCode: "USD",
            type: .expense,
            date: templateDate,
            recurringTemplateId: template.id,
            account: account
        )
        let nonSourceOccurrence = Transaction(
            amount: 80,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .month, value: 1, to: templateDate)!,
            recurringTemplateId: template.id,
            account: account
        )
        context.insert(sourceOccurrence)
        context.insert(nonSourceOccurrence)
        try context.save()

        let viewModel = TransactionListViewModel(modelContext: context)
        XCTAssertTrue(viewModel.isSourceRecurringTransaction(transactionId: sourceOccurrence.id))
        XCTAssertFalse(viewModel.isSourceRecurringTransaction(transactionId: nonSourceOccurrence.id))
    }

    @MainActor
    func testTransactionListHidesOnlyFutureGeneratedScheduledWhenToggleOff() async throws {
        let originalValue = UserDefaults.standard.object(
            forKey: TransactionListPreference.showUpcomingScheduledStorageKey
        ) as? Bool
        defer {
            if let originalValue {
                UserDefaults.standard.set(
                    originalValue,
                    forKey: TransactionListPreference.showUpcomingScheduledStorageKey
                )
            } else {
                UserDefaults.standard.removeObject(
                    forKey: TransactionListPreference.showUpcomingScheduledStorageKey
                )
            }
        }

        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Filter Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let templateId = UUID()
        let pastGenerated = Transaction(
            amount: 10,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: -2, to: .now)!,
            recurringTemplateId: templateId,
            account: account
        )
        let futureGenerated = Transaction(
            amount: 12,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 2, to: .now)!,
            recurringTemplateId: templateId,
            account: account
        )
        let futureManual = Transaction(
            amount: 20,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
            account: account
        )

        context.insert(pastGenerated)
        context.insert(futureGenerated)
        context.insert(futureManual)
        try context.save()

        TransactionListPreference.showUpcomingScheduled = false
        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()

        let hiddenIds = Set(viewModel.filteredTransactions.map(\.id))
        XCTAssertTrue(hiddenIds.contains(pastGenerated.id))
        XCTAssertFalse(hiddenIds.contains(futureGenerated.id))
        XCTAssertTrue(hiddenIds.contains(futureManual.id))

        viewModel.showUpcomingScheduled = true
        viewModel.applyFilters()

        let shownIds = Set(viewModel.filteredTransactions.map(\.id))
        XCTAssertTrue(shownIds.contains(pastGenerated.id))
        XCTAssertTrue(shownIds.contains(futureGenerated.id))
        XCTAssertTrue(shownIds.contains(futureManual.id))
    }

    @MainActor
    func testUpcomingHintBarAppearsWhenUpcomingGeneratedTransactionsExist() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Hint Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let now = Date.now
        let generated = Transaction(
            amount: 42,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 4, to: now)!,
            recurringTemplateId: UUID(),
            account: account
        )
        context.insert(generated)
        try context.save()

        TransactionListPreference.showUpcomingScheduled = false
        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()

        XCTAssertEqual(viewModel.hiddenUpcomingScheduledCount, 1)
        XCTAssertEqual(viewModel.nextUpcomingScheduledDate, generated.date)
        XCTAssertTrue(viewModel.shouldShowUpcomingHintBar)
    }

    @MainActor
    func testUpcomingHintBarStillAppearsWhenShowUpcomingIsEnabledForHideAction() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Hint Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let generated = Transaction(
            amount: 35,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
            recurringTemplateId: UUID(),
            account: account
        )
        context.insert(generated)
        try context.save()

        TransactionListPreference.showUpcomingScheduled = false
        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()
        XCTAssertTrue(viewModel.shouldShowUpcomingHintBar)

        viewModel.showUpcomingScheduled = true
        viewModel.applyFilters()
        XCTAssertTrue(viewModel.shouldShowUpcomingHintBar)
    }

    @MainActor
    func testUpcomingHintCountsOnlyGeneratedTransactionsWithinLookAheadWindow() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Hint Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let now = Date.now
        let withinWindowGenerated = Transaction(
            amount: 10,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 6, to: now)!,
            recurringTemplateId: UUID(),
            account: account
        )
        let beyondWindowGenerated = Transaction(
            amount: 20,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(
                byAdding: .day,
                value: RecurringTransactionGenerator.defaultLookAheadDays + 8,
                to: now
            )!,
            recurringTemplateId: UUID(),
            account: account
        )
        let manualFuture = Transaction(
            amount: 30,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 5, to: now)!,
            account: account
        )

        context.insert(withinWindowGenerated)
        context.insert(beyondWindowGenerated)
        context.insert(manualFuture)
        try context.save()

        TransactionListPreference.showUpcomingScheduled = false
        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()

        XCTAssertEqual(viewModel.hiddenUpcomingScheduledCount, 1)
        XCTAssertEqual(viewModel.hiddenUpcomingScheduledTransactions.first?.id, withinWindowGenerated.id)
        XCTAssertEqual(viewModel.upcomingScheduledTransactionsInWindow.count, 1)
        XCTAssertEqual(viewModel.upcomingScheduledTransactionsInWindow.first?.id, withinWindowGenerated.id)
    }

    @MainActor
    func testRevealUpcomingScheduledShowsHiddenGeneratedTransactionsInFilteredList() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Hint Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let generated = Transaction(
            amount: 55,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 2, to: .now)!,
            recurringTemplateId: UUID(),
            account: account
        )
        context.insert(generated)
        try context.save()

        TransactionListPreference.showUpcomingScheduled = false
        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()

        XCTAssertFalse(viewModel.filteredTransactions.map(\.id).contains(generated.id))

        viewModel.revealUpcomingScheduled()

        XCTAssertTrue(viewModel.showUpcomingScheduled)
        XCTAssertTrue(viewModel.filteredTransactions.map(\.id).contains(generated.id))
    }

    @MainActor
    func testHideUpcomingScheduledHidesGeneratedTransactionsInFilteredList() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Hint Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let generated = Transaction(
            amount: 55,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 2, to: .now)!,
            recurringTemplateId: UUID(),
            account: account
        )
        context.insert(generated)
        try context.save()

        TransactionListPreference.showUpcomingScheduled = true
        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()

        XCTAssertTrue(viewModel.filteredTransactions.map(\.id).contains(generated.id))
        XCTAssertTrue(viewModel.shouldShowUpcomingHintBar)

        viewModel.hideUpcomingScheduled()

        XCTAssertFalse(viewModel.showUpcomingScheduled)
        XCTAssertFalse(viewModel.filteredTransactions.map(\.id).contains(generated.id))
        XCTAssertTrue(viewModel.shouldShowUpcomingHintBar)
    }

    @MainActor
    func testVisibleUpcomingSectionUsesDedicatedRowsWithoutDuplicationInTimeline() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Upcoming Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let generatedFuture = Transaction(
            amount: 60,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
            recurringTemplateId: UUID(),
            account: account
        )
        let manualToday = Transaction(
            amount: 20,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            account: account
        )
        context.insert(generatedFuture)
        context.insert(manualToday)
        try context.save()

        TransactionListPreference.showUpcomingScheduled = true
        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()

        XCTAssertTrue(viewModel.visibleUpcomingScheduledRows.map(\.id).contains(generatedFuture.id))
        let timelineIDs = viewModel.groupedTransactionRows.flatMap(\.rows).map(\.id)
        XCTAssertFalse(timelineIDs.contains(generatedFuture.id))
        XCTAssertTrue(timelineIDs.contains(manualToday.id))
    }

    @MainActor
    func testHasVisibleTransactionsIsTrueWhenOnlyUpcomingScheduledRowsExist() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Upcoming Only Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let generatedFuture = Transaction(
            amount: 60,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
            recurringTemplateId: UUID(),
            account: account
        )
        context.insert(generatedFuture)
        try context.save()

        TransactionListPreference.showUpcomingScheduled = true
        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()

        XCTAssertTrue(viewModel.groupedTransactionRows.isEmpty)
        XCTAssertEqual(viewModel.visibleUpcomingScheduledRows.map(\.id), [generatedFuture.id])
        XCTAssertTrue(viewModel.hasVisibleTransactions)
    }

    @MainActor
    func testClearFiltersResetsToShowUpcomingScheduledByDefault() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Clear Filter Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let generated = Transaction(
            amount: 55,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 2, to: .now)!,
            recurringTemplateId: UUID(),
            account: account
        )
        context.insert(generated)
        try context.save()

        TransactionListPreference.showUpcomingScheduled = false
        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()
        XCTAssertFalse(viewModel.filteredTransactions.map(\.id).contains(generated.id))

        viewModel.selectedType = .expense
        viewModel.clearFilters()

        XCTAssertTrue(viewModel.showUpcomingScheduled)
        XCTAssertTrue(viewModel.filteredTransactions.map(\.id).contains(generated.id))
    }

    @MainActor
    func testTravelTransactionFilterShowsOnlyTravelTransactions() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Travel Filter Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let travelTransaction = Transaction(
            amount: 55,
            currencyCode: "JPY",
            type: .expense,
            date: .now,
            notes: "Travel",
            isTravelTransaction: true,
            account: account
        )
        let regularTransaction = Transaction(
            amount: 30,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            notes: "Regular",
            isTravelTransaction: false,
            account: account
        )
        context.insert(travelTransaction)
        context.insert(regularTransaction)
        try context.save()

        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()

        viewModel.showTravelTransactionsOnly = true
        viewModel.applyFilters()

        XCTAssertEqual(viewModel.filteredTransactions.map(\.id), [travelTransaction.id])
        XCTAssertTrue(viewModel.hasFilters)
    }

    @MainActor
    func testClearFiltersResetsTravelTransactionFilter() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Travel Filter Reset Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let travelTransaction = Transaction(
            amount: 55,
            currencyCode: "JPY",
            type: .expense,
            date: .now,
            notes: "Travel",
            isTravelTransaction: true,
            account: account
        )
        let regularTransaction = Transaction(
            amount: 30,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            notes: "Regular",
            isTravelTransaction: false,
            account: account
        )
        context.insert(travelTransaction)
        context.insert(regularTransaction)
        try context.save()

        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()

        viewModel.showTravelTransactionsOnly = true
        viewModel.applyFilters()
        XCTAssertEqual(viewModel.filteredTransactions.map(\.id), [travelTransaction.id])

        viewModel.clearFilters()

        XCTAssertFalse(viewModel.showTravelTransactionsOnly)
        XCTAssertEqual(
            Set(viewModel.filteredTransactions.map(\.id)),
            Set([travelTransaction.id, regularTransaction.id])
        )
    }

    @MainActor
    func testUpcomingHintHiddenWhenContentFiltersAreActive() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Hint Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let generated = Transaction(
            amount: 40,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 4, to: .now)!,
            recurringTemplateId: UUID(),
            account: account
        )
        context.insert(generated)
        try context.save()

        TransactionListPreference.showUpcomingScheduled = false
        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()
        XCTAssertTrue(viewModel.shouldShowUpcomingHintBar)

        viewModel.selectedType = .expense
        viewModel.applyFilters()

        XCTAssertFalse(viewModel.shouldShowUpcomingHintBar)
    }

    @MainActor
    func testUpcomingHintHiddenWhenTravelFilterIsActive() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Travel Hint Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let generated = Transaction(
            amount: 40,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 4, to: .now)!,
            recurringTemplateId: UUID(),
            account: account
        )
        let travelTransaction = Transaction(
            amount: 22,
            currencyCode: "JPY",
            type: .expense,
            date: .now,
            isTravelTransaction: true,
            account: account
        )
        context.insert(generated)
        context.insert(travelTransaction)
        try context.save()

        TransactionListPreference.showUpcomingScheduled = false
        let viewModel = TransactionListViewModel(modelContext: context)
        await viewModel.loadTransactions()
        XCTAssertTrue(viewModel.shouldShowUpcomingHintBar)

        viewModel.showTravelTransactionsOnly = true
        viewModel.applyFilters()

        XCTAssertFalse(viewModel.shouldShowUpcomingHintBar)
        XCTAssertEqual(viewModel.filteredTransactions.map(\.id), [travelTransaction.id])
    }
    
    func testReportPeriodDateRangesUseExpectedBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let referenceDate = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 14,
            hour: 15,
            minute: 30
        ))!
        
        let monthRange = ReportsViewModel.ReportPeriod.month.dateRange(
            referenceDate: referenceDate,
            calendar: calendar
        )
        XCTAssertEqual(
            monthRange.start,
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))
        )
        XCTAssertEqual(monthRange.end, referenceDate)
        
        let lastMonthRange = ReportsViewModel.ReportPeriod.lastMonth.dateRange(
            referenceDate: referenceDate,
            calendar: calendar
        )
        XCTAssertEqual(
            lastMonthRange.start,
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))
        )
        XCTAssertEqual(
            lastMonthRange.end,
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 23, minute: 59, second: 59))
        )
        
        let quarterRange = ReportsViewModel.ReportPeriod.quarter.dateRange(
            referenceDate: referenceDate,
            calendar: calendar
        )
        XCTAssertEqual(
            quarterRange.start,
            calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))
        )
        XCTAssertEqual(quarterRange.end, referenceDate)
        
        let yearRange = ReportsViewModel.ReportPeriod.year.dateRange(
            referenceDate: referenceDate,
            calendar: calendar
        )
        let expectedYearStart = calendar.date(
            byAdding: .month,
            value: -11,
            to: calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        )
        XCTAssertEqual(
            yearRange.start,
            expectedYearStart
        )
        XCTAssertEqual(yearRange.end, referenceDate)
        
        let allRange = ReportsViewModel.ReportPeriod.all.dateRange(
            referenceDate: referenceDate,
            calendar: calendar
        )
        XCTAssertEqual(allRange.start, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(allRange.end, referenceDate)
    }
    
    @MainActor
    func testSetCustomRangeNormalizesStartAndEndDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let later = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20))!
        let earlier = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5))!
        
        let normalized = ReportsViewModel.normalizedDateRange(start: later, end: earlier)
        
        XCTAssertEqual(normalized.start, earlier)
        XCTAssertEqual(normalized.end, later)
    }
    
    @MainActor
    func testDefaultDataSeederCreatesDefaultAccountsWhenNoneExist() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let seeder = DefaultDataSeeder(context: context)
        
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Account>()), 0)
        
        try await seeder.seedIfNeeded()
        
        let accounts = try context.fetch(FetchDescriptor<Account>())
        XCTAssertEqual(accounts.count, 3)
        
        let names = Set(accounts.map(\.name))
        XCTAssertTrue(names.contains("Cash"))
        XCTAssertTrue(names.contains("Bank Account"))
        XCTAssertTrue(names.contains("Credit Card"))
    }
    
    @MainActor
    func testDefaultDataSeederDoesNotDuplicateExistingAccounts() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let seeder = DefaultDataSeeder(context: context)
        
        try await seeder.seedIfNeeded()
        let firstCount = try context.fetchCount(FetchDescriptor<Account>())
        
        try await seeder.seedIfNeeded()
        let secondCount = try context.fetchCount(FetchDescriptor<Account>())
        
        XCTAssertEqual(firstCount, 3)
        XCTAssertEqual(secondCount, 3)
    }

    @MainActor
    func testDashboardDisplayCurrencyUsesUserPreference() throws {
        XCTAssertEqual(
            DashboardViewModel.resolvedDisplayCurrencyCode(preferredCurrencyCode: "TWD"),
            "TWD"
        )
    }

    @MainActor
    func testDashboardDisplayCurrencyFallsBackForUnsupportedPreference() throws {
        let resolvedCode = DashboardViewModel.resolvedDisplayCurrencyCode(
            preferredCurrencyCode: "INVALID"
        )
        XCTAssertTrue(SupportedCurrency(rawValue: resolvedCode) != nil)
    }

    @MainActor
    func testUserCurrencyPreferenceResolvesValidCode() throws {
        XCTAssertEqual(
            UserCurrencyPreference.resolvedDisplayCurrencyCode(preferredCurrencyCode: "EUR"),
            "EUR"
        )
    }

    @MainActor
    func testUserCurrencyPreferenceResolvesInvalidCodeToSupportedCurrency() throws {
        let resolvedCode = UserCurrencyPreference.resolvedDisplayCurrencyCode(
            preferredCurrencyCode: "NOT_A_CURRENCY"
        )
        XCTAssertTrue(SupportedCurrency(rawValue: resolvedCode) != nil)
    }

    func testConversionModeDefaultsForDashboardAndReports() {
        XCTAssertEqual(ConversionMode.defaultForDashboard, .latest)
        XCTAssertEqual(ConversionMode.defaultForReports, .historical)
    }

    @MainActor
    func testDashboardLoadDataConvertsMixedCurrencyTotalsUsingLatestRates() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext

        let usdAccount = Account(name: "USD Wallet", type: .cash, currencyCode: "USD")
        let twdAccount = Account(name: "TWD Wallet", type: .cash, currencyCode: "TWD")
        context.insert(usdAccount)
        context.insert(twdAccount)

        context.insert(
            Transaction(
                amount: 50,
                currencyCode: "USD",
                type: .income,
                date: .now,
                account: usdAccount
            )
        )
        context.insert(
            Transaction(
                amount: 3200,
                currencyCode: "TWD",
                type: .income,
                date: .now,
                account: twdAccount
            )
        )
        context.insert(
            Transaction(
                amount: 10,
                currencyCode: "USD",
                type: .expense,
                date: .now,
                account: usdAccount
            )
        )
        context.insert(
            Transaction(
                amount: 64,
                currencyCode: "TWD",
                type: .expense,
                date: .now,
                account: twdAccount
            )
        )

        let calendar = Calendar(identifier: .gregorian)
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!
        context.insert(
            ExchangeRate(
                baseCurrencyCode: "USD",
                quoteCurrencyCode: "TWD",
                rate: 30,
                effectiveDate: day1
            )
        )
        context.insert(
            ExchangeRate(
                baseCurrencyCode: "USD",
                quoteCurrencyCode: "TWD",
                rate: 32,
                effectiveDate: day2
            )
        )
        try context.save()

        UserCurrencyPreference.currencyCode = "USD"
        let viewModel = DashboardViewModel(modelContext: context)
        await viewModel.loadData()

        XCTAssertEqual(viewModel.totalBalance, 138)
        XCTAssertEqual(viewModel.monthlyIncome, 150)
        XCTAssertEqual(viewModel.monthlyExpenses, 12)
    }

    @MainActor
    func testReportsUseHistoricalRatesForTransactionDates() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext

        let account = Account(name: "TWD Wallet", type: .cash, currencyCode: "TWD")
        context.insert(account)

        let calendar = Calendar(identifier: .gregorian)
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!

        context.insert(
            Transaction(
                amount: 3000,
                currencyCode: "TWD",
                type: .income,
                date: day1,
                account: account
            )
        )
        context.insert(
            Transaction(
                amount: 3200,
                currencyCode: "TWD",
                type: .income,
                date: day2,
                account: account
            )
        )

        context.insert(
            ExchangeRate(
                baseCurrencyCode: "USD",
                quoteCurrencyCode: "TWD",
                rate: 30,
                effectiveDate: day1
            )
        )
        context.insert(
            ExchangeRate(
                baseCurrencyCode: "USD",
                quoteCurrencyCode: "TWD",
                rate: 32,
                effectiveDate: day2
            )
        )
        try context.save()

        UserCurrencyPreference.currencyCode = "USD"
        let viewModel = ReportsViewModel(modelContext: context)
        viewModel.selectedPeriod = .all
        await viewModel.loadReports()

        XCTAssertEqual(viewModel.totalIncome, 200)
        XCTAssertEqual(viewModel.monthlyTrends.count, 1)
        XCTAssertEqual(viewModel.monthlyTrends.first?.income, 200)
    }

    @MainActor
    func testReportsAllPeriodIncludesPreviousYearTransactions() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext

        let account = Account(name: "USD Wallet", type: .cash, currencyCode: "USD")
        context.insert(account)

        let calendar = Calendar(identifier: .gregorian)
        let dec2025 = calendar.date(from: DateComponents(year: 2025, month: 12, day: 10))!
        let jan2026 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!

        context.insert(
            Transaction(
                amount: 100,
                currencyCode: "USD",
                type: .expense,
                date: dec2025,
                account: account
            )
        )
        context.insert(
            Transaction(
                amount: 50,
                currencyCode: "USD",
                type: .expense,
                date: jan2026,
                account: account
            )
        )

        try context.save()

        UserCurrencyPreference.currencyCode = "USD"
        let viewModel = ReportsViewModel(modelContext: context)
        viewModel.selectedPeriod = .all
        await viewModel.loadReports()

        XCTAssertEqual(viewModel.totalExpenses, 150)
    }
    
    @MainActor
    func testAvailableCategoryBreakdownTypesReflectAvailableData() {
        let expenseCategories: [ReportsViewModel.CategorySummary] = [
            .init(category: nil, categoryName: "Food", amount: 30, percentage: 60, color: .red)
        ]
        let incomeCategories: [ReportsViewModel.CategorySummary] = [
            .init(category: nil, categoryName: "Salary", amount: 100, percentage: 100, color: .green)
        ]

        let both = ReportsViewModel.availableCategoryBreakdownTypes(
            expenseCategories: expenseCategories,
            incomeCategories: incomeCategories
        )
        XCTAssertEqual(both, [.expense, .income])

        let onlyIncome = ReportsViewModel.availableCategoryBreakdownTypes(
            expenseCategories: [],
            incomeCategories: incomeCategories
        )
        XCTAssertEqual(onlyIncome, [.income])

        let none = ReportsViewModel.availableCategoryBreakdownTypes(
            expenseCategories: [],
            incomeCategories: []
        )
        XCTAssertTrue(none.isEmpty)
    }

    @MainActor
    func testCategoriesForBreakdownReturnMatchingData() {
        let expenseCategories: [ReportsViewModel.CategorySummary] = [
            .init(category: nil, categoryName: "Food", amount: 30, percentage: 60, color: .red)
        ]
        let incomeCategories: [ReportsViewModel.CategorySummary] = [
            .init(category: nil, categoryName: "Salary", amount: 100, percentage: 100, color: .green)
        ]

        let expenseResult = ReportsViewModel.categoriesForBreakdown(
            .expense,
            expenseCategories: expenseCategories,
            incomeCategories: incomeCategories
        )
        XCTAssertEqual(expenseResult.count, 1)
        XCTAssertEqual(expenseResult.first?.categoryName, "Food")

        let incomeResult = ReportsViewModel.categoriesForBreakdown(
            .income,
            expenseCategories: expenseCategories,
            incomeCategories: incomeCategories
        )
        XCTAssertEqual(incomeResult.count, 1)
        XCTAssertEqual(incomeResult.first?.categoryName, "Salary")
    }

    @MainActor
    func testCategoryChartSlicesRollupTailCategoriesIntoOtherSegment() {
        let categories: [ReportsViewModel.CategorySummary] = [
            .init(category: nil, categoryName: "Food", amount: 45, percentage: 45, color: .red),
            .init(category: nil, categoryName: "Transport", amount: 25, percentage: 25, color: .blue),
            .init(category: nil, categoryName: "Shopping", amount: 10, percentage: 10, color: .green),
            .init(category: nil, categoryName: "Bills", amount: 8, percentage: 8, color: .orange),
            .init(category: nil, categoryName: "Health", amount: 6, percentage: 6, color: .pink),
            .init(category: nil, categoryName: "Other A", amount: 4, percentage: 4, color: .purple),
            .init(category: nil, categoryName: "Other B", amount: 2, percentage: 2, color: .teal)
        ]

        let slices = ReportsViewModel.categoryChartSlices(
            from: categories,
            maxVisibleCategories: 5,
            otherCategoryName: "Other",
            otherColor: .gray
        )

        XCTAssertEqual(slices.count, 6)
        XCTAssertEqual(slices[0].name, "Food")
        XCTAssertEqual(slices[4].name, "Health")
        XCTAssertEqual(slices[5].name, "Other")
        XCTAssertEqual(slices[5].amount, 6)
    }

    @MainActor
    func testCategoryChartSlicesKeepOriginalOrderWhenAtOrUnderLimit() {
        let categories: [ReportsViewModel.CategorySummary] = [
            .init(category: nil, categoryName: "Food", amount: 60, percentage: 60, color: .red),
            .init(category: nil, categoryName: "Transport", amount: 40, percentage: 40, color: .blue)
        ]

        let slices = ReportsViewModel.categoryChartSlices(
            from: categories,
            maxVisibleCategories: 5,
            otherCategoryName: "Other",
            otherColor: .gray
        )

        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices[0].name, "Food")
        XCTAssertEqual(slices[1].name, "Transport")
        XCTAssertEqual(slices[0].amount, 60)
        XCTAssertEqual(slices[1].amount, 40)
    }

    @MainActor
    func testCategoryRowsDisplayStateCollapsedShowsConfiguredLimitAndHiddenCount() {
        let categories: [ReportsViewModel.CategorySummary] = (1...7).map { index in
            .init(
                category: nil,
                categoryName: "Category \(index)",
                amount: Decimal(index),
                percentage: Double(index),
                color: .blue
            )
        }

        let state = ReportsViewModel.categoryRowsDisplayState(
            from: categories,
            rowLimit: 5,
            isExpanded: false
        )

        XCTAssertEqual(state.visible.count, 5)
        XCTAssertEqual(state.visible.first?.categoryName, "Category 1")
        XCTAssertEqual(state.visible.last?.categoryName, "Category 5")
        XCTAssertEqual(state.hiddenCount, 2)
    }

    @MainActor
    func testCategoryRowsDisplayStateExpandedShowsAllRows() {
        let categories: [ReportsViewModel.CategorySummary] = (1...7).map { index in
            .init(
                category: nil,
                categoryName: "Category \(index)",
                amount: Decimal(index),
                percentage: Double(index),
                color: .green
            )
        }

        let state = ReportsViewModel.categoryRowsDisplayState(
            from: categories,
            rowLimit: 5,
            isExpanded: true
        )

        XCTAssertEqual(state.visible.count, 7)
        XCTAssertEqual(state.hiddenCount, 0)
    }

    func testReportsCategoryRowLimitPreferenceNormalizesUnsupportedValueToDefault() {
        XCTAssertEqual(
            ReportsCategoryRowLimitPreference.normalized(9),
            ReportsCategoryRowLimitPreference.defaultValue
        )
    }

    @MainActor
    func testCategoryRowsDisplayStateNormalizesZeroLimitToAtLeastOneVisibleRow() {
        let categories: [ReportsViewModel.CategorySummary] = (1...3).map { index in
            .init(
                category: nil,
                categoryName: "Category \(index)",
                amount: Decimal(index),
                percentage: Double(index),
                color: .orange
            )
        }

        let state = ReportsViewModel.categoryRowsDisplayState(
            from: categories,
            rowLimit: 0,
            isExpanded: false
        )

        XCTAssertEqual(state.visible.count, 1)
        XCTAssertEqual(state.hiddenCount, 2)
    }
    
    @MainActor
    func testBudgetListTotalsConvertToDisplayCurrency() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext

        let category = Category(
            nameKey: "category.expense.food",
            icon: "fork.knife",
            colorHex: "#FF0000",
            type: .expense,
            isSystemDefault: false
        )
        context.insert(category)

        let account = Account(name: "TWD Wallet", type: .cash, currencyCode: "TWD")
        context.insert(account)

        let budget = Budget(
            limitAmount: 3200,
            currencyCode: "TWD",
            period: .monthly,
            category: category
        )
        context.insert(budget)

        context.insert(
            Transaction(
                amount: 1600,
                currencyCode: "TWD",
                type: .expense,
                date: .now,
                account: account,
                category: category
            )
        )

        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!
        context.insert(
            ExchangeRate(
                baseCurrencyCode: "USD",
                quoteCurrencyCode: "TWD",
                rate: 32,
                effectiveDate: day
            )
        )
        try context.save()

        UserCurrencyPreference.currencyCode = "USD"
        let viewModel = BudgetListViewModel(modelContext: context)
        await viewModel.loadBudgets()

        XCTAssertEqual(viewModel.totalBudgeted, 100)
        XCTAssertEqual(viewModel.totalSpent, 50)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    @MainActor
    private func measuredHeight<V: View>(for view: V, width: CGFloat = 320) -> CGFloat {
        let host = UIHostingController(rootView: view)
        let hostedView = host.view!
        hostedView.bounds = CGRect(x: 0, y: 0, width: width, height: 1_000)
        hostedView.backgroundColor = .clear
        hostedView.setNeedsLayout()
        hostedView.layoutIfNeeded()

        let size = hostedView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return size.height
    }

}
