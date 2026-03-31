import XCTest
@testable import Flux

final class ImportReportTests: XCTestCase {
    func testImportReportRoundTripPreservesSummaryAndEntries() throws {
        let report = ImportReport(
            archiveId: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
            schemaVersion: 1,
            summary: ImportReportSummary(
                importedCount: 12,
                updatedCount: 3,
                skippedCount: 2,
                failedCount: 1,
                warningCount: 4
            ),
            entries: [
                ImportReportEntry(
                    entityType: "Transaction",
                    entityId: UUID(uuidString: "44444444-4444-4444-4444-444444444444"),
                    action: .failed,
                    severity: .fatal,
                    message: "Missing account reference",
                    conflictReason: "account-not-found",
                    details: [
                        "referencedAccountId": "33333333-3333-3333-3333-333333333333"
                    ]
                ),
                ImportReportEntry(
                    entityType: "Category",
                    entityId: UUID(uuidString: "22222222-2222-2222-2222-222222222222"),
                    action: .skipped,
                    severity: .warning,
                    message: "Duplicate record skipped",
                    conflictReason: "duplicate-id",
                    details: [:]
                )
            ],
            conflictReasons: [
                "duplicate-id",
                "account-not-found"
            ],
            createdAt: Date(timeIntervalSince1970: 1_700_001_000)
        )

        let decoded = try Self.roundTrip(report)

        XCTAssertEqual(decoded, report)
        XCTAssertEqual(decoded.summary.failedCount, 1)
        XCTAssertEqual(decoded.entries.first?.severity, .fatal)
    }

    func testImportReportEntryPreservesMachineReadableMetadata() throws {
        let entry = ImportReportEntry(
            entityType: "Budget",
            entityId: UUID(uuidString: "99999999-9999-9999-9999-999999999999"),
            action: .updated,
            severity: .info,
            message: "Budget merged",
            conflictReason: nil,
            details: [
                "categoryId": "22222222-2222-2222-2222-222222222222",
                "sourceMode": "merge"
            ]
        )

        let decoded = try Self.roundTrip(entry)

        XCTAssertEqual(decoded, entry)
        XCTAssertEqual(decoded.action, .updated)
        XCTAssertEqual(decoded.details["sourceMode"], "merge")
    }

    private static func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(value)
        return try decoder.decode(T.self, from: data)
    }
}
