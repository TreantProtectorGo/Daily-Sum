import XCTest
import SwiftData
@testable import Flux

@MainActor
final class BackupImportServiceTests: XCTestCase {
    private enum MarkerStoreFailure: Error, Equatable {
        case failedSave(phase: RestorePhase)
    }

    private final class FailingRestoreSessionMarkerStore: RestoreSessionMarkerStoring {
        private let failingPhase: RestorePhase
        private var marker: RestoreSessionMarker?

        init(failingPhase: RestorePhase) {
            self.failingPhase = failingPhase
        }

        func save(_ marker: RestoreSessionMarker) throws {
            if marker.phase == failingPhase {
                throw MarkerStoreFailure.failedSave(phase: marker.phase)
            }
            self.marker = marker
        }

        func load() throws -> RestoreSessionMarker? {
            marker
        }

        func clear() {
            marker = nil
        }
    }

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

    func testPrepareImportRejectsTruncatedArchiveData() throws {
        let service = BackupImportService(restoreSessionMarkerStore: InMemoryRestoreSessionMarkerStore())
        let data = Data("{\"schemaVersion\":1".utf8)

        XCTAssertThrowsError(
            try service.prepareImport(
                data: data,
                mode: .replace,
                scope: .financialDataOnly
            )
        ) { error in
            XCTAssertEqual(error as? BackupArchiveCodecError, .invalidArchiveFormat)
        }
    }

    func testApplyImportReplaceRestoresArchiveDataAndCrossDevicePreferencesOnly() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        try Self.seedExistingLocalData(in: context)

        let originalDefaultAccountId = TransactionAccountPreference.defaultAccountId
        let originalRememberLastUsedAccount = TransactionAccountPreference.rememberLastUsedAccount
        let originalLastUsedAccountId = TransactionAccountPreference.lastUsedAccountId
        let originalAutoPresentAccountAfterCategorySelection =
            TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection
        let originalCurrencyCode = UserCurrencyPreference.currencyCode
        let originalLanguage = AppLanguagePreference.language
        let originalTravelCurrencyModeEnabled = TravelCurrencyPreference.isEnabled
        let originalTravelCurrencySource = TravelCurrencyPreference.source
        let originalDetectedCurrencyCode = TravelCurrencyPreference.detectedCurrencyCode
        let originalManualCurrencyCode = TravelCurrencyPreference.manualCurrencyCode
        let originalReportsCategoryRowLimit = ReportsCategoryRowLimitPreference.rowLimit

        TransactionAccountPreference.defaultAccountId =
            UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
        TransactionAccountPreference.rememberLastUsedAccount = false
        TransactionAccountPreference.lastUsedAccountId =
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
        TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection = true
        UserCurrencyPreference.currencyCode = "HKD"
        AppLanguagePreference.language = .simplifiedChinese
        TravelCurrencyPreference.isEnabled = true
        TravelCurrencyPreference.source = .manual
        TravelCurrencyPreference.detectedCurrencyCode = "HKD"
        TravelCurrencyPreference.manualCurrencyCode = "JPY"
        ReportsCategoryRowLimitPreference.rowLimit = 12

        defer {
            TransactionAccountPreference.defaultAccountId = originalDefaultAccountId
            TransactionAccountPreference.rememberLastUsedAccount = originalRememberLastUsedAccount
            TransactionAccountPreference.lastUsedAccountId = originalLastUsedAccountId
            TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection =
                originalAutoPresentAccountAfterCategorySelection
            UserCurrencyPreference.currencyCode = originalCurrencyCode
            AppLanguagePreference.language = originalLanguage
            TravelCurrencyPreference.isEnabled = originalTravelCurrencyModeEnabled
            TravelCurrencyPreference.source = originalTravelCurrencySource
            TravelCurrencyPreference.detectedCurrencyCode = originalDetectedCurrencyCode
            TravelCurrencyPreference.manualCurrencyCode = originalManualCurrencyCode
            ReportsCategoryRowLimitPreference.rowLimit = originalReportsCategoryRowLimit
        }

