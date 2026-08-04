import SwiftData
import XCTest
@testable import Flux

@MainActor
final class ScheduledPostingStatusMigrationTests: XCTestCase {
    func testMigrationOnlyMarksLegacyGeneratedOccurrencesStrictlyAfterBoundaryPending() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let templateID = UUID()

        let eligibleFuture = makeTransaction(
            date: now.addingTimeInterval(1),
            recurringTemplateId: templateID
        )
        let past = makeTransaction(
            date: now.addingTimeInterval(-1),
            recurringTemplateId: templateID
        )
        let exactBoundary = makeTransaction(date: now, recurringTemplateId: templateID)
        let ordinaryFuture = makeTransaction(date: now.addingTimeInterval(2))
        let template = makeTransaction(
            date: now.addingTimeInterval(3),
            isRecurringTemplate: true
        )
        let confirmedFuture = makeTransaction(
            date: now.addingTimeInterval(4),
            recurringTemplateId: templateID,
            postingStatus: .posted
        )

        for transaction in [
            eligibleFuture, past, exactBoundary, ordinaryFuture, template, confirmedFuture
        ] {
            context.insert(transaction)
        }
        try context.save()

        XCTAssertTrue(
            try ScheduledPostingStatusMigration.runVersionedUpgradeIfNeeded(
                in: context,
                now: now
            )
        )

        XCTAssertEqual(eligibleFuture.postingStatus, .pending)
        XCTAssertNil(past.postingStatusRawValue)
        XCTAssertNil(exactBoundary.postingStatusRawValue)
        XCTAssertNil(ordinaryFuture.postingStatusRawValue)
        XCTAssertNil(template.postingStatusRawValue)
        XCTAssertEqual(confirmedFuture.postingStatus, .posted)
        XCTAssertTrue(
            try ScheduledPostingStatusMigration.hasCompletedVersionedUpgrade(in: context)
        )

        XCTAssertFalse(
            try ScheduledPostingStatusMigration.runVersionedUpgradeIfNeeded(
                in: context,
                now: now
            )
        )
    }

    func testMigrationProcessesLateLegacyOccurrenceAfterStoreMarkerArrives() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertTrue(
            try ScheduledPostingStatusMigration.runVersionedUpgradeIfNeeded(
                in: context,
                now: now
            )
        )

        let lateCloudOccurrence = makeTransaction(
            date: now.addingTimeInterval(60),
            recurringTemplateId: UUID()
        )
        context.insert(lateCloudOccurrence)
        try context.save()

        XCTAssertTrue(
            try ScheduledPostingStatusMigration.runVersionedUpgradeIfNeeded(
                in: context,
                now: now
            )
        )
        XCTAssertEqual(lateCloudOccurrence.postingStatus, .pending)

        let markers = try context.fetch(FetchDescriptor<AppMigrationState>())
            .filter { $0.key == ScheduledPostingStatusMigration.versionedMigrationKey }
        XCTAssertEqual(markers.count, 1)
    }

    private func makeTransaction(
        date: Date,
        recurringTemplateId: UUID? = nil,
        isRecurringTemplate: Bool = false,
        postingStatus: TransactionPostingStatus? = nil
    ) -> Transaction {
        Transaction(
            amount: 10,
            currencyCode: "HKD",
            type: .expense,
            date: date,
            isRecurringTemplate: isRecurringTemplate,
            recurrenceRule: isRecurringTemplate ? .monthly : nil,
            recurringTemplateId: recurringTemplateId,
            postingStatus: postingStatus
        )
    }
}
