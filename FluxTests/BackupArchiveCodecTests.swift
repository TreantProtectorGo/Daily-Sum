import XCTest
@testable import Flux

@MainActor
final class BackupArchiveCodecTests: XCTestCase {
    func testBackupArchiveCodecEncodesAndDecodesValidArchive() throws {
        let archive = Self.makeValidArchive()

        let data = try BackupArchiveCodec.encode(archive)
        let decoded = try BackupArchiveCodec.decode(data)

        XCTAssertEqual(decoded.schemaVersion, BackupArchive.currentSchemaVersion)
        XCTAssertEqual(decoded.appVersion, archive.appVersion)
        XCTAssertEqual(decoded.financialData.accounts.count, 1)
        XCTAssertEqual(decoded.financialData.transactions.count, 1)
        XCTAssertEqual(decoded.preferences.crossDevice.appLanguage, archive.preferences.crossDevice.appLanguage)
        XCTAssertTrue(decoded.integrityMetadata.contentHash.hasPrefix("sha256:"))
    }

    func testBackupArchiveCodecRejectsUnsupportedSchemaVersion() throws {
        let data = try Self.encodedData(from: Self.makeValidArchive()) { json in
            json["schemaVersion"] = 99
        }

        XCTAssertThrowsError(try BackupArchiveCodec.decode(data)) { error in
            guard let codecError = error as? BackupArchiveCodecError else {
                return XCTFail("Expected BackupArchiveCodecError, got \(error)")
            }
            switch codecError {
            case .unsupportedSchemaVersion(99):
                break
            default:
                XCTFail("Expected unsupportedSchemaVersion(99), got \(codecError)")
            }
        }
    }

    func testBackupArchiveCodecRejectsChecksumMismatch() throws {
        let data = try Self.encodedData(from: Self.makeValidArchive()) { json in
            json["appVersion"] = "2.0.0"
        }

        XCTAssertThrowsError(try BackupArchiveCodec.decode(data)) { error in
            guard let codecError = error as? BackupArchiveCodecError else {
                return XCTFail("Expected BackupArchiveCodecError, got \(error)")
            }
            switch codecError {
            case .checksumMismatch:
                break
            default:
                XCTFail("Expected checksumMismatch, got \(codecError)")
            }
        }
    }

    func testBackupArchiveCodecRejectsMissingRequiredSections() throws {
        let data = try Self.encodedData(from: Self.makeValidArchive()) { json in
            json.removeValue(forKey: "financialData")
            json.removeValue(forKey: "preferences")
        }

        XCTAssertThrowsError(try BackupArchiveCodec.decode(data)) { error in
            guard let codecError = error as? BackupArchiveCodecError else {
                return XCTFail("Expected BackupArchiveCodecError, got \(error)")
            }
            switch codecError {
            case .missingRequiredSections(let sections):
                XCTAssertEqual(sections.sorted(), ["financialData", "preferences"])
            default:
                XCTFail("Expected missingRequiredSections, got \(codecError)")
            }
        }
    }

    func testBackupArchiveCodecRejectsDuplicateRecordIDs() throws {
        var archive = Self.makeValidArchive()
        let duplicateID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        archive.financialData.accounts.append(
            BackupAccountRecord(
                id: duplicateID,
                name: "Duplicate Wallet",
                type: .cash,
                currencyCode: "USD",
                initialBalance: 0,
                icon: "banknote",
                colorHex: "#007AFF",
                includeInTotal: true,
                createdAt: Date(timeIntervalSince1970: 1_700_000_401)
            )
        )
        archive.integrityMetadata.recordCounts = BackupRecordCounts(
            currencies: 1,
            exchangeRates: 1,
            categories: 1,
            accounts: 2,
            transactions: 1,
            scheduledOccurrenceExceptions: 1,
            budgets: 1
        )

        XCTAssertThrowsError(try BackupArchiveCodec.encode(archive)) { error in
            guard let codecError = error as? BackupArchiveCodecError else {
                return XCTFail("Expected BackupArchiveCodecError, got \(error)")
            }
            switch codecError {
            case .duplicateRecordID(entity: "accounts", id: duplicateID):
                break
            default:
                XCTFail("Expected duplicateRecordID(accounts, \(duplicateID)), got \(codecError)")
            }
        }
    }

    func testBackupArchiveCodecRejectsMalformedInput() {
        let data = Data("not-json".utf8)

        XCTAssertThrowsError(try BackupArchiveCodec.decode(data)) { error in
            guard let codecError = error as? BackupArchiveCodecError else {
                return XCTFail("Expected BackupArchiveCodecError, got \(error)")
            }
            switch codecError {
            case .invalidArchiveFormat:
                break
            default:
                XCTFail("Expected invalidArchiveFormat, got \(codecError)")
            }
        }
    }