        let markerStore = InMemoryRestoreSessionMarkerStore()
        let service = BackupImportService(restoreSessionMarkerStore: markerStore)
        let archive = Self.makeArchive()
        let data = try BackupArchiveCodec.encode(archive)

        let report = try service.applyImport(
            data: data,
            mode: .replace,
            scope: .financialDataAndCrossDevicePreferences,
            context: context
        )

        XCTAssertEqual(try context.fetch(FetchDescriptor<Account>()).map(\.id), [
            UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        ])
        XCTAssertEqual(try context.fetch(FetchDescriptor<Transaction>()).map(\.id), [
            UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        ])
        XCTAssertEqual(UserCurrencyPreference.currencyCode, "USD")
        XCTAssertEqual(AppLanguagePreference.language, .english)
        XCTAssertFalse(TravelCurrencyPreference.isEnabled)
        XCTAssertEqual(TravelCurrencyPreference.source, .automatic)
        XCTAssertEqual(ReportsCategoryRowLimitPreference.rowLimit, 5)
        XCTAssertEqual(
            TransactionAccountPreference.defaultAccountId,
            UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
        )
        XCTAssertFalse(TransactionAccountPreference.rememberLastUsedAccount)
        XCTAssertEqual(
            TransactionAccountPreference.lastUsedAccountId,
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
        )
        XCTAssertTrue(TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection)
        XCTAssertNil(try markerStore.load())
        XCTAssertEqual(report.archiveId, archive.integrityMetadata.archiveId)
        XCTAssertEqual(report.summary.importedCount, 2)
        XCTAssertEqual(report.summary.failedCount, 0)
    }

    func testApplyImportReplaceLeavesInterruptedMarkerWhenFailureOccursAfterClear() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        try Self.seedExistingLocalData(in: context)

        let markerStore = FailingRestoreSessionMarkerStore(failingPhase: .importPass1)
        let service = BackupImportService(restoreSessionMarkerStore: markerStore)
        let archive = Self.makeArchive()
        let data = try BackupArchiveCodec.encode(archive)

        XCTAssertThrowsError(
            try service.applyImport(
                data: data,
                mode: .replace,
                scope: .financialDataOnly,
                context: context
            )
        ) { error in
            XCTAssertEqual(error as? MarkerStoreFailure, .failedSave(phase: .importPass1))
        }

        let marker = try XCTUnwrap(markerStore.load())
        XCTAssertEqual(marker.phase, .destructiveClearStarted)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<Account>()).map(\.id),
            [UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!]
        )
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<Transaction>()).map(\.id),
            [UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!]
        )
    }

    func testApplyImportReplaceRestoresAccountTypeLinkAndCategorySortOrder() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        var archive = Self.makeArchive()
        let typeID = UUID(uuidString: "11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let categoryID = UUID(uuidString: "22222222-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        archive.financialData.accountTypeDefinitions = [
            BackupAccountTypeDefinitionRecord(
                id: typeID,
                name: "Travel Wallet",
                icon: "airplane",
                colorHex: "#00AA88",
                isSystemDefault: false,
                sortOrder: 7,
                createdAt: Date(timeIntervalSince1970: 1_700_000_100),
                legacyTypeRawValue: AccountType.cash.rawValue
            )
        ]
        archive.financialData.accounts[0].typeDefinitionId = typeID
        archive.financialData.categories = [
            BackupCategoryRecord(
                id: categoryID,
                nameKey: "Trips",
                icon: "airplane",
                colorHex: "#00AA88",
                type: .expense,
                isSystemDefault: false,
                sortOrder: 9,
                parentCategoryId: nil
            )
        ]
        archive.integrityMetadata.recordCounts.accountTypeDefinitions = 1
        archive.integrityMetadata.recordCounts.categories = 1

        let data = try BackupArchiveCodec.encode(archive)
        _ = try BackupImportService(
            restoreSessionMarkerStore: InMemoryRestoreSessionMarkerStore()
        ).applyImport(
            data: data,
            mode: .replace,
            scope: .financialDataOnly,
            context: context
        )

        let restoredType = try XCTUnwrap(context.fetch(FetchDescriptor<AccountTypeDefinition>()).first)
        let restoredAccount = try XCTUnwrap(context.fetch(FetchDescriptor<Account>()).first)
        let restoredCategory = try XCTUnwrap(
            context.fetch(FetchDescriptor<Flux.Category>()).first
        )
        XCTAssertEqual(restoredType.id, typeID)
        XCTAssertEqual(restoredType.sortOrder, 7)
        XCTAssertEqual(restoredAccount.typeDefinition?.id, typeID)
        XCTAssertEqual(restoredCategory.sortOrder, 9)
    }

    func testApplyImportMergeUpdatesStableIDMatchesAndReportsUpdates() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        try Self.seedMergeUpsertData(in: context)

        let markerStore = InMemoryRestoreSessionMarkerStore()
        let service = BackupImportService(restoreSessionMarkerStore: markerStore)
        let archive = Self.makeArchive()
        let data = try BackupArchiveCodec.encode(archive)

        let report = try service.applyImport(
            data: data,
            mode: .merge,
            scope: .financialDataOnly,
            context: context
        )

        let account = try XCTUnwrap(
            context.fetch(FetchDescriptor<Account>())
                .first(where: { $0.id == UUID(uuidString: "33333333-3333-3333-3333-333333333333")! })
        )
        let transaction = try XCTUnwrap(
            context.fetch(FetchDescriptor<Transaction>())
                .first(where: { $0.id == UUID(uuidString: "44444444-4444-4444-4444-444444444444")! })
        )

        XCTAssertEqual(account.name, "Cash Wallet")
        XCTAssertEqual(account.currencyCode, "USD")
        XCTAssertEqual(transaction.amount, 25.5)
        XCTAssertEqual(transaction.currencyCode, "USD")
        XCTAssertEqual(report.summary.importedCount, 0)
        XCTAssertEqual(report.summary.updatedCount, 2)
        XCTAssertEqual(report.summary.skippedCount, 0)
        XCTAssertEqual(report.summary.failedCount, 0)
        XCTAssertNil(try markerStore.load())
    }

    func testApplyImportMergeSkipsUnchangedStableIDMatches() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        try Self.seedMergeIdenticalData(in: context)

        let service = BackupImportService(restoreSessionMarkerStore: InMemoryRestoreSessionMarkerStore())
        let archive = Self.makeArchive()
        let data = try BackupArchiveCodec.encode(archive)

        let report = try service.applyImport(
            data: data,
            mode: .merge,
            scope: .financialDataOnly,
            context: context
        )

        XCTAssertEqual(report.summary.importedCount, 0)
        XCTAssertEqual(report.summary.updatedCount, 0)
        XCTAssertEqual(report.summary.skippedCount, 2)
        XCTAssertEqual(report.summary.failedCount, 0)
        XCTAssertEqual(report.entries.map(\.action), [.skipped, .skipped])
    }

    func testApplyImportMergeReportsRecordLevelFailureForMissingReference() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext

        let service = BackupImportService(restoreSessionMarkerStore: InMemoryRestoreSessionMarkerStore())
        var archive = Self.makeArchive()
        archive.financialData.transactions.append(
            BackupTransactionRecord(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                amount: 12,
                currencyCode: "USD",
                type: .expense,
                date: Date(timeIntervalSince1970: 1_700_000_600),
                notes: "Broken",
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
                accountId: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
                categoryId: nil
            )
        )
        archive.integrityMetadata.recordCounts.transactions = 2
        let data = try BackupArchiveCodec.encode(archive)

        let report = try service.applyImport(
            data: data,
            mode: .merge,
            scope: .financialDataOnly,
            context: context
        )

        XCTAssertEqual(try context.fetch(FetchDescriptor<Account>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Transaction>()).count, 1)
        XCTAssertEqual(report.summary.importedCount, 2)
        XCTAssertEqual(report.summary.updatedCount, 0)
        XCTAssertEqual(report.summary.skippedCount, 0)
        XCTAssertEqual(report.summary.failedCount, 1)
        XCTAssertEqual(report.conflictReasons.count, 1)
        XCTAssertEqual(
            report.entries.first(where: {
                $0.entityId == UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
            })?.action,
            .failed
        )
    }

    func testPrepareImportRejectsOlderSchemaVersion() throws {
        let data = try Self.encodedData(from: Self.makeArchive()) { json in
            json["schemaVersion"] = BackupArchive.minimumSupportedSchemaVersion - 1
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
                .unsupportedSchemaVersion(BackupArchive.minimumSupportedSchemaVersion - 1)
            )
        }
    }

    func testApplyImportRejectsForwardSchemaVersionDuringReplace() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let data = try Self.encodedData(from: Self.makeArchive()) { json in
            json["schemaVersion"] = BackupArchive.currentSchemaVersion + 1
        }
        let markerStore = InMemoryRestoreSessionMarkerStore()
        let service = BackupImportService(restoreSessionMarkerStore: markerStore)

        XCTAssertThrowsError(
            try service.applyImport(
                data: data,
                mode: .replace,
                scope: .financialDataOnly,
                context: container.mainContext
            )
        ) { error in
            XCTAssertEqual(
                error as? BackupArchiveCodecError,
                .unsupportedSchemaVersion(BackupArchive.currentSchemaVersion + 1)
            )
        }
        XCTAssertNil(try? markerStore.load())
    }

    func testApplyImportRejectsUnknownEnumValueDuringMerge() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let data = try Self.encodedData(from: Self.makeArchive()) { json in
            var preferences = json["preferences"] as? [String: Any] ?? [:]
            var crossDevice = preferences["crossDevice"] as? [String: Any] ?? [:]
            crossDevice["travelCurrencySource"] = "telepathy"
            preferences["crossDevice"] = crossDevice
            json["preferences"] = preferences
        }
        let service = BackupImportService(restoreSessionMarkerStore: InMemoryRestoreSessionMarkerStore())

        XCTAssertThrowsError(
            try service.applyImport(
                data: data,
                mode: .merge,
                scope: .financialDataOnly,
                context: container.mainContext
            )
        ) { error in
            XCTAssertEqual(error as? BackupArchiveCodecError, .invalidArchiveFormat)
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
                    isTravelCurrencyModeEnabled: false,
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

    private static func seedExistingLocalData(in context: ModelContext) throws {
        let account = Account(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            name: "Old Wallet",
            type: .cash,
            currencyCode: "HKD",
            initialBalance: 1
        )
        let transaction = Transaction(
            id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            amount: 10,
            currencyCode: "HKD",
            type: .expense,
            account: account
        )
        context.insert(account)
        context.insert(transaction)
        try context.save()
    }

    private static func seedMergeUpsertData(in context: ModelContext) throws {
        let account = Account(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Old Cash Wallet",
            type: .cash,
            currencyCode: "HKD",
            initialBalance: 10,
            icon: "banknote",
            colorHex: "#FF0000",
            includeInTotal: false,
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let transaction = Transaction(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            amount: 10,
            currencyCode: "HKD",
            type: .expense,
            date: Date(timeIntervalSince1970: 1_700_000_200),
            notes: "Old Lunch",
            account: account
        )
        context.insert(account)
        context.insert(transaction)
        try context.save()
    }

    private static func seedMergeIdenticalData(in context: ModelContext) throws {
        let account = Account(
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
        let transaction = Transaction(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            amount: 25.5,
            currencyCode: "USD",
            type: .expense,
            date: Date(timeIntervalSince1970: 1_700_000_500),
            notes: "Lunch",
            isTravelTransaction: false,
            account: account
        )
        context.insert(account)
        context.insert(transaction)
        try context.save()
    }
}
