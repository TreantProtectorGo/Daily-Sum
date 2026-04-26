import XCTest
@testable import Flux

@MainActor
final class BackupFileStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testWriteBackupArchivePersistsReadableFileAndListsNewestFirst() throws {
        let olderArchive = Self.makeArchive(
            archiveId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            accounts: 1,
            transactions: 2
        )
        let newerArchive = Self.makeArchive(
            archiveId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_100),
            accounts: 3,
            transactions: 4
        )
        let store = BackupFileStore(directory: temporaryDirectory)

        let olderSummary = try store.writeBackupArchive(olderArchive)
        let newerSummary = try store.writeBackupArchive(newerArchive)
        let listedBackups = try store.listBackups()

        XCTAssertTrue(FileManager.default.fileExists(atPath: olderSummary.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newerSummary.url.path))
        XCTAssertEqual(listedBackups.map(\.archiveId), [
            newerArchive.integrityMetadata.archiveId,
            olderArchive.integrityMetadata.archiveId
        ])
        XCTAssertEqual(listedBackups.first?.recordCounts.accounts, 3)
        XCTAssertEqual(listedBackups.first?.recordCounts.transactions, 4)
        XCTAssertEqual(
            try BackupArchiveCodec.decode(store.readBackupData(for: newerSummary)),
            newerArchive
        )
    }

    func testListBackupsIgnoresInvalidArchiveFiles() throws {
        let validArchive = Self.makeArchive(
            archiveId: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            accounts: 1,
            transactions: 1
        )
        let store = BackupFileStore(directory: temporaryDirectory)
        _ = try store.writeBackupArchive(validArchive)
        let invalidFileURL = temporaryDirectory.appendingPathComponent("broken.json")
        try Data("not json".utf8).write(to: invalidFileURL)

        let listedBackups = try store.listBackups()

        XCTAssertEqual(listedBackups.count, 1)
        XCTAssertEqual(listedBackups.first?.archiveId, validArchive.integrityMetadata.archiveId)
    }

    func testDeleteBackupRemovesBackupFile() throws {
        let archive = Self.makeArchive(
            archiveId: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            accounts: 1,
            transactions: 1
        )
        let store = BackupFileStore(directory: temporaryDirectory)
        let summary = try store.writeBackupArchive(archive)

        try store.deleteBackup(summary)

        XCTAssertFalse(FileManager.default.fileExists(atPath: summary.url.path))
        XCTAssertEqual(try store.listBackups(), [])
    }

    func testWriteAutomaticBackupUsesAutomaticFilenameAndSummaryKind() throws {
        let manualArchive = Self.makeArchive(
            archiveId: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            accounts: 1,
            transactions: 1
        )
        let automaticArchive = Self.makeArchive(
            archiveId: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_100),
            accounts: 1,
            transactions: 1
        )
        let store = BackupFileStore(directory: temporaryDirectory)

        let manualSummary = try store.writeBackupArchive(manualArchive, kind: .manual)
        let automaticSummary = try store.writeBackupArchive(automaticArchive, kind: .automatic)
        let listedBackups = try store.listBackups()

        XCTAssertFalse(manualSummary.isAutomatic)
        XCTAssertTrue(automaticSummary.isAutomatic)
        XCTAssertTrue(automaticSummary.filename.hasPrefix("Flux_Auto_"))
        XCTAssertEqual(listedBackups.first?.backupKind, .automatic)
        XCTAssertEqual(listedBackups.last?.backupKind, .manual)
    }

    func testBackupFileDisplayFormatterUsesReadableDateInsteadOfTechnicalFilename() throws {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }
        AppLanguagePreference.language = .english

        let exportedAt = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-04-16T15:21:51Z")
        )
        let summary = BackupFileSummary(
            url: temporaryDirectory.appendingPathComponent("Flux_20260416_152151-3.json"),
            filename: "Flux_20260416_152151-3.json",
            exportedAt: exportedAt,
            fileSize: 1_234_567,
            exportSourceDevice: "Unit Test iPhone",
            recordCounts: BackupRecordCounts(
                currencies: 0,
                exchangeRates: 0,
                categories: 0,
                accounts: 2,
                transactions: 5,
                scheduledOccurrenceExceptions: 0,
                budgets: 0
            ),
            archiveId: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        )
        let formatter = BackupFileDisplayFormatter(
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let title = formatter.title(for: summary)
        let subtitle = formatter.subtitle(for: summary)

        XCTAssertFalse(title.contains(summary.filename))
        XCTAssertFalse(title.contains(".json"))
        XCTAssertTrue(title.localizedStandardContains("2026"))
        XCTAssertTrue(title.localizedStandardContains("Apr"))
        XCTAssertTrue(title.localizedStandardContains("3:21"))
        XCTAssertTrue(subtitle.contains("2 accounts"))
        XCTAssertTrue(subtitle.contains("5 transactions"))
        XCTAssertTrue(subtitle.contains("MB"))
        XCTAssertFalse(subtitle.contains(summary.filename))
    }

    func testBackupFileDisplayFormatterLocalizesRecordText() throws {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }
        AppLanguagePreference.language = .traditionalChinese

        let exportedAt = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-04-16T08:47:00Z")
        )
        let summary = BackupFileSummary(
            url: temporaryDirectory.appendingPathComponent("Flux_20260416_084700.json"),
            filename: "Flux_20260416_084700.json",
            exportedAt: exportedAt,
            fileSize: 16_384,
            exportSourceDevice: "Unit Test iPhone",
            recordCounts: BackupRecordCounts(
                currencies: 0,
                exchangeRates: 0,
                categories: 0,
                accounts: 3,
                transactions: 2,
                scheduledOccurrenceExceptions: 0,
                budgets: 0
            ),
            archiveId: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        )
        let formatter = BackupFileDisplayFormatter(
            locale: Locale(identifier: "zh-Hant"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let title = formatter.title(for: summary)
        let subtitle = formatter.subtitle(for: summary)

        XCTAssertFalse(title.localizedStandardContains("Apr"))
        XCTAssertTrue(title.localizedStandardContains("2026"))
        XCTAssertEqual(subtitle, "3 個帳戶，2 筆交易，16 KB，此裝置")
    }

    func testBackupFileDisplayFormatterKeepsEnglishSingularRecordText() throws {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }
        AppLanguagePreference.language = .english

        let exportedAt = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-04-16T08:47:00Z")
        )
        let summary = BackupFileSummary(
            url: temporaryDirectory.appendingPathComponent("Flux_20260416_084700.json"),
            filename: "Flux_20260416_084700.json",
            exportedAt: exportedAt,
            fileSize: 1_024,
            exportSourceDevice: "Unit Test iPhone",
            recordCounts: BackupRecordCounts(
                currencies: 0,
                exchangeRates: 0,
                categories: 0,
                accounts: 1,
                transactions: 1,
                scheduledOccurrenceExceptions: 0,
                budgets: 0
            ),
            archiveId: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            storageLocation: .iCloudDrive
        )
        let formatter = BackupFileDisplayFormatter(
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(formatter.subtitle(for: summary), "1 account, 1 transaction, 1 KB, iCloud Drive")
    }

    func testBackupFileDisplayFormatterShowsLocalStorageLocation() throws {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }
        AppLanguagePreference.language = .traditionalChinese

        let exportedAt = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-04-16T08:47:00Z")
        )
        let summary = BackupFileSummary(
            url: temporaryDirectory.appendingPathComponent("Flux_20260416_084700.json"),
            filename: "Flux_20260416_084700.json",
            exportedAt: exportedAt,
            fileSize: 1_024,
            exportSourceDevice: "Unit Test iPhone",
            recordCounts: BackupRecordCounts(
                currencies: 0,
                exchangeRates: 0,
                categories: 0,
                accounts: 1,
                transactions: 1,
                scheduledOccurrenceExceptions: 0,
                budgets: 0
            ),
            archiveId: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            storageLocation: .thisDevice
        )
        let formatter = BackupFileDisplayFormatter(
            locale: Locale(identifier: "zh-Hant"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(formatter.subtitle(for: summary), "1 個帳戶，1 筆交易，1 KB，此裝置")
    }

    private static func makeArchive(
        archiveId: UUID,
        exportedAt: Date,
        accounts: Int,
        transactions: Int
    ) -> BackupArchive {
        let accountRecords = (0..<accounts).map { index in
            BackupAccountRecord(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa\(index)")!,
                name: "Account \(index)",
                type: .cash,
                currencyCode: "USD",
                initialBalance: 0,
                icon: "wallet.pass",
                colorHex: "#0A84FF",
                includeInTotal: true,
                createdAt: exportedAt.addingTimeInterval(TimeInterval(index))
            )
        }
        let transactionRecords = (0..<transactions).map { index in
            BackupTransactionRecord(
                id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb\(index)")!,
                amount: 10,
                currencyCode: "USD",
                type: .expense,
                date: exportedAt.addingTimeInterval(TimeInterval(index)),
                notes: nil,
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
                accountId: accountRecords.first?.id,
                categoryId: nil
            )
        }
        let financialData = BackupFinancialData(
            accounts: accountRecords,
            transactions: transactionRecords
        )
        let archive = BackupArchive(
            schemaVersion: BackupArchive.currentSchemaVersion,
            appVersion: "1.0.0",
            exportedAt: exportedAt,
            exportSourceDevice: "Unit Test iPhone",
            financialData: financialData,
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
                archiveId: archiveId,
                contentHash: "",
                recordCounts: BackupRecordCounts(
                    currencies: 0,
                    exchangeRates: 0,
                    categories: 0,
                    accounts: accounts,
                    transactions: transactions,
                    scheduledOccurrenceExceptions: 0,
                    budgets: 0
                ),
                createdByBuild: nil,
                compressionFormat: nil
            )
        )
        let encodedArchive = try! BackupArchiveCodec.encode(archive)
        return try! BackupArchiveCodec.decode(encodedArchive)
    }
}