    func testBackupArchiveCodecRejectsTruncatedInput() {
        let data = Data("{\"schemaVersion\":1,\"appVersion\":\"1.0.0\"".utf8)

        XCTAssertThrowsError(try BackupArchiveCodec.decode(data)) { error in
            XCTAssertEqual(error as? BackupArchiveCodecError, .invalidArchiveFormat)
        }
    }

    func testBackupArchiveCodecRejectsOlderSchemaVersion() throws {
        let data = try Self.encodedData(from: Self.makeValidArchive()) { json in
            json["schemaVersion"] = BackupArchive.currentSchemaVersion - 1
        }

        XCTAssertThrowsError(try BackupArchiveCodec.decode(data)) { error in
            XCTAssertEqual(
                error as? BackupArchiveCodecError,
                .unsupportedSchemaVersion(BackupArchive.currentSchemaVersion - 1)
            )
        }
    }

    func testBackupArchiveCodecRejectsUnknownTypedPreferenceEnumValue() throws {
        let data = try Self.encodedData(from: Self.makeValidArchive()) { json in
            var preferences = json["preferences"] as? [String: Any] ?? [:]
            var crossDevice = preferences["crossDevice"] as? [String: Any] ?? [:]
            crossDevice["appLanguage"] = "pirate"
            preferences["crossDevice"] = crossDevice
            json["preferences"] = preferences
        }

        XCTAssertThrowsError(try BackupArchiveCodec.decode(data)) { error in
            XCTAssertEqual(error as? BackupArchiveCodecError, .invalidArchiveFormat)
        }
    }

    func testBackupArchiveCodecErrorsExposeUserReadableDescriptions() {
        XCTAssertEqual(
            BackupArchiveCodecError.invalidArchiveFormat.localizedDescription,
            "This backup file is invalid or corrupted."
        )
        XCTAssertEqual(
            BackupArchiveCodecError.recordCountMismatch(expected: [:], actual: [:]).localizedDescription,
            "This backup record count does not match its integrity metadata."
        )
    }

    func testBackupArchiveRoundTripPreservesArchiveContract() throws {
        let archive = Self.makeValidArchive()

        let data = try BackupArchiveCodec.encode(archive)
        let decoded = try BackupArchiveCodec.decode(data)

        XCTAssertEqual(decoded.appVersion, archive.appVersion)
        XCTAssertEqual(decoded.financialData.accounts.first?.name, "Cash Wallet")
        XCTAssertEqual(decoded.preferences.crossDevice.reportsCategoryRowLimit, 5)
        XCTAssertEqual(decoded.integrityMetadata.recordCounts.transactions, 1)
    }

    func testBackupPreferencesRoundTripPreservesTypedScopes() throws {
        let preferences = Self.makeValidPreferences()

        let decoded = try Self.roundTrip(preferences)

        XCTAssertEqual(decoded, preferences)
        XCTAssertEqual(decoded.crossDevice.appLanguage, .traditionalChinese)
        XCTAssertNil(decoded.deviceLocal.defaultTransactionAccountId)
    }

