import Foundation
import SwiftData

/// Introduces confirmation semantics for occurrences generated before posting state existed.
///
/// The store marker records that the versioned migration has run. We still scan for eligible
/// records on later activations because a CloudKit import can deliver an old transaction after
/// its migration marker. The posting-status field is itself the per-record completion marker, so
/// this remains idempotent and never recreates data that the user deleted.
@MainActor
enum ScheduledPostingStatusMigration {
    static let versionedMigrationKey = "flux.scheduledPostingStatus.v1.done"

    @discardableResult
    static func runVersionedUpgradeIfNeeded(
        in context: ModelContext,
        now: Date = .now,
        saveChanges: Bool = true
    ) throws -> Bool {
        var changed = false
        let transactions = try context.fetch(FetchDescriptor<Transaction>())

        for transaction in transactions where isEligibleLegacyOccurrence(transaction, now: now) {
            transaction.postingStatus = .pending
            changed = true
        }

        let markers = try context.fetch(FetchDescriptor<AppMigrationState>())
            .filter { $0.key == versionedMigrationKey }
            .sorted { $0.id.uuidString < $1.id.uuidString }

        if let canonicalMarker = markers.first {
            for duplicate in markers.dropFirst() {
                context.delete(duplicate)
                changed = true
            }
            let earliestCompletion = markers.map(\.completedAt).min() ?? canonicalMarker.completedAt
            if canonicalMarker.completedAt != earliestCompletion {
                canonicalMarker.completedAt = earliestCompletion
                changed = true
            }
        } else {
            context.insert(AppMigrationState(key: versionedMigrationKey))
            changed = true
        }

        if changed && saveChanges {
            try context.save()
        }
        return changed
    }

    static func hasCompletedVersionedUpgrade(in context: ModelContext) throws -> Bool {
        try context.fetch(FetchDescriptor<AppMigrationState>())
            .contains { $0.key == versionedMigrationKey }
    }

    private static func isEligibleLegacyOccurrence(
        _ transaction: Transaction,
        now: Date
    ) -> Bool {
        !transaction.isRecurringTemplate &&
            transaction.recurringTemplateId != nil &&
            transaction.postingStatusRawValue == nil &&
            transaction.date > now
    }
}
