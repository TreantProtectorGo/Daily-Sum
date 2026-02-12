//
//  FluxTests.swift
//  FluxTests
//
//  Created by Wing - on 9/2/2026.
//

import XCTest
import SwiftData
@testable import Flux

final class FluxTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
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
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))
        )
        XCTAssertEqual(quarterRange.end, referenceDate)
        
        let yearRange = ReportsViewModel.ReportPeriod.year.dateRange(
            referenceDate: referenceDate,
            calendar: calendar
        )
        XCTAssertEqual(
            yearRange.start,
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))
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

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
