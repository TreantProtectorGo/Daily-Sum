import XCTest
import SwiftData
@testable import Flux

@MainActor
final class AutomaticBackupSchedulerTests: XCTestCase {
    private final class MockBackupExportService: BackupExportServicing {
        var result: Result<BackupArchive, Error>
        private(set) var makeBackupArchiveCallCount = 0

        init(result: Result<BackupArchive, Error>) {
            self.result = result
        }

        func makeBackupArchive() throws -> BackupArchive {
            makeBackupArchiveCallCount += 1
            return try result.get()
        }
    }

    private final class MockBackupFileStore: BackupFileStoring {
        var backups: [BackupFileSummary]
        var writeResult: Result<BackupFileSummary, Error>
        private(set) var writtenKind: BackupFileKind?
        private(set) var deletedBackups: [BackupFileSummary] = []

        init(
            backups: [BackupFileSummary],
            writeResult: Result<BackupFileSummary, Error>
        ) {
            self.backups = backups
            self.writeResult = writeResult
        }

        func listBackups() throws -> [BackupFileSummary] {
            backups.sorted { lhs, rhs in
                lhs.exportedAt > rhs.exportedAt
            }
        }

        func writeBackupArchive(
            _ archive: BackupArchive,
            kind: BackupFileKind
        ) throws -> BackupFileSummary {
            writtenKind = kind
            let summary = try writeResult.get()
            backups.append(summary)
            return summary
        }

        func readBackupData(for backup: BackupFileSummary) throws -> Data {
            Data()
        }

        func deleteBackup(_ backup: BackupFileSummary) throws {
            deletedBackups.append(backup)
            backups.removeAll { $0.id == backup.id }
        }
    }

    func testRunIfNeededCreatesAutomaticBackupWhenIntervalHasElapsed() throws {
        withAutomaticBackupPreferencesRestored {
            let now = Date(timeIntervalSince1970: 1_700_700_000)
            AutomaticBackupPreference.frequency = .weekly
            AutomaticBackupPreference.retentionLimit = .count50
            AutomaticBackupPreference.lastAutomaticBackupAt = now.addingTimeInterval(-8 * 24 * 60 * 60)
            let archive = Self.makeArchive(exportedAt: now)
            let newBackup = Self.makeBackupFileSummary(
                filename: "Flux_Auto_20231122_000000.json",
                exportedAt: now,
                kind: .automatic
            )
            let exportService = MockBackupExportService(result: .success(archive))
            let fileStore = MockBackupFileStore(backups: [], writeResult: .success(newBackup))
            let scheduler = AutomaticBackupScheduler(
                backupExportService: exportService,
                backupFileStore: fileStore,
                now: { now }
            )

            scheduler.runIfNeeded()

            XCTAssertEqual(exportService.makeBackupArchiveCallCount, 1)
            XCTAssertEqual(fileStore.writtenKind, .automatic)
            XCTAssertEqual(AutomaticBackupPreference.lastAutomaticBackupAt, now)
        }
    }

    func testRunIfNeededSkipsWhenIntervalHasNotElapsed() throws {
        withAutomaticBackupPreferencesRestored {
            let now = Date(timeIntervalSince1970: 1_700_700_000)
            AutomaticBackupPreference.frequency = .weekly
            AutomaticBackupPreference.lastAutomaticBackupAt = now.addingTimeInterval(-6 * 24 * 60 * 60)
            let exportService = MockBackupExportService(result: .success(Self.makeArchive(exportedAt: now)))
            let fileStore = MockBackupFileStore(backups: [], writeResult: .success(
                Self.makeBackupFileSummary(
                    filename: "Flux_Auto_20231122_000000.json",
                    exportedAt: now,
                    kind: .automatic
                )
            ))
            let scheduler = AutomaticBackupScheduler(
                backupExportService: exportService,
                backupFileStore: fileStore,
                now: { now }
            )

            scheduler.runIfNeeded()

            XCTAssertEqual(exportService.makeBackupArchiveCallCount, 0)
            XCTAssertNil(fileStore.writtenKind)
        }
    }

