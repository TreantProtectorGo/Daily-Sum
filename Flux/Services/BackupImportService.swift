import Foundation

enum BackupRestoreMode: String, Codable, Equatable {
    case replace
    case merge
}

enum BackupRestoreScope: String, Codable, Equatable {
    case financialDataOnly
    case financialDataAndCrossDevicePreferences
    case financialDataAndAllPreferences
}

enum RestorePhase: String, Codable, Equatable {
    case preflightPassed
    case destructiveClearStarted
    case importPass1
    case importPass2
    case preferencesApplied
    case finalized
}

struct BackupImportPreflightSummary: Codable, Equatable {
    var archiveId: UUID
    var schemaVersion: Int
    var appVersion: String
    var exportedAt: Date
    var exportSourceDevice: String
    var selectedMode: BackupRestoreMode
    var selectedScope: BackupRestoreScope
    var recordCounts: BackupRecordCounts
    var warnings: [String]
}

enum BackupImportServiceError: Error, Equatable {
    case missingReferencedRecord(
        recordType: String,
        recordID: UUID,
        referencedType: String,
        referencedID: UUID
    )
}

extension BackupImportServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .missingReferencedRecord(recordType, recordID, referencedType, referencedID):
            return "Missing \(referencedType) record \(referencedID) referenced by \(recordType) record \(recordID)."
        }
    }
}

@MainActor
protocol BackupImportServicing {
    func prepareImport(
        data: Data,
        mode: BackupRestoreMode,
        scope: BackupRestoreScope
    ) throws -> BackupImportPreflightSummary
}

@MainActor
final class BackupImportService: BackupImportServicing {
    private let restoreSessionMarkerStore: any RestoreSessionMarkerStoring

    init(restoreSessionMarkerStore: (any RestoreSessionMarkerStoring)? = nil) {
        self.restoreSessionMarkerStore = restoreSessionMarkerStore ?? RestoreSessionMarkerStore()
    }

    func validateImport(
        data: Data,
        mode: BackupRestoreMode,
        scope: BackupRestoreScope
    ) throws -> BackupImportPreflightSummary {
        let archive = try BackupArchiveCodec.decode(data)
        return try makePreflightSummary(from: archive, mode: mode, scope: scope)
    }

    func prepareImport(
        data: Data,
        mode: BackupRestoreMode,
        scope: BackupRestoreScope
    ) throws -> BackupImportPreflightSummary {
        let summary = try validateImport(data: data, mode: mode, scope: scope)
        try restoreSessionMarkerStore.save(makeRestoreSessionMarker(from: summary))
        return summary
    }

    private func makePreflightSummary(
        from archive: BackupArchive,
        mode: BackupRestoreMode,
        scope: BackupRestoreScope
    ) throws -> BackupImportPreflightSummary {
        try validateReferencedRecords(in: archive)
        return BackupImportPreflightSummary(
            archiveId: archive.integrityMetadata.archiveId,
            schemaVersion: archive.schemaVersion,
            appVersion: archive.appVersion,
            exportedAt: archive.exportedAt,
            exportSourceDevice: archive.exportSourceDevice,
            selectedMode: mode,
            selectedScope: scope,
            recordCounts: archive.integrityMetadata.recordCounts,
            warnings: []
        )
    }

    private func validateReferencedRecords(in archive: BackupArchive) throws {
        let accountIDs = Set(archive.financialData.accounts.map(\.id))
        let categoryIDs = Set(archive.financialData.categories.map(\.id))
        let transactionIDs = Set(archive.financialData.transactions.map(\.id))

        for transaction in archive.financialData.transactions {
            if let accountID = transaction.accountId, !accountIDs.contains(accountID) {
                throw BackupImportServiceError.missingReferencedRecord(
                    recordType: "transactions",
                    recordID: transaction.id,
                    referencedType: "accounts",
                    referencedID: accountID
                )
            }

            if let categoryID = transaction.categoryId, !categoryIDs.contains(categoryID) {
                throw BackupImportServiceError.missingReferencedRecord(
                    recordType: "transactions",
                    recordID: transaction.id,
                    referencedType: "categories",
                    referencedID: categoryID
                )
            }

            if let templateID = transaction.recurringTemplateId, !transactionIDs.contains(templateID) {
                throw BackupImportServiceError.missingReferencedRecord(
                    recordType: "transactions",
                    recordID: transaction.id,
                    referencedType: "transactions",
                    referencedID: templateID
                )
            }
        }

        for category in archive.financialData.categories {
            if let parentCategoryID = category.parentCategoryId, !categoryIDs.contains(parentCategoryID) {
                throw BackupImportServiceError.missingReferencedRecord(
                    recordType: "categories",
                    recordID: category.id,
                    referencedType: "categories",
                    referencedID: parentCategoryID
                )
            }
        }

        for budget in archive.financialData.budgets {
            if let categoryID = budget.categoryId, !categoryIDs.contains(categoryID) {
                throw BackupImportServiceError.missingReferencedRecord(
                    recordType: "budgets",
                    recordID: budget.id,
                    referencedType: "categories",
                    referencedID: categoryID
                )
            }
        }

        for exception in archive.financialData.scheduledOccurrenceExceptions {
            if !transactionIDs.contains(exception.templateId) {
                throw BackupImportServiceError.missingReferencedRecord(
                    recordType: "scheduledOccurrenceExceptions",
                    recordID: exception.id,
                    referencedType: "transactions",
                    referencedID: exception.templateId
                )
            }
        }
    }

    private func makeRestoreSessionMarker(
        from summary: BackupImportPreflightSummary
    ) -> RestoreSessionMarker {
        RestoreSessionMarker(
            restoreSessionId: UUID(),
            startedAt: .now,
            archiveId: summary.archiveId,
            mode: summary.selectedMode,
            scope: summary.selectedScope,
            phase: .preflightPassed,
            recoveryActionHint: "Preflight completed. Resume the staged restore or clear it before retrying."
        )
    }
}
