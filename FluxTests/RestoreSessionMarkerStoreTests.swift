import XCTest
@testable import Flux

final class RestoreSessionMarkerStoreTests: XCTestCase {
    func testRestoreSessionMarkerStoreRoundTripsAndClearsMarker() throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = RestoreSessionMarkerStore(userDefaults: defaults)
        let marker = RestoreSessionMarker(
            restoreSessionId: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            archiveId: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            mode: .replace,
            scope: .financialDataOnly,
            phase: .preflightPassed,
            recoveryActionHint: "Resume restore or clear the staged session."
        )

        try store.save(marker)

        XCTAssertEqual(try store.load(), marker)

        store.clear()

        XCTAssertNil(try store.load())
    }

    func testStartupRecoveryConsumesStaleRestoreMarker() throws {
        let store = InMemoryRestoreSessionMarkerStore()
        let marker = RestoreSessionMarker(
            restoreSessionId: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            archiveId: UUID(),
            mode: .replace,
            scope: .financialDataOnly,
            phase: .importPass1,
            recoveryActionHint: "Retry restore."
        )
        try store.save(marker)

        let recovered = RestoreSessionStartupRecovery.consumeMarkerIfPresent(from: store)

        XCTAssertEqual(recovered, marker)
        XCTAssertNil(try store.load())
    }
}
