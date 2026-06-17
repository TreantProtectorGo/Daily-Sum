import XCTest
@testable import Flux

final class IconManagementReorderTests: XCTestCase {
    func testMovingFirstRowToLaterDestinationPlacesItAtDestination() {
        let result = IconManagementReorder.reordered(
            items: ["Cash", "Bank", "Card"],
            sourceIndex: 0,
            destinationIndex: 2
        )

        XCTAssertEqual(result, ["Bank", "Card", "Cash"])
    }

    func testMovingLastRowToEarlierDestinationPlacesItBeforeDestination() {
        let result = IconManagementReorder.reordered(
            items: ["Cash", "Bank", "Card"],
            sourceIndex: 2,
            destinationIndex: 0
        )

        XCTAssertEqual(result, ["Card", "Cash", "Bank"])
    }

    func testInvalidMoveReturnsOriginalOrder() {
        let result = IconManagementReorder.reordered(
            items: ["Cash", "Bank", "Card"],
            sourceIndex: 5,
            destinationIndex: 0
        )

        XCTAssertEqual(result, ["Cash", "Bank", "Card"])
    }
}
