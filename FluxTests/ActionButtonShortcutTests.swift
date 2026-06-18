import XCTest
@testable import Flux

@MainActor
final class ActionButtonShortcutTests: XCTestCase {
    func testRouterPublishesExpenseRequest() {
        let router = ActionButtonShortcutRouter()

        router.requestTransactionEntry(type: .expense)

        XCTAssertEqual(router.pendingTransactionEntry?.type, .expense)
    }

    func testRouterPublishesIncomeRequest() {
        let router = ActionButtonShortcutRouter()

        router.requestTransactionEntry(type: .income)

        XCTAssertEqual(router.pendingTransactionEntry?.type, .income)
    }

    func testRepeatedRequestsHaveFreshIdentity() throws {
        let router = ActionButtonShortcutRouter()
        router.requestTransactionEntry(type: .expense)
        let firstID = try XCTUnwrap(router.pendingTransactionEntry?.id)

        router.requestTransactionEntry(type: .expense)
        let secondID = try XCTUnwrap(router.pendingTransactionEntry?.id)

        XCTAssertNotEqual(firstID, secondID)
    }

    func testTransactionEntryDefaultsToExpenseWithoutShortcutRequest() {
        XCTAssertEqual(TransactionEntryInitialType.resolved(nil), .expense)
    }

    func testTransactionEntryUsesShortcutRequestedType() {
        XCTAssertEqual(TransactionEntryInitialType.resolved(.income), .income)
    }
}