    func testPruneAutomaticBackupsDeletesOldestAutomaticBackupsOnly() throws {
        try withAutomaticBackupPreferencesRestored {
            let backups = (0..<31).map { index in
                Self.makeBackupFileSummary(
                    filename: "Flux_Auto_202311\(String(format: "%02d", index + 1))_000000.json",
                    exportedAt: Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(index)),
                    kind: .automatic
                )
            } + [
                Self.makeBackupFileSummary(
                    filename: "Flux_20231101_000000.json",
                    exportedAt: Date(timeIntervalSince1970: 1_699_000_000),
                    kind: .manual
                )
            ]
            let fileStore = MockBackupFileStore(
                backups: backups,
                writeResult: .failure(NSError(domain: "BackupFileStore", code: 1, userInfo: nil))
            )
            let scheduler = AutomaticBackupScheduler(
                backupExportService: MockBackupExportService(result: .failure(NSError(domain: "BackupExport", code: 1, userInfo: nil))),
                backupFileStore: fileStore
            )

            try scheduler.pruneAutomaticBackups(limit: .count30)

            XCTAssertEqual(fileStore.deletedBackups.count, 1)
            XCTAssertEqual(fileStore.deletedBackups.first?.backupKind, .automatic)
            XCTAssertEqual(fileStore.deletedBackups.first?.exportedAt, Date(timeIntervalSince1970: 1_700_000_000))
            XCTAssertTrue(fileStore.backups.contains { $0.backupKind == .manual })
        }
    }

    private func withAutomaticBackupPreferencesRestored(_ body: () throws -> Void) rethrows {
        let originalFrequency = AutomaticBackupPreference.frequency
        let originalRetentionLimit = AutomaticBackupPreference.retentionLimit
        let originalLastAutomaticBackupAt = AutomaticBackupPreference.lastAutomaticBackupAt
        defer {
            AutomaticBackupPreference.frequency = originalFrequency
            AutomaticBackupPreference.retentionLimit = originalRetentionLimit
            AutomaticBackupPreference.lastAutomaticBackupAt = originalLastAutomaticBackupAt
        }
        try body()
    }

    private static func makeArchive(exportedAt: Date) -> BackupArchive {
        BackupArchive(
            schemaVersion: BackupArchive.currentSchemaVersion,
            appVersion: "1.0",
            exportedAt: exportedAt,
            exportSourceDevice: "iPhone 17 Pro",
            financialData: BackupFinancialData(),
            preferences: Self.makePreferences(),
            integrityMetadata: BackupIntegrityMetadata(
                archiveId: UUID(),
                contentHash: "sha256:abc123",
                recordCounts: BackupRecordCounts(
                    currencies: 0,
                    exchangeRates: 0,
                    categories: 0,
                    accounts: 0,
                    transactions: 0,
                    scheduledOccurrenceExceptions: 0,
                    budgets: 0
                ),
                createdByBuild: nil,
                compressionFormat: nil
            )
        )
    }

    private static func makeBackupFileSummary(
        filename: String,
        exportedAt: Date,
        kind: BackupFileKind
    ) -> BackupFileSummary {
        BackupFileSummary(
            url: URL(fileURLWithPath: "/tmp/\(filename)"),
            filename: filename,
            exportedAt: exportedAt,
            fileSize: 1024,
            exportSourceDevice: "iPhone 17 Pro",
            recordCounts: BackupRecordCounts(
                currencies: 0,
                exchangeRates: 0,
                categories: 0,
                accounts: 0,
                transactions: 0,
                scheduledOccurrenceExceptions: 0,
                budgets: 0
            ),
            archiveId: UUID(),
            backupKind: kind
        )
    }

    private static func makePreferences() -> BackupPreferences {
        BackupPreferences(
            crossDevice: BackupCrossDevicePreferences(
                preferredCurrencyCode: "HKD",
                appLanguage: .english,
                travelCurrencySource: .manual,
                detectedTravelCurrencyCode: nil,
                manualTravelCurrencyCode: "JPY",
                reportsCategoryRowLimit: 5
            ),
            deviceLocal: BackupDeviceLocalPreferences(
                defaultTransactionAccountId: nil,
                rememberLastUsedTransactionAccount: true,
                lastUsedTransactionAccountId: nil,
                autoPresentAccountAfterCategorySelection: false
            )
        )
    }
}
