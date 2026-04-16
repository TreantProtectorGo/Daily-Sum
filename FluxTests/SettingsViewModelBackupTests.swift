import XCTest
import Observation
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
        var previewResult: Result<BackupImportPreflightSummary, Error>
        var applyResult: Result<ImportReport, Error>
        private(set) var lastPreparedData: Data?
        private(set) var lastAppliedData: Data?
        private(set) var lastPreparedMode: BackupRestoreMode?
        private(set) var lastPreparedScope: BackupRestoreScope?
        private(set) var lastAppliedMode: BackupRestoreMode?
        private(set) var lastAppliedScope: BackupRestoreScope?

        init(
            previewResult: Result<BackupImportPreflightSummary, Error>,
            applyResult: Result<ImportReport, Error> = .failure(
                NSError(domain: "BackupImport", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Apply not configured"
                ])
            )
        ) {
            self.previewResult = previewResult
            self.applyResult = applyResult
        }

        func prepareImport(
            data: Data,
            mode: BackupRestoreMode,
            scope: BackupRestoreScope
        ) throws -> BackupImportPreflightSummary {
            lastPreparedData = data
            lastPreparedMode = mode
            lastPreparedScope = scope
            return try previewResult.get()
        }

        func applyImport(
            data: Data,
            mode: BackupRestoreMode,
            scope: BackupRestoreScope,
            context: ModelContext
        ) throws -> ImportReport {
            lastAppliedData = data
            lastAppliedMode = mode
            lastAppliedScope = scope
            return try applyResult.get()
        }
    }

    @MainActor
    private final class MockBackupFileStore: BackupFileStoring {
        var backups: [BackupFileSummary]
        var writeResult: Result<BackupFileSummary, Error>
        var readDataResult: Result<Data, Error>
        private(set) var writtenArchive: BackupArchive?
        private(set) var readBackup: BackupFileSummary?

        init(
            backups: [BackupFileSummary] = [],
            writeResult: Result<BackupFileSummary, Error>,
            readDataResult: Result<Data, Error> = .failure(
                NSError(domain: "BackupFileStore", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Read not configured"
                ])
            )
        ) {
            self.backups = backups
            self.writeResult = writeResult
            self.readDataResult = readDataResult
        }

        func listBackups() throws -> [BackupFileSummary] {
            backups
        }

        func writeBackupArchive(_ archive: BackupArchive) throws -> BackupFileSummary {
            writtenArchive = archive
            return try writeResult.get()
        }

        func readBackupData(for backup: BackupFileSummary) throws -> Data {
            readBackup = backup
            return try readDataResult.get()
        }
    }

    @MainActor
    private final class MockCloudSyncSettingsStore: CloudSyncSettingsStoring {
        var isCloudSyncEnabled: Bool
        private let availability: CloudSyncAvailability

        init(
            isCloudSyncEnabled: Bool,
            availability: CloudSyncAvailability
        ) {
            self.isCloudSyncEnabled = isCloudSyncEnabled
            self.availability = availability
        }

        var status: CloudSyncStatus {
            switch availability {
            case .available:
                return isCloudSyncEnabled ? .enabled : .disabled
            case let .unavailable(reason):
                return .unavailable(reason)
            }
        }

        func currentCrossDevicePreferences() -> BackupCrossDevicePreferences {
            BackupCrossDevicePreferences(
                preferredCurrencyCode: "USD",
                appLanguage: .english,
                travelCurrencySource: .automatic,
                detectedTravelCurrencyCode: nil,
                manualTravelCurrencyCode: nil,
                reportsCategoryRowLimit: 5
            )
        }

        func applyCrossDevicePreferences(_ preferences: BackupCrossDevicePreferences) {}
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

    func testCreateManagedBackupWritesArchiveAndRefreshesBackupList() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let archive = Self.makeArchive()
        let fileSummary = Self.makeBackupFileSummary(filename: "Flux_20231114_221320.json")
        let backupFileStore = MockBackupFileStore(
            backups: [fileSummary],
            writeResult: .success(fileSummary)
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            backupExportService: MockBackupExportService(result: .success(archive)),
            backupFileStore: backupFileStore
        )

        viewModel.createManagedBackup()

        XCTAssertFalse(viewModel.isPreparingBackupExport)
        XCTAssertEqual(backupFileStore.writtenArchive, archive)
        XCTAssertEqual(viewModel.preparedBackupArchive, archive)
        XCTAssertEqual(viewModel.lastCreatedBackupFile, fileSummary)
        XCTAssertEqual(viewModel.backupFiles, [fileSummary])
        XCTAssertNil(viewModel.backupExportErrorMessage)
    }

    func testPrepareManagedBackupRestorePreviewUsesSelectedBackupWithFixedPolicy() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let backupData = Data("{\"backup\":true}".utf8)
        let fileSummary = Self.makeBackupFileSummary(filename: "Flux_20231114_221320.json")
        let preview = BackupImportPreflightSummary(
            archiveId: fileSummary.archiveId,
            schemaVersion: BackupArchive.currentSchemaVersion,
            appVersion: "1.0.0",
            exportedAt: fileSummary.exportedAt,
            exportSourceDevice: fileSummary.exportSourceDevice,
            selectedMode: .replace,
            selectedScope: .financialDataAndAllPreferences,
            recordCounts: fileSummary.recordCounts,
            warnings: []
        )
        let importService = MockBackupImportService(previewResult: .success(preview))
        let backupFileStore = MockBackupFileStore(
            backups: [fileSummary],
            writeResult: .failure(NSError(domain: "BackupFileStore", code: 1, userInfo: nil)),
            readDataResult: .success(backupData)
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            backupImportService: importService,
            backupFileStore: backupFileStore
        )

        viewModel.prepareManagedBackupRestorePreview(from: fileSummary)

        XCTAssertEqual(backupFileStore.readBackup, fileSummary)
        XCTAssertEqual(importService.lastPreparedData, backupData)
        XCTAssertEqual(importService.lastPreparedMode, .replace)
        XCTAssertEqual(importService.lastPreparedScope, .financialDataAndAllPreferences)
        XCTAssertEqual(viewModel.preparedBackupRestorePreview, preview)
        XCTAssertNil(viewModel.backupRestorePreviewErrorMessage)
    }

    func testPrepareManagedBackupRestoreConfirmationReturnsPreflightOutcome() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let backupData = Data("{\"backup\":true}".utf8)
        let fileSummary = Self.makeBackupFileSummary(filename: "Flux_20231114_221320.json")
        let preview = BackupImportPreflightSummary(
            archiveId: fileSummary.archiveId,
            schemaVersion: BackupArchive.currentSchemaVersion,
            appVersion: "1.0.0",
            exportedAt: fileSummary.exportedAt,
            exportSourceDevice: fileSummary.exportSourceDevice,
            selectedMode: .replace,
            selectedScope: .financialDataAndAllPreferences,
            recordCounts: fileSummary.recordCounts,
            warnings: []
        )
        let importService = MockBackupImportService(previewResult: .success(preview))
        let backupFileStore = MockBackupFileStore(
            backups: [fileSummary],
            writeResult: .failure(NSError(domain: "BackupFileStore", code: 1, userInfo: nil)),
            readDataResult: .success(backupData)
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            backupImportService: importService,
            backupFileStore: backupFileStore
        )

        let shouldConfirm = viewModel.prepareManagedBackupRestoreConfirmation(from: fileSummary)

        XCTAssertTrue(shouldConfirm)
        XCTAssertEqual(backupFileStore.readBackup, fileSummary)
        XCTAssertEqual(importService.lastPreparedMode, .replace)
        XCTAssertEqual(importService.lastPreparedScope, .financialDataAndAllPreferences)
        XCTAssertEqual(viewModel.preparedBackupRestorePreview, preview)
        XCTAssertNil(viewModel.backupRestorePreviewErrorMessage)
    }

    func testApplyPreparedManagedBackupRestoreUsesPreviouslySelectedBackupData() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let backupData = Data("{\"backup\":true}".utf8)
        let fileSummary = Self.makeBackupFileSummary(filename: "Flux_20231114_221320.json")
        let preview = BackupImportPreflightSummary(
            archiveId: fileSummary.archiveId,
            schemaVersion: BackupArchive.currentSchemaVersion,
            appVersion: "1.0.0",
            exportedAt: fileSummary.exportedAt,
            exportSourceDevice: fileSummary.exportSourceDevice,
            selectedMode: .replace,
            selectedScope: .financialDataAndAllPreferences,
            recordCounts: fileSummary.recordCounts,
            warnings: []
        )
        let report = ImportReport(
            archiveId: fileSummary.archiveId,
            schemaVersion: BackupArchive.currentSchemaVersion,
            summary: ImportReportSummary(
                importedCount: 1,
                updatedCount: 0,
                skippedCount: 0,
                failedCount: 0,
                warningCount: 0
            ),
            entries: [],
            conflictReasons: [],
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let importService = MockBackupImportService(
            previewResult: .success(preview),
            applyResult: .success(report)
        )
        let backupFileStore = MockBackupFileStore(
            backups: [fileSummary],
            writeResult: .failure(NSError(domain: "BackupFileStore", code: 1, userInfo: nil)),
            readDataResult: .success(backupData)
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            backupImportService: importService,
            backupFileStore: backupFileStore
        )

        viewModel.prepareManagedBackupRestorePreview(from: fileSummary)
        viewModel.applyPreparedManagedBackupRestore()

        XCTAssertEqual(importService.lastAppliedData, backupData)
        XCTAssertEqual(importService.lastAppliedMode, .replace)
        XCTAssertEqual(importService.lastAppliedScope, .financialDataAndAllPreferences)
        XCTAssertEqual(viewModel.appliedBackupImportReport, report)
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
        let importService = MockBackupImportService(previewResult: .success(preview))
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
            previewResult: .failure(
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

    func testCloudSyncStatusPublishesEnabledState() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let cloudSyncStore = MockCloudSyncSettingsStore(
            isCloudSyncEnabled: true,
            availability: .available
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            cloudSyncSettingsStore: cloudSyncStore
        )

        XCTAssertEqual(viewModel.cloudSyncStatus, .enabled)
        XCTAssertFalse(viewModel.cloudSyncRequiresAttention)
        XCTAssertEqual(viewModel.cloudSyncStatusTitle, "On")
    }

    func testCloudSyncStatusPublishesAttentionState() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let cloudSyncStore = MockCloudSyncSettingsStore(
            isCloudSyncEnabled: true,
            availability: .unavailable(.iCloudAccountRequired)
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            cloudSyncSettingsStore: cloudSyncStore
        )

        XCTAssertEqual(viewModel.cloudSyncStatus, .unavailable(.iCloudAccountRequired))
        XCTAssertTrue(viewModel.cloudSyncRequiresAttention)
        XCTAssertEqual(viewModel.cloudSyncStatusTitle, "Needs Attention")
        XCTAssertEqual(viewModel.cloudSyncStatusMessage, "Sign in to iCloud to enable sync.")
    }

    func testCloudSyncToggleInvalidatesObservedStatusCopy() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let cloudSyncStore = MockCloudSyncSettingsStore(
            isCloudSyncEnabled: false,
            availability: .available
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            cloudSyncSettingsStore: cloudSyncStore
        )

        let invalidation = expectation(description: "Observed state invalidated")
        withObservationTracking {
            _ = viewModel.cloudSyncStatusTitle
            _ = viewModel.cloudSyncStatusMessage
        } onChange: {
            invalidation.fulfill()
        }

        viewModel.isCloudSyncEnabled = true

        await fulfillment(of: [invalidation], timeout: 1.0)
        XCTAssertEqual(viewModel.cloudSyncStatus, .enabled)
        XCTAssertEqual(viewModel.cloudSyncStatusTitle, "On")
        XCTAssertEqual(viewModel.cloudSyncStatusMessage, "Changes sync through iCloud.")
    }

    func testBackupRestoreSelectionDefaultsToReplaceAndAllPreferences() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let viewModel = SettingsViewModel(modelContext: container.mainContext)

        XCTAssertEqual(viewModel.selectedBackupRestoreMode, .replace)
        XCTAssertEqual(viewModel.selectedBackupRestoreScope, .financialDataAndAllPreferences)
    }

    func testPrepareBackupRestorePreviewPublishesSummaryText() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let preview = BackupImportPreflightSummary(
            archiveId: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            schemaVersion: BackupArchive.currentSchemaVersion,
            appVersion: "1.2.3",
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exportSourceDevice: "Wing's iPhone",
            selectedMode: .merge,
            selectedScope: .financialDataAndAllPreferences,
            recordCounts: BackupRecordCounts(
                currencies: 1,
                exchangeRates: 2,
                categories: 3,
                accounts: 4,
                transactions: 5,
                scheduledOccurrenceExceptions: 6,
                budgets: 7
            ),
            warnings: []
        )
        let importService = MockBackupImportService(previewResult: .success(preview))
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            backupImportService: importService
        )

        viewModel.prepareBackupRestorePreview(
            from: Data("{}".utf8),
            mode: .merge,
            scope: .financialDataAndAllPreferences
        )

        XCTAssertEqual(
            viewModel.backupRestorePreviewSummaryText,
            "Wing's iPhone, 4 accounts, 5 transactions"
        )
    }

    func testApplyBackupRestorePublishesSummaryText() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let report = ImportReport(
            archiveId: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
            schemaVersion: BackupArchive.currentSchemaVersion,
            summary: ImportReportSummary(
                importedCount: 5,
                updatedCount: 2,
                skippedCount: 1,
                failedCount: 0,
                warningCount: 1
            ),
            entries: [],
            conflictReasons: [],
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let importService = MockBackupImportService(
            previewResult: .failure(
                NSError(domain: "BackupImport", code: 1, userInfo: nil)
            ),
            applyResult: .success(report)
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            backupImportService: importService
        )

        viewModel.applyBackupRestore(
            from: Data("{}".utf8),
            mode: .merge,
            scope: .financialDataAndCrossDevicePreferences
        )

        XCTAssertEqual(
            viewModel.appliedBackupImportSummaryText,
            "Imported 5, updated 2, skipped 1, failed 0"
        )
    }

    func testApplyBackupRestorePublishesSuccessState() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let report = ImportReport(
            archiveId: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            schemaVersion: BackupArchive.currentSchemaVersion,
            summary: ImportReportSummary(
                importedCount: 2,
                updatedCount: 0,
                skippedCount: 0,
                failedCount: 0,
                warningCount: 0
            ),
            entries: [],
            conflictReasons: [],
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let importService = MockBackupImportService(
            previewResult: .failure(
                NSError(domain: "BackupImport", code: 1, userInfo: nil)
            ),
            applyResult: .success(report)
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            backupImportService: importService
        )

        viewModel.applyBackupRestore(
            from: Data("{}".utf8),
            mode: .replace,
            scope: .financialDataOnly
        )

        XCTAssertFalse(viewModel.isApplyingBackupRestore)
        XCTAssertEqual(viewModel.appliedBackupImportReport, report)
        XCTAssertNil(viewModel.backupRestoreApplyErrorMessage)
    }

    func testApplyBackupRestoreReplaceRequestsAppReload() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let report = ImportReport(
            archiveId: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            schemaVersion: BackupArchive.currentSchemaVersion,
            summary: ImportReportSummary(
                importedCount: 2,
                updatedCount: 0,
                skippedCount: 0,
                failedCount: 0,
                warningCount: 0
            ),
            entries: [],
            conflictReasons: [],
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let importService = MockBackupImportService(
            previewResult: .failure(
                NSError(domain: "BackupImport", code: 1, userInfo: nil)
            ),
            applyResult: .success(report)
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            backupImportService: importService
        )

        let expectation = expectation(forNotification: AppModelReload.requestedNotification, object: nil)

        viewModel.applyBackupRestore(
            from: Data("{}".utf8),
            mode: .replace,
            scope: .financialDataOnly
        )

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testApplyBackupRestorePublishesErrorState() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let importService = MockBackupImportService(
            previewResult: .failure(
                NSError(domain: "BackupImport", code: 1, userInfo: nil)
            ),
            applyResult: .failure(
                NSError(domain: "BackupImport", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Apply failed"
                ])
            )
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            backupImportService: importService
        )

        viewModel.applyBackupRestore(
            from: Data("{}".utf8),
            mode: .replace,
            scope: .financialDataOnly
        )

        XCTAssertFalse(viewModel.isApplyingBackupRestore)
        XCTAssertNil(viewModel.appliedBackupImportReport)
        XCTAssertEqual(viewModel.backupRestoreApplyErrorMessage, "Apply failed")
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

    private static func makeBackupFileSummary(filename: String) -> BackupFileSummary {
        BackupFileSummary(
            url: URL(fileURLWithPath: "/tmp/\(filename)"),
            filename: filename,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            fileSize: 1024,
            exportSourceDevice: "iPhone 17 Pro",
            recordCounts: BackupRecordCounts(
                currencies: 0,
                exchangeRates: 0,
                categories: 0,
                accounts: 1,
                transactions: 1,
                scheduledOccurrenceExceptions: 0,
                budgets: 0
            ),
            archiveId: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        )
    }
}
