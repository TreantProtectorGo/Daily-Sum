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

    func testDashboardFooterViewAllLinksShareLabelAndBudgetNavigation() throws {
        let dashboardSource = try sourceContents(at: "Flux/Views/DashboardView.swift")
        let mainTabSource = try sourceContents(at: "Flux/Views/MainTabView.swift")

        XCTAssertTrue(dashboardSource.contains("private struct DashboardViewAllFooterLink"))
        XCTAssertTrue(dashboardSource.contains("private struct DashboardViewAllFooterLabel"))
        XCTAssertTrue(dashboardSource.contains("DashboardViewAllFooterLink(action: onViewAllTransactions)"))
        XCTAssertTrue(dashboardSource.contains("DashboardViewAllFooterLink(action: onViewAllBudgets)"))
        XCTAssertTrue(dashboardSource.contains("dashboard.budgets.viewAll"))
        XCTAssertTrue(dashboardSource.contains("dashboard.viewAll\", defaultValue: \"View All\""))
        XCTAssertTrue(dashboardSource.contains("Image(systemName: \"chevron.right\")"))
        XCTAssertFalse(dashboardSource.contains("dashboard.viewAllInReports"))
        XCTAssertFalse(dashboardSource.contains("Image(systemName: \"arrow.right\")"))

        XCTAssertTrue(mainTabSource.contains("onViewAllBudgets:"))
        XCTAssertTrue(mainTabSource.contains("selectedTabBinding.wrappedValue = .budgets"))
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
        XCTAssertTrue(rangeSummarySource.contains("return amount"))
        XCTAssertFalse(rangeSummarySource.contains("percent"))
        XCTAssertFalse(source.contains("BalanceTrendCalculator"))
        XCTAssertTrue(source.contains("BalanceTrendChartSeries"))
        XCTAssertTrue(source.contains("Text(currency: totalBalance, code: currencyCode)"))
        XCTAssertTrue(source.contains(".frame(height: isCompact ? 44 : 180)"))
        XCTAssertTrue(source.contains(".accessibilityIdentifier(\"dashboard.totalBalance.card\")"))
        XCTAssertTrue(source.contains(".accessibilityIdentifier(\"dashboard.balanceTrend.chart\")"))
    }

    private var repositoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sourceContents(at relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryURL.appending(path: relativePath),
            encoding: .utf8
        )
    }
}
