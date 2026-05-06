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
    }
}
