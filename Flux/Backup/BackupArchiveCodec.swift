import Foundation
import CryptoKit

enum BackupArchiveCodecError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case missingRequiredSections([String])
    case checksumMismatch(expected: String, actual: String)
    case duplicateRecordID(entity: String, id: UUID)
    case invalidArchiveFormat
    case recordCountMismatch(expected: [String: Int], actual: [String: Int])
}

enum BackupArchiveCodec {
    private static let requiredTopLevelSections = [
        "schemaVersion",
        "appVersion",
        "exportedAt",
        "exportSourceDevice",
        "financialData",
        "preferences",
        "integrityMetadata"
    ]

    static func encode(_ archive: BackupArchive) throws -> Data {
        try validateSemanticStructure(archive)

        let contentHash = try contentHash(for: archive)
        let normalizedArchive = BackupArchive(
            schemaVersion: archive.schemaVersion,
            appVersion: archive.appVersion,
            exportedAt: archive.exportedAt,
            exportSourceDevice: archive.exportSourceDevice,
            financialData: archive.financialData,
            preferences: archive.preferences,
            integrityMetadata: BackupIntegrityMetadata(
                archiveId: archive.integrityMetadata.archiveId,
                contentHash: contentHash,
                recordCounts: archive.integrityMetadata.recordCounts,
                createdByBuild: archive.integrityMetadata.createdByBuild,
                compressionFormat: archive.integrityMetadata.compressionFormat
            )
        )

        return try makeEncoder().encode(normalizedArchive)
    }

    static func decode(_ data: Data) throws -> BackupArchive {
        let jsonObject: [String: Any]
        do {
            jsonObject = try parseJSONObject(from: data)
        } catch {
            throw BackupArchiveCodecError.invalidArchiveFormat
        }
        try validateRequiredTopLevelSections(in: jsonObject)

        let archive: BackupArchive
        do {
            archive = try JSONDecoder().decode(BackupArchive.self, from: data)
        } catch {
            throw BackupArchiveCodecError.invalidArchiveFormat
        }

        try validateSemanticStructure(archive)
        try verifyIntegrity(of: archive)
        return archive
    }

    static func validate(_ archive: BackupArchive) throws {
        try validateSemanticStructure(archive)
        try verifyIntegrity(of: archive)
    }

    private static func validateSemanticStructure(_ archive: BackupArchive) throws {
        guard archive.schemaVersion == BackupArchive.currentSchemaVersion else {
            throw BackupArchiveCodecError.unsupportedSchemaVersion(archive.schemaVersion)
        }

        let actualCounts = actualRecordCounts(for: archive)
        let expectedCounts = expectedRecordCounts(from: archive.integrityMetadata.recordCounts)
        guard actualCounts == expectedCounts else {
            throw BackupArchiveCodecError.recordCountMismatch(
                expected: expectedCounts,
                actual: actualCounts
            )
        }

        try validateUniqueIDs(archive.financialData.exchangeRates, entity: "exchangeRates")
        try validateUniqueIDs(archive.financialData.categories, entity: "categories")
        try validateUniqueIDs(archive.financialData.accounts, entity: "accounts")
        try validateUniqueIDs(archive.financialData.transactions, entity: "transactions")
        try validateUniqueIDs(
            archive.financialData.scheduledOccurrenceExceptions,
            entity: "scheduledOccurrenceExceptions"
        )
        try validateUniqueIDs(archive.financialData.budgets, entity: "budgets")

        try validateExchangeRateNaturalKeyUniqueness(archive.financialData.exchangeRates)
    }

    private static func verifyIntegrity(of archive: BackupArchive) throws {
        let expectedHash = archive.integrityMetadata.contentHash
        let actualHash = try contentHash(for: archive)

        guard expectedHash == actualHash else {
            throw BackupArchiveCodecError.checksumMismatch(
                expected: expectedHash,
                actual: actualHash
            )
        }
    }