    func testBackupArchiveJSONShapeUsesTypedPreferenceKeys() throws {
        let archive = BackupArchive(
            schemaVersion: BackupArchive.currentSchemaVersion,
            appVersion: "1.0.0",
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exportSourceDevice: "iPhone 17 Pro",
            financialData: BackupFinancialData(),
            preferences: BackupPreferences(
                crossDevice: BackupCrossDevicePreferences(
                    preferredCurrencyCode: "USD",
                    appLanguage: .english,
                    isTravelCurrencyModeEnabled: false,
                    travelCurrencySource: .manual,
                    detectedTravelCurrencyCode: "HKD",
                    manualTravelCurrencyCode: "JPY",
                    reportsCategoryRowLimit: 8
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

        let encoder = JSONEncoder()
        let data = try encoder.encode(archive)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let preferences = try XCTUnwrap(json["preferences"] as? [String: Any])
        let crossDevice = try XCTUnwrap(preferences["crossDevice"] as? [String: Any])

        XCTAssertNotNil(json["schemaVersion"])
        XCTAssertNotNil(json["financialData"])
        XCTAssertEqual(crossDevice["appLanguage"] as? String, AppLanguage.english.rawValue)
        XCTAssertEqual(crossDevice["isTravelCurrencyModeEnabled"] as? Bool, false)
        XCTAssertEqual(crossDevice["travelCurrencySource"] as? String, TravelCurrencySource.manual.rawValue)
        XCTAssertNil(crossDevice["showUpcomingScheduledTransactions"])
    }

    private static func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(value)
        return try decoder.decode(T.self, from: data)
    }

    private static func makeValidArchive() -> BackupArchive {
        BackupArchive(
            schemaVersion: BackupArchive.currentSchemaVersion,
            appVersion: "1.0.0",
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exportSourceDevice: "iPhone 17 Pro",
            financialData: BackupFinancialData(
                currencies: [
                    BackupCurrencyRecord(
                        code: "USD",
                        exchangeRateToBase: 1,
                        lastUpdated: Date(timeIntervalSince1970: 1_700_000_100),
                        isBaseCurrency: true
                    )
                ],
                exchangeRates: [
                    BackupExchangeRateRecord(
                        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                        baseCurrencyCode: "USD",
                        quoteCurrencyCode: "HKD",
                        rate: 7.8,
                        effectiveDate: Date(timeIntervalSince1970: 1_700_000_200),
                        fetchedAt: Date(timeIntervalSince1970: 1_700_000_300),
                        provider: "mock"
                    )
                ],
                categories: [
                    BackupCategoryRecord(
                        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                        nameKey: "Food",
                        icon: "fork.knife",
                        colorHex: "#FF0000",
                        type: .expense,
                        isSystemDefault: false,
                        parentCategoryId: nil
                    )
                ],
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
                        receiptImageData: Data([0x01, 0x02]),
                        isRecurringTemplate: false,
                        recurrenceRule: .monthly,
                        schedulePlanTypeRawValue: SchedulePlanType.recurring.rawValue,
                        dueDayOfMonth: 15,
                        reminderLeadDays: 3,
                        installmentTotalCount: nil,
                        installmentSequenceNumber: nil,
                        recurringTemplateId: nil,
                        generatedDate: nil,
                        accountId: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                        categoryId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
                    )
                ],
                scheduledOccurrenceExceptions: [
                    BackupScheduledOccurrenceExceptionRecord(
                        id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                        templateId: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                        occurrenceDate: Date(timeIntervalSince1970: 1_700_000_600),
                        createdAt: Date(timeIntervalSince1970: 1_700_000_700)
                    )
                ],
                budgets: [
                    BackupBudgetRecord(
                        id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
                        limitAmount: 1000,
                        currencyCode: "USD",
                        period: .monthly,
                        alertThreshold: 0.8,
                        alertsEnabled: true,
                        alertTrackingPeriodStart: Date(timeIntervalSince1970: 1_700_000_800),
                        hasSentWarningAlertInTrackedPeriod: false,
                        hasSentExceededAlertInTrackedPeriod: false,
                        createdAt: Date(timeIntervalSince1970: 1_700_000_900),
                        isActive: true,
                        categoryId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
                    )
                ]
            ),
            preferences: makeValidPreferences(),
            integrityMetadata: BackupIntegrityMetadata(
                archiveId: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
                contentHash: "sha256:abc123",
                recordCounts: BackupRecordCounts(
                    currencies: 1,
                    exchangeRates: 1,
                    categories: 1,
                    accounts: 1,
                    transactions: 1,
                    scheduledOccurrenceExceptions: 1,
                    budgets: 1
                ),
                createdByBuild: "42",
                compressionFormat: "none"
            )
        )
    }

    private static func makeValidPreferences() -> BackupPreferences {
        BackupPreferences(
            crossDevice: BackupCrossDevicePreferences(
                preferredCurrencyCode: "HKD",
                appLanguage: .traditionalChinese,
                isTravelCurrencyModeEnabled: false,
                travelCurrencySource: .automatic,
                detectedTravelCurrencyCode: "JPY",
                manualTravelCurrencyCode: nil,
                reportsCategoryRowLimit: 5
            ),
            deviceLocal: BackupDeviceLocalPreferences(
                defaultTransactionAccountId: nil,
                rememberLastUsedTransactionAccount: false,
                lastUsedTransactionAccountId: nil,
                autoPresentAccountAfterCategorySelection: false
            )
        )
    }

    private static func encodedData(
        from archive: BackupArchive,
        mutate: (inout [String: Any]) -> Void
    ) throws -> Data {
        let encoded = try JSONEncoder().encode(archive)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        mutate(&json)
        return try JSONSerialization.data(withJSONObject: json)
    }
}
