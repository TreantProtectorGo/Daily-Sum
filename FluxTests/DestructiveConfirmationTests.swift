import XCTest
@testable import Flux

final class DestructiveConfirmationTests: XCTestCase {
    func testAccountDeleteConfirmationUsesSpecificDestructiveActionCopy() {
        let confirmation = DestructiveConfirmation.accountDelete

        XCTAssertEqual(confirmation.title, "Delete this account?")
        XCTAssertEqual(confirmation.destructiveTitle, "Delete Account")
        XCTAssertEqual(confirmation.cancelTitle, "Cancel")
        XCTAssertNotEqual(confirmation.destructiveTitle, "Confirm")
        XCTAssertTrue(confirmation.message.contains("transactions"))
    }

    func testClearDataConfirmationUsesSpecificDestructiveActionCopy() {
        let confirmation = DestructiveConfirmation.clearAllData

        XCTAssertEqual(confirmation.title, "Clear all data?")
        XCTAssertEqual(confirmation.destructiveTitle, "Clear All Data")
        XCTAssertEqual(confirmation.cancelTitle, "Cancel")
        XCTAssertNotEqual(confirmation.destructiveTitle, "Confirm")
    }
}