    private static func contentHash(for archive: BackupArchive) throws -> String {
        let payload = BackupArchiveContentPayload(
            schemaVersion: archive.schemaVersion,
            appVersion: archive.appVersion,
            exportedAt: archive.exportedAt,
            exportSourceDevice: archive.exportSourceDevice,
            financialData: archive.financialData,
            preferences: archive.preferences
        )
        let data = try makeEncoder().encode(payload)
        let digest = SHA256.hash(data: data)
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func actualRecordCounts(for archive: BackupArchive) -> [String: Int] {
        [
            "currencies": archive.financialData.currencies.count,
            "exchangeRates": archive.financialData.exchangeRates.count,
            "categories": archive.financialData.categories.count,
            "accounts": archive.financialData.accounts.count,
            "transactions": archive.financialData.transactions.count,
            "scheduledOccurrenceExceptions": archive.financialData.scheduledOccurrenceExceptions.count,
            "budgets": archive.financialData.budgets.count
        ]
    }

    private static func expectedRecordCounts(from counts: BackupRecordCounts) -> [String: Int] {
        [
            "currencies": counts.currencies,
            "exchangeRates": counts.exchangeRates,
            "categories": counts.categories,
            "accounts": counts.accounts,
            "transactions": counts.transactions,
            "scheduledOccurrenceExceptions": counts.scheduledOccurrenceExceptions,
            "budgets": counts.budgets
        ]
    }

    private static func validateUniqueIDs<T>(
        _ records: [T],
        entity: String,
        id: (T) -> UUID
    ) throws {
        var seen = Set<UUID>()
        for record in records {
            let recordID = id(record)
            if !seen.insert(recordID).inserted {
                throw BackupArchiveCodecError.duplicateRecordID(entity: entity, id: recordID)
            }
        }
    }

    private static func validateUniqueIDs(_ records: [BackupExchangeRateRecord], entity: String) throws {
        try validateUniqueIDs(records, entity: entity, id: \.id)
    }

    private static func validateUniqueIDs(_ records: [BackupCategoryRecord], entity: String) throws {
        try validateUniqueIDs(records, entity: entity, id: \.id)
    }

    private static func validateUniqueIDs(_ records: [BackupAccountRecord], entity: String) throws {
        try validateUniqueIDs(records, entity: entity, id: \.id)
    }

    private static func validateUniqueIDs(_ records: [BackupTransactionRecord], entity: String) throws {
        try validateUniqueIDs(records, entity: entity, id: \.id)
    }

    private static func validateUniqueIDs(
        _ records: [BackupScheduledOccurrenceExceptionRecord],
        entity: String
    ) throws {
        try validateUniqueIDs(records, entity: entity, id: \.id)
    }

    private static func validateUniqueIDs(_ records: [BackupBudgetRecord], entity: String) throws {
        try validateUniqueIDs(records, entity: entity, id: \.id)
    }

    private static func validateExchangeRateNaturalKeyUniqueness(
        _ records: [BackupExchangeRateRecord]
    ) throws {
        var seen = Set<ExchangeRateNaturalKey>()
        for record in records {
            let key = ExchangeRateNaturalKey(
                baseCurrencyCode: record.baseCurrencyCode,
                quoteCurrencyCode: record.quoteCurrencyCode,
                effectiveDate: record.effectiveDate
            )
            if !seen.insert(key).inserted {
                throw BackupArchiveCodecError.invalidArchiveFormat
            }
        }
    }

    private static func validateRequiredTopLevelSections(in jsonObject: [String: Any]) throws {
        let missingSections = requiredTopLevelSections.filter { jsonObject[$0] == nil }
        guard missingSections.isEmpty else {
            throw BackupArchiveCodecError.missingRequiredSections(missingSections)
        }
    }

    private static func parseJSONObject(from data: Data) throws -> [String: Any] {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackupArchiveCodecError.invalidArchiveFormat
        }
        return jsonObject
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private struct BackupArchiveContentPayload: Codable {
    let schemaVersion: Int
    let appVersion: String
    let exportedAt: Date
    let exportSourceDevice: String
    let financialData: BackupFinancialData
    let preferences: BackupPreferences
}

private struct ExchangeRateNaturalKey: Hashable {
    let baseCurrencyCode: String
    let quoteCurrencyCode: String
    let effectiveDate: Date
}
