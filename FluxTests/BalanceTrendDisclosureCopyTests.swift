import XCTest
@testable import Flux

final class BalanceTrendDisclosureCopyTests: XCTestCase {
    func testCollapsedSummaryIncludesRangeAndAccountCount() {
        XCTAssertEqual(
            BalanceTrendDisclosureCopy.summary(
                range: .week,
                accountCount: 3,
                hasAccounts: true
            ),
            "1W · 3 accounts"
        )
    }

    func testCollapsedSummaryOmitsAccountCountWhenNoAccountsExist() {
        XCTAssertEqual(
            BalanceTrendDisclosureCopy.summary(
                range: .oneMonth,
                accountCount: 0,
                hasAccounts: false
            ),
            "1M"
        )
    }

    func testAccessibilityLabelReflectsExpandedState() {
        XCTAssertEqual(
            BalanceTrendDisclosureCopy.accessibilityLabel(isExpanded: true),
            "Hide balance trend"
        )
        XCTAssertEqual(
            BalanceTrendDisclosureCopy.accessibilityLabel(isExpanded: false),
            "Show balance trend"
        )
    }
}
