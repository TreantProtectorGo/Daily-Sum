import XCTest
@testable import Flux

@MainActor
final class AmountInputSessionTests: XCTestCase {
    func testPresentationCanExpandAndCollapseWithoutChangingAmount() {
        let session = AmountInputSession()

        session.present(currentAmount: 12)
        XCTAssertTrue(session.isPresented)

        let dismissal = session.collapse(currentAmount: 12)
        XCTAssertFalse(session.isPresented)
        XCTAssertEqual(dismissal.amount, 12)
        XCTAssertFalse(dismissal.didConfirm)
    }

    func testConfirmCommitsExpressionAndCollapsesDock() {
        let session = AmountInputSession()
        session.present(currentAmount: 0)

        _ = session.perform(.digit(1), currentAmount: 0)
        _ = session.perform(.digit(2), currentAmount: 1)
        _ = session.perform(.operation(.add), currentAmount: 12)
        _ = session.perform(.digit(3), currentAmount: 12)
        let mutation = session.perform(.confirm, currentAmount: 12)

        XCTAssertEqual(mutation.amount, 15)
        XCTAssertTrue(mutation.didConfirm)
        XCTAssertFalse(session.isPresented)
    }

    func testFirstAcceptedInputIsReportedOnlyOnce() {
        let session = AmountInputSession()
        session.present(currentAmount: 0)

        let first = session.perform(.digit(1), currentAmount: 0)
        let second = session.perform(.digit(2), currentAmount: 1)

        XCTAssertTrue(first.didAcceptFirstInput)
        XCTAssertFalse(second.didAcceptFirstInput)
    }
}
