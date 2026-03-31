import XCTest
import SwiftData
@testable import Flux

@MainActor
final class SettingsViewModelBackupTests: XCTestCase {
    @MainActor
    private final class MockBackupExportService: BackupExportServicing {
        var result: Result<BackupArchive, Error>

        init(result: Result<BackupArchive, Error>) {
            self.result = result
        }

        func makeBackupArchive() throws -> BackupArchive {
            try result.get()
        }
    }

    @MainActor
    private final class MockBackupImportService: BackupImportServicing {
        var result: Result<BackupImportPreflightSummary, Error>

        init(result: Result<BackupImportPreflightSummary, Error>) {
            self.result = result
        }

        func prepareImport(
            data: Data,
            mode: BackupRestoreMode,
            scope: BackupRestoreScope
        ) throws -> BackupImportPreflightSummary {
            try result.get()
        }
    }

    func testPrepareBackupExportPublishesSuccessState() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let archive = Self.makeArchive()
        let service = MockBackupExportService(result: .success(archive))
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            backupExportService: service
        )

        viewModel.prepareBackupExport()

        XCTAssertFalse(viewModel.isPreparingBackupExport)
        XCTAssertEqual(viewModel.preparedBackupArchive, archive)
        XCTAssertNil(viewModel.backupExportErrorMessage)
    }

    func testPrepareBackupExportPublishesErrorState() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let service = MockBackupExportService(
            result: .failure(NSError(domain: "BackupExport", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Export failed"
            ]))
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            backupExportService: service
        )

        viewModel.prepareBackupExport()

        XCTAssertFalse(viewModel.isPreparingBackupExport)
        XCTAssertNil(viewModel.preparedBackupArchive)
        XCTAssertEqual(viewModel.backupExportErrorMessage, "Export failed")
    }

    func testPrepareBackupRestorePreviewPublishesSuccessState() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let preview = BackupImportPreflightSummary(
            archiveId: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            schemaVersion: BackupArchive.currentSchemaVersion,
            appVersion: "1.0.0",
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exportSourceDevice: "iPhone 17 Pro",
            selectedMode: .replace,
            selectedScope: .financialDataOnly,
            recordCounts: BackupRecordCounts(
                currencies: 0,
                exchangeRates: 0,
                categories: 0,
                accounts: 1,
                transactions: 1,
                scheduledOccurrenceExceptions: 0,
                budgets: 0
            ),
            warnings: []
        )
        let importService = MockBackupImportService(result: .success(preview))
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            backupImportService: importService
        )

        viewModel.prepareBackupRestorePreview(
            from: Data("{}".utf8),
            mode: .replace,
            scope: .financialDataOnly
        )

        XCTAssertFalse(viewModel.isPreparingBackupRestorePreview)
        XCTAssertEqual(viewModel.preparedBackupRestorePreview, preview)
        XCTAssertNil(viewModel.backupRestorePreviewErrorMessage)
    }

    func testPrepareBackupRestorePreviewBlocksReplaceWhenPreflightFails() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let importService = MockBackupImportService(
            result: .failure(
                BackupImportServiceError.missingReferencedRecord(
                    recordType: "transactions",
                    recordID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                    referencedType: "accounts",
                    referencedID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
                )
            )
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            backupImportService: importService
        )

        viewModel.prepareBackupRestorePreview(
            from: Data("{}".utf8),
            mode: .replace,
            scope: .financialDataOnly
        )

        XCTAssertFalse(viewModel.isPreparingBackupRestorePreview)
        XCTAssertNil(viewModel.preparedBackupRestorePreview)
        XCTAssertNotNil(viewModel.backupRestorePreviewErrorMessage)
    }

    private static func makeArchive() -> BackupArchive {
        BackupArchive(
            schemaVersion: BackupArchive.currentSchemaVersion,
            appVersion: "1.0.0",
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exportSourceDevice: "iPhone 17 Pro",
            financialData: BackupFinancialData(),
            preferences: BackupPreferences(
                crossDevice: BackupCrossDevicePreferences(
                    preferredCurrencyCode: "USD",
                    appLanguage: .english,
                    travelCurrencySource: .automatic,
                    detectedTravelCurrencyCode: "HKD",
                    manualTravelCurrencyCode: nil,
                    reportsCategoryRowLimit: 5
                ),
                deviceLocal: BackupDeviceLocalPreferences(
                    defaultTransactionAccountId: nil,
                    rememberLastUsedTransactionAccount: true,
                    lastUsedTransactionAccountId: nil,
                    autoPresentAccountAfterCategorySelection: false
                )
            ),
            integrityMetadata: BackupIntegrityMetadata(
                archiveId: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
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
}
