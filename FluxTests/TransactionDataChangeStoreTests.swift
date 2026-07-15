import XCTest
@testable import Flux

@MainActor
final class TransactionDataChangeStoreTests: XCTestCase {
    func testMarkChangedAdvancesRevisionExactlyOnce() {
        let store = TransactionDataChangeStore()
        let initialRevision = store.revision

        store.markChanged()

        XCTAssertEqual(store.revision, initialRevision + 1)
    }
}
