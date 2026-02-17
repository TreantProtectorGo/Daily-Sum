//
//  FluxTests.swift
//  FluxTests
//
//  Created by Wing - on 9/2/2026.
//

import XCTest
import SwiftData
import SwiftUI
@testable import Flux

final class FluxTests: XCTestCase {
    private var originalPreferredCurrencyCode: String?
    private var originalUseLocationDefaults: Bool?

    override func setUpWithError() throws {
        originalPreferredCurrencyCode = UserDefaults.standard.string(
            forKey: UserCurrencyPreference.storageKey
        )
        originalUseLocationDefaults = UserDefaults.standard.object(
            forKey: TravelCurrencyPreference.storageKey
        ) as? Bool
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.set(
            originalPreferredCurrencyCode,
            forKey: UserCurrencyPreference.storageKey
        )
        if let originalUseLocationDefaults {
            UserDefaults.standard.set(
                originalUseLocationDefaults,
                forKey: TravelCurrencyPreference.storageKey
            )
        } else {
            UserDefaults.standard.removeObject(forKey: TravelCurrencyPreference.storageKey)
        }
    }

    func testTravelCurrencyPreferencePersistsValue() {
        TravelCurrencyPreference.useLocationDefaults = false
        XCTAssertFalse(TravelCurrencyPreference.useLocationDefaults)

        TravelCurrencyPreference.useLocationDefaults = true
        XCTAssertTrue(TravelCurrencyPreference.useLocationDefaults)
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
        XCTAssertEqual(
            yearRange.start,
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))
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

}
