import XCTest
import SwiftData
@testable import Flux

@MainActor
final class BackupImportServiceTests: XCTestCase {
    func testValidateImportReturnsPreflightSummaryWithoutPersistingMarker() throws {
        let archive = Self.makeArchive()
        let data = try BackupArchiveCodec.encode(archive)
        let markerStore = InMemoryRestoreSessionMarkerStore()
        let service = BackupImportService(restoreSessionMarkerStore: markerStore)

        let summary = try service.validateImport(
            data: data,
            mode: .replace,
            scope: .financialDataOnly
        )

        XCTAssertEqual(summary.archiveId, archive.integrityMetadata.archiveId)
        XCTAssertTrue(summary.warnings.isEmpty)
        XCTAssertNil(try markerStore.load())
    }

    func testPrepareImportReturnsPreflightSummaryAndPersistsMarker() throws {
        let archive = Self.makeArchive()
        let data = try BackupArchiveCodec.encode(archive)
        let markerStore = InMemoryRestoreSessionMarkerStore()
        let service = BackupImportService(restoreSessionMarkerStore: markerStore)

        let summary = try service.prepareImport(
            data: data,
            mode: .replace,
            scope: .financialDataAndCrossDevicePreferences
        )

        XCTAssertEqual(summary.archiveId, archive.integrityMetadata.archiveId)
        XCTAssertEqual(summary.selectedMode, .replace)
        XCTAssertEqual(summary.selectedScope, .financialDataAndCrossDevicePreferences)
        XCTAssertEqual(summary.recordCounts.transactions, 1)
        XCTAssertTrue(summary.warnings.isEmpty)

        let marker = try XCTUnwrap(markerStore.load())
        XCTAssertEqual(marker.archiveId, archive.integrityMetadata.archiveId)
        XCTAssertEqual(marker.mode, .replace)
        XCTAssertEqual(marker.scope, .financialDataAndCrossDevicePreferences)
        XCTAssertEqual(marker.phase, .preflightPassed)
    }

    func testPrepareImportPropagatesUnsupportedSchemaValidation() throws {
        let data = try Self.encodedData(from: Self.makeArchive()) { json in
            json["schemaVersion"] = BackupArchive.currentSchemaVersion + 1
        }
        let service = BackupImportService(restoreSessionMarkerStore: InMemoryRestoreSessionMarkerStore())

        XCTAssertThrowsError(
            try service.prepareImport(
                data: data,
                mode: .replace,
                scope: .financialDataOnly
            )
        ) { error in
            XCTAssertEqual(
                error as? BackupArchiveCodecError,
                .unsupportedSchemaVersion(BackupArchive.currentSchemaVersion + 1)
            )
        }
    }

    func testPrepareImportRejectsOlderSchemaVersion() throws {
        let data = try Self.encodedData(from: Self.makeArchive()) { json in
            json["schemaVersion"] = BackupArchive.currentSchemaVersion - 1
        }
        let service = BackupImportService(restoreSessionMarkerStore: InMemoryRestoreSessionMarkerStore())

        XCTAssertThrowsError(
            try service.prepareImport(
                data: data,
                mode: .replace,
                scope: .financialDataOnly
            )
        ) { error in
            XCTAssertEqual(
                error as? BackupArchiveCodecError,
                .unsupportedSchemaVersion(BackupArchive.currentSchemaVersion - 1)
            )
        }
    }

    func testPrepareImportRejectsMissingReferencedAccount() throws {
        var archive = Self.makeArchive()
        archive.financialData.transactions[0].accountId =
            UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
        let data = try BackupArchiveCodec.encode(archive)

        let service = BackupImportService(restoreSessionMarkerStore: InMemoryRestoreSessionMarkerStore())

        XCTAssertThrowsError(
            try service.prepareImport(
                data: data,
                mode: .replace,
                scope: .financialDataOnly
            )
        ) { error in
            XCTAssertEqual(
                error as? BackupImportServiceError,
                .missingReferencedRecord(
                    recordType: "transactions",
                    recordID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                    referencedType: "accounts",
                    referencedID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
                )
            )
        }
    }

    private static func encodedData(
        from archive: BackupArchive,
        mutate: (inout [String: Any]) -> Void
    ) throws -> Data {
        let original = try BackupArchiveCodec.encode(archive)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        mutate(&json)
        return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    }

    private static func makeArchive() -> BackupArchive {
        BackupArchive(
            schemaVersion: BackupArchive.currentSchemaVersion,
            appVersion: "1.0.0",
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exportSourceDevice: "iPhone 17 Pro",
            financialData: BackupFinancialData(
                accounts: [
                    BackupAccountRecord(
                        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                        name: "Cash Wallet",
                        type: .cash,
                        currencyCode: "USD",
                        initialBalance: 500,
                        icon: "banknote",
                        colorHex: "#007AFF",
                        includeInTotal: true,
                        createdAt: Date(timeIntervalSince1970: 1_700_000_400)
                    )
                ],
                transactions: [
                    BackupTransactionRecord(
                        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                        amount: 25.5,
                        currencyCode: "USD",
                        type: .expense,
                        date: Date(timeIntervalSince1970: 1_700_000_500),
                        notes: "Lunch",
                        isTravelTransaction: false,
                        travelAmount: nil,
                        travelCurrencyCode: nil,
                        travelExchangeRate: nil,
                        travelExchangeRateEffectiveDate: nil,
                        travelExchangeRateProvider: nil,
                        receiptImageData: nil,
                        isRecurringTemplate: false,
                        recurrenceRule: nil,
                        schedulePlanTypeRawValue: nil,
                        dueDayOfMonth: nil,
                        reminderLeadDays: nil,
                        installmentTotalCount: nil,
                        installmentSequenceNumber: nil,
                        recurringTemplateId: nil,
                        generatedDate: nil,
                        accountId: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                        categoryId: nil
                    )
                ]
            ),
            preferences: BackupPreferences(
                crossDevice: BackupCrossDevicePreferences(
                    preferredCurrencyCode: "USD",
                    appLanguage: .english,
                    travelCurrencySource: .automatic,
                    detectedTravelCurrencyCode: nil,
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
                    accounts: 1,
                    transactions: 1,
                    scheduledOccurrenceExceptions: 0,
                    budgets: 0
                ),
                createdByBuild: "42",
                compressionFormat: nil
            )
        )
    }
}
