import XCTest

final class DashboardAccountsNavigationTests: XCTestCase {
    func testDashboardAccountsViewAllUsesDedicatedAccountsList() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Flux")
            .appendingPathComponent("Views")
            .appendingPathComponent("DashboardView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("TODO: Full accounts list"))
        XCTAssertFalse(source.contains("Text(\"All Accounts\")"))
        XCTAssertTrue(source.contains("AccountsListView"))
        XCTAssertTrue(source.contains("accountsSectionHeader(viewModel: viewModel)"))
        XCTAssertTrue(source.contains("BalanceOverviewCard("))
        XCTAssertTrue(source.contains("defaultValue: \"主頁\""))
        XCTAssertFalse(source.contains("BalanceTrendSection("))
        XCTAssertFalse(source.contains("BalanceDetailView("))
    }

    func testAccountsListAddButtonUsesBottomTrailingFloatingActionButton() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Flux")
            .appendingPathComponent("Views")
            .appendingPathComponent("AccountsListView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains(".overlay(alignment: .bottomTrailing)"))
        XCTAssertTrue(source.contains("FloatingActionButton"))
        XCTAssertTrue(source.contains(".padding(.trailing, 25)"))
        XCTAssertTrue(source.contains(".padding(.bottom, 20)"))
        XCTAssertFalse(source.contains("ToolbarItem(placement: .topBarTrailing)"))
    }

    func testDashboardDoesNotShowMonthlyIncomeExpenseSummaryCards() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Flux")
            .appendingPathComponent("Views")
            .appendingPathComponent("DashboardView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("monthlySummarySection"))
        XCTAssertFalse(source.contains("dashboard.income"))
        XCTAssertFalse(source.contains("dashboard.expenses"))
        XCTAssertFalse(source.contains("viewModel.monthlyIncome"))
        XCTAssertFalse(source.contains("viewModel.monthlyExpenses"))
    }

    func testDashboardTabUsesHomeLabel() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Flux")
            .appendingPathComponent("Views")
            .appendingPathComponent("MainTabView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("AppLocalization.string(\"tab.dashboard\", defaultValue: \"主頁\")"))
        XCTAssertFalse(source.contains("AppLocalization.string(\"tab.dashboard\", defaultValue: \"Dashboard\")"))
    }

    func testDashboardMergesTotalBalanceAndTrendIntoHeroCard() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Flux")
            .appendingPathComponent("Views")
            .appendingPathComponent("DashboardView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("BalanceOverviewCard("))
        XCTAssertFalse(source.contains("balanceCard(viewModel: viewModel)"))
        XCTAssertFalse(source.contains("BalanceTrendSection("))
        XCTAssertFalse(source.contains("NavigationLink {\n            BalanceDetailView("))
    }

    func testBalanceOverviewCardUsesMergedTrendLayout() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Flux")
            .appendingPathComponent("Views")
            .appendingPathComponent("BalanceOverviewCard.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("import Charts"))
        XCTAssertTrue(source.contains("enum BalanceTrendRange"))
        XCTAssertTrue(source.contains("case week"))
        XCTAssertTrue(source.contains("case oneMonth"))
        XCTAssertTrue(source.contains("case threeMonths"))
        XCTAssertTrue(source.contains("case oneYear"))
        XCTAssertTrue(source.contains("case all"))
        XCTAssertFalse(source.contains("case monthToDate"))
        XCTAssertTrue(source.contains("struct BalanceOverviewCard"))
        XCTAssertTrue(source.contains("LineMark"))
        XCTAssertTrue(source.contains("AreaMark"))
        XCTAssertTrue(source.contains("rangeSummaryText"))
        let rangeSummaryBody = try XCTUnwrap(
            source.range(of: "private var rangeSummaryText: String")?.lowerBound
        )
        let rangeSummarySource = String(source[rangeSummaryBody...])
            .prefix(500)
        XCTAssertFalse(rangeSummarySource.contains("selectedRange.summaryTitle"))
        XCTAssertTrue(rangeSummarySource.contains("return \"\\(amount) (\\(percent))\""))
        XCTAssertTrue(source.contains("BalanceTrendCalculator"))
        XCTAssertTrue(source.contains("Text(currency: totalBalance, code: currencyCode)"))
        XCTAssertTrue(source.contains(".frame(height: 180)"))
        XCTAssertTrue(source.contains(".accessibilityIdentifier(\"dashboard.totalBalance.card\")"))
        XCTAssertTrue(source.contains(".accessibilityIdentifier(\"dashboard.balanceTrend.chart\")"))
    }
}
