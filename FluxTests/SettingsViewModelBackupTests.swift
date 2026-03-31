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
