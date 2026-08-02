import Foundation
import SwiftData

enum BackupRestoreMode: String, Codable, Equatable, CaseIterable {
    case replace
    case merge
}

enum BackupRestoreScope: String, Codable, Equatable, CaseIterable {
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
    case unsupportedRestoreMode(BackupRestoreMode)
}

extension BackupImportServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .missingReferencedRecord(recordType, recordID, referencedType, referencedID):
            return AppLocalization.formatted(
                "backup.error.missingReferencedRecord",
                defaultValue: "Missing %1$@ record %2$@ referenced by %3$@ record %4$@.",
                referencedType,
                referencedID.uuidString,
                recordType,
                recordID.uuidString
            )
        case let .unsupportedRestoreMode(mode):
            return AppLocalization.formatted(
                "backup.error.unsupportedRestoreMode",
                defaultValue: "Restore mode %@ is not supported yet.",
                mode.rawValue
            )
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

    func applyImport(
        data: Data,
        mode: BackupRestoreMode,
        scope: BackupRestoreScope,
        context: ModelContext
    ) throws -> ImportReport
}

@MainActor
final class BackupImportService: BackupImportServicing {
    private struct ImportedArchiveObjects {
        var accountTypeDefinitions: [UUID: AccountTypeDefinition] = [:]
        var currencies: [String: Currency] = [:]
        var categories: [UUID: Category] = [:]
        var accounts: [UUID: Account] = [:]
        var transactions: [UUID: Transaction] = [:]
        var budgets: [UUID: Budget] = [:]
    }

    private struct MergeState {
        var accountTypeDefinitions: [UUID: AccountTypeDefinition]
        var currencies: [String: Currency]
        var exchangeRates: [String: ExchangeRate]
        var categories: [UUID: Category]
        var accounts: [UUID: Account]
        var transactions: [UUID: Transaction]
        var budgets: [UUID: Budget]
        var scheduledOccurrenceExceptions: [UUID: ScheduledOccurrenceException]
    }

    private struct MergeAccumulator {
        var entries: [ImportReportEntry] = []
        var conflictReasons: [String] = []

        mutating func append(_ entry: ImportReportEntry) {
            entries.append(entry)
            if let conflictReason = entry.conflictReason,
               !conflictReasons.contains(conflictReason) {
                conflictReasons.append(conflictReason)
            }
        }
    }

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

    func applyImport(
        data: Data,
        mode: BackupRestoreMode,
        scope: BackupRestoreScope,
        context: ModelContext
    ) throws -> ImportReport {
        switch mode {
        case .replace:
            return try applyReplaceImport(data: data, mode: mode, scope: scope, context: context)
        case .merge:
            return try applyMergeImport(data: data, scope: scope, context: context)
        }
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
        let accountTypeDefinitionIDs = Set(archive.financialData.accountTypeDefinitions.map(\.id))
        let accountIDs = Set(archive.financialData.accounts.map(\.id))
        let categoryIDs = Set(archive.financialData.categories.map(\.id))
        let transactionIDs = Set(archive.financialData.transactions.map(\.id))

        for account in archive.financialData.accounts {
            if let definitionID = account.typeDefinitionId,
               !accountTypeDefinitionIDs.contains(definitionID) {
                throw BackupImportServiceError.missingReferencedRecord(
                    recordType: "accounts",
                    recordID: account.id,
                    referencedType: "accountTypeDefinitions",
                    referencedID: definitionID
                )
            }
        }

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

    private func applyReplaceImport(
        data: Data,
        mode: BackupRestoreMode,
        scope: BackupRestoreScope,
        context: ModelContext
    ) throws -> ImportReport {
        let archive = try BackupArchiveCodec.decode(data)
        let summary = try makePreflightSummary(from: archive, mode: mode, scope: scope)
        var marker = makeRestoreSessionMarker(from: summary)

        try restoreSessionMarkerStore.save(marker)

        marker.phase = .destructiveClearStarted
        marker.recoveryActionHint = "Replace restore started clearing local records."
        try restoreSessionMarkerStore.save(marker)

        do {
            try clearSupportedLocalRecords(in: context)

            marker.phase = .importPass1
            marker.recoveryActionHint = "Replace restore is rebuilding base records."
            try restoreSessionMarkerStore.save(marker)

            let importedObjects = importArchivePass1(archive, into: context)

            marker.phase = .importPass2
            marker.recoveryActionHint = "Replace restore is reconnecting relationships."
            try restoreSessionMarkerStore.save(marker)

            resolveRelationships(in: archive, with: importedObjects)
            try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        applyPreferences(from: archive.preferences, scope: scope)

        marker.phase = .preferencesApplied
        marker.recoveryActionHint = "Replace restore applied the selected preferences."
        try? restoreSessionMarkerStore.save(marker)

        marker.phase = .finalized
        marker.recoveryActionHint = "Restore completed successfully."
        try? restoreSessionMarkerStore.save(marker)
        restoreSessionMarkerStore.clear()

        return makeImportReport(from: archive)
    }

    private func applyMergeImport(
        data: Data,
        scope: BackupRestoreScope,
        context: ModelContext
    ) throws -> ImportReport {
        let archive = try BackupArchiveCodec.decode(data)
        var state = try loadMergeState(from: context)
        var accumulator = MergeAccumulator()

        mergeCurrencies(
            archive.financialData.currencies,
            into: context,
            state: &state,
            accumulator: &accumulator
        )
        mergeAccountTypeDefinitions(
            archive.financialData.accountTypeDefinitions,
            into: context,
            state: &state,
            accumulator: &accumulator
        )
        mergeCategories(
            archive.financialData.categories,
            into: context,
            state: &state,
            accumulator: &accumulator
        )
        mergeAccounts(
            archive.financialData.accounts,
            into: context,
            state: &state,
            accumulator: &accumulator
        )
        mergeExchangeRates(
            archive.financialData.exchangeRates,
            into: context,
            state: &state,
            accumulator: &accumulator
        )
        resolveCategoryParents(
            archive.financialData.categories,
            state: &state,
            accumulator: &accumulator
        )
        mergeTransactions(
            archive.financialData.transactions,
            into: context,
            state: &state,
            accumulator: &accumulator
        )
        mergeScheduledOccurrenceExceptions(
            archive.financialData.scheduledOccurrenceExceptions,
            into: context,
            state: &state,
            accumulator: &accumulator
        )
        mergeBudgets(
            archive.financialData.budgets,
            into: context,
            state: &state,
            accumulator: &accumulator
        )

        try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context)
        try context.save()
        applyPreferences(from: archive.preferences, scope: scope)
        restoreSessionMarkerStore.clear()

        return makeImportReport(
            archiveId: archive.integrityMetadata.archiveId,
            schemaVersion: archive.schemaVersion,
            entries: accumulator.entries,
            conflictReasons: accumulator.conflictReasons
        )
    }

    private func clearSupportedLocalRecords(in context: ModelContext) throws {
        try deleteAll(Transaction.self, from: context)
        try deleteAll(Budget.self, from: context)
        try deleteAll(ScheduledOccurrenceException.self, from: context)
        try deleteAll(Account.self, from: context)
        try deleteAll(AccountTypeDefinition.self, from: context)
        try deleteAll(Category.self, from: context)
        try deleteAll(ExchangeRate.self, from: context)
        try deleteAll(Currency.self, from: context)
    }

    private func deleteAll<Model: PersistentModel>(
        _ modelType: Model.Type,
        from context: ModelContext
    ) throws {
        let records = try context.fetch(FetchDescriptor<Model>())
        for record in records {
            context.delete(record)
        }
    }

    private func importArchivePass1(
        _ archive: BackupArchive,
        into context: ModelContext
    ) -> ImportedArchiveObjects {
        var imported = ImportedArchiveObjects()

        for record in archive.financialData.accountTypeDefinitions {
            let definition = AccountTypeDefinition(
                id: record.id,
                name: record.name,
                icon: record.icon,
                colorHex: record.colorHex,
                isSystemDefault: record.isSystemDefault,
                sortOrder: record.sortOrder,
                createdAt: record.createdAt,
                legacyType: record.legacyTypeRawValue.flatMap(AccountType.init(rawValue:))
            )
            context.insert(definition)
            imported.accountTypeDefinitions[record.id] = definition
        }

        for record in archive.financialData.currencies {
            let currency = Currency(
                code: record.code,
                exchangeRateToBase: record.exchangeRateToBase,
                lastUpdated: record.lastUpdated,
                isBaseCurrency: record.isBaseCurrency
            )
            context.insert(currency)
            imported.currencies[record.code] = currency
        }

        for record in archive.financialData.categories {
            let category = Category(
                id: record.id,
                nameKey: record.nameKey,
                icon: record.icon,
                colorHex: record.colorHex,
                type: record.type,
                isSystemDefault: record.isSystemDefault,
                sortOrder: record.sortOrder ?? 0
            )
            context.insert(category)
            imported.categories[record.id] = category
        }

        for record in archive.financialData.accounts {
            let account = Account(
                id: record.id,
                name: record.name,
                type: record.type,
                currencyCode: record.currencyCode,
                initialBalance: record.initialBalance,
                typeDefinition: record.typeDefinitionId.flatMap {
                    imported.accountTypeDefinitions[$0]
                },
                icon: record.icon,
                colorHex: record.colorHex,
                includeInTotal: record.includeInTotal,
                createdAt: record.createdAt
            )
            context.insert(account)
            imported.accounts[record.id] = account
        }

        for record in archive.financialData.exchangeRates {
            context.insert(
                ExchangeRate(
                    id: record.id,
                    baseCurrencyCode: record.baseCurrencyCode,
                    quoteCurrencyCode: record.quoteCurrencyCode,
                    rate: record.rate,
                    effectiveDate: record.effectiveDate,
                    fetchedAt: record.fetchedAt,
                    provider: record.provider
                )
            )
        }

        for record in archive.financialData.transactions {
            let transaction = Transaction(
                id: record.id,
                amount: record.amount,
                currencyCode: record.currencyCode,
                type: record.type,
                date: record.date,
                createdAt: record.createdAt ?? record.date,
                notes: record.notes,
                isTravelTransaction: record.isTravelTransaction,
                travelAmount: record.travelAmount,
                travelCurrencyCode: record.travelCurrencyCode,
                travelExchangeRate: record.travelExchangeRate,
                travelExchangeRateEffectiveDate: record.travelExchangeRateEffectiveDate,
                travelExchangeRateProvider: record.travelExchangeRateProvider,
                receiptImageData: record.receiptImageData,
                isRecurringTemplate: record.isRecurringTemplate,
                recurrenceRule: record.recurrenceRule,
                schedulePlanType: record.schedulePlanTypeRawValue.flatMap(SchedulePlanType.init(rawValue:)),
                dueDayOfMonth: record.dueDayOfMonth,
                reminderLeadDays: record.reminderLeadDays,
                installmentTotalCount: record.installmentTotalCount,
                installmentSequenceNumber: record.installmentSequenceNumber,
                recurringTemplateId: record.recurringTemplateId,
                generatedDate: record.generatedDate
            )
            context.insert(transaction)
            imported.transactions[record.id] = transaction
        }

        for record in archive.financialData.scheduledOccurrenceExceptions {
            context.insert(
                ScheduledOccurrenceException(
                    id: record.id,
                    templateId: record.templateId,
                    occurrenceDate: record.occurrenceDate,
                    createdAt: record.createdAt
                )
            )
        }

        for record in archive.financialData.budgets {
            let budget = Budget(
                id: record.id,
                limitAmount: record.limitAmount,
                currencyCode: record.currencyCode,
                period: record.period,
                alertThreshold: record.alertThreshold,
                alertsEnabled: record.alertsEnabled,
                alertTrackingPeriodStart: record.alertTrackingPeriodStart,
                hasSentWarningAlertInTrackedPeriod: record.hasSentWarningAlertInTrackedPeriod,
                hasSentExceededAlertInTrackedPeriod: record.hasSentExceededAlertInTrackedPeriod,
                createdAt: record.createdAt,
                isActive: record.isActive
            )
            context.insert(budget)
            imported.budgets[record.id] = budget
        }

        return imported
    }

    private func loadMergeState(from context: ModelContext) throws -> MergeState {
        let accountTypeDefinitions = try context.fetch(FetchDescriptor<AccountTypeDefinition>())
        let currencies = try context.fetch(FetchDescriptor<Currency>())
        let exchangeRates = try context.fetch(FetchDescriptor<ExchangeRate>())
        let categories = try context.fetch(FetchDescriptor<Category>())
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let scheduledOccurrenceExceptions = try context.fetch(
            FetchDescriptor<ScheduledOccurrenceException>()
        )

        return MergeState(
            accountTypeDefinitions: Dictionary(
                uniqueKeysWithValues: accountTypeDefinitions.map { ($0.id, $0) }
            ),
            currencies: Dictionary(uniqueKeysWithValues: currencies.map { ($0.code, $0) }),
            exchangeRates: Dictionary(
                uniqueKeysWithValues: exchangeRates.map {
                    (exchangeRateKey(
                        baseCurrencyCode: $0.baseCurrencyCode,
                        quoteCurrencyCode: $0.quoteCurrencyCode,
                        effectiveDate: $0.effectiveDate
                    ), $0)
                }
            ),
            categories: Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) }),
            accounts: Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) }),
            transactions: Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) }),
            budgets: Dictionary(uniqueKeysWithValues: budgets.map { ($0.id, $0) }),
            scheduledOccurrenceExceptions: Dictionary(
                uniqueKeysWithValues: scheduledOccurrenceExceptions.map { ($0.id, $0) }
            )
        )
    }

    private func mergeAccountTypeDefinitions(
        _ records: [BackupAccountTypeDefinitionRecord],
        into context: ModelContext,
        state: inout MergeState,
        accumulator: inout MergeAccumulator
    ) {
        for record in records {
            if let existing = state.accountTypeDefinitions[record.id] {
                let matches = existing.name == record.name &&
                    existing.icon == record.icon &&
                    existing.colorHex == record.colorHex &&
                    existing.isSystemDefault == record.isSystemDefault &&
                    existing.sortOrder == record.sortOrder &&
                    existing.createdAt == record.createdAt &&
                    existing.legacyTypeRawValue == record.legacyTypeRawValue
                if !matches {
                    existing.name = record.name
                    existing.icon = record.icon
                    existing.colorHex = record.colorHex
                    existing.isSystemDefault = record.isSystemDefault
                    existing.sortOrder = record.sortOrder
                    existing.createdAt = record.createdAt
                    existing.legacyTypeRawValue = record.legacyTypeRawValue
                }
                accumulator.append(
                    makeReportEntry(
                        entityType: "accountTypeDefinitions",
                        entityId: record.id,
                        action: matches ? .skipped : .updated,
                        severity: .info,
                        message: matches ? "Skipped unchanged account type \(record.id)." :
                            "Updated account type \(record.id).",
                        conflictReason: nil,
                        details: ["name": record.name]
                    )
                )
                continue
            }

            let definition = AccountTypeDefinition(
                id: record.id,
                name: record.name,
                icon: record.icon,
                colorHex: record.colorHex,
                isSystemDefault: record.isSystemDefault,
                sortOrder: record.sortOrder,
                createdAt: record.createdAt,
                legacyType: record.legacyTypeRawValue.flatMap(AccountType.init(rawValue:))
            )
            context.insert(definition)
            state.accountTypeDefinitions[record.id] = definition
            accumulator.append(
                makeReportEntry(
                    entityType: "accountTypeDefinitions",
                    entityId: record.id,
                    action: .imported,
                    severity: .info,
                    message: "Imported account type \(record.id).",
                    conflictReason: nil,
                    details: ["name": record.name]
                )
            )
        }
    }

    private func mergeCurrencies(
        _ records: [BackupCurrencyRecord],
        into context: ModelContext,
        state: inout MergeState,
        accumulator: inout MergeAccumulator
    ) {
        for record in records {
            if let existing = state.currencies[record.code] {
                if currencyMatches(existing, record: record) {
                    accumulator.append(
                        makeReportEntry(
                            entityType: "currencies",
                            entityId: nil,
                            action: .skipped,
                            severity: .info,
                            message: "Skipped unchanged currency \(record.code).",
                            conflictReason: nil,
                            details: ["code": record.code]
                        )
                    )
                } else {
                    existing.exchangeRateToBase = record.exchangeRateToBase
                    existing.lastUpdated = record.lastUpdated
                    existing.isBaseCurrency = record.isBaseCurrency
                    accumulator.append(
                        makeReportEntry(
                            entityType: "currencies",
                            entityId: nil,
                            action: .updated,
                            severity: .info,
                            message: "Updated currency \(record.code).",
                            conflictReason: nil,
                            details: ["code": record.code]
                        )
                    )
                }
                continue
            }

            let currency = Currency(
                code: record.code,
                exchangeRateToBase: record.exchangeRateToBase,
                lastUpdated: record.lastUpdated,
                isBaseCurrency: record.isBaseCurrency
            )
            context.insert(currency)
            state.currencies[record.code] = currency
            accumulator.append(
                makeReportEntry(
                    entityType: "currencies",
                    entityId: nil,
                    action: .imported,
                    severity: .info,
                    message: "Imported currency \(record.code).",
                    conflictReason: nil,
                    details: ["code": record.code]
                )
            )
        }
    }

    private func mergeCategories(
        _ records: [BackupCategoryRecord],
        into context: ModelContext,
        state: inout MergeState,
        accumulator: inout MergeAccumulator
    ) {
        for record in records {
            if let existing = state.categories[record.id] {
                if categoryMatches(existing, record: record) {
                    accumulator.append(
                        makeReportEntry(
                            entityType: "categories",
                            entityId: record.id,
                            action: .skipped,
                            severity: .info,
                            message: "Skipped unchanged category \(record.id).",
                            conflictReason: nil,
                            details: ["nameKey": record.nameKey]
                        )
                    )
                } else {
                    existing.nameKey = record.nameKey
                    existing.icon = record.icon
                    existing.colorHex = record.colorHex
                    existing.type = record.type
                    existing.isSystemDefault = record.isSystemDefault
                    existing.sortOrder = record.sortOrder ?? 0
                    accumulator.append(
                        makeReportEntry(
                            entityType: "categories",
                            entityId: record.id,
                            action: .updated,
                            severity: .info,
                            message: "Updated category \(record.id).",
                            conflictReason: nil,
                            details: ["nameKey": record.nameKey]
                        )
                    )
                }
                continue
            }

            let category = Category(
                id: record.id,
                nameKey: record.nameKey,
                icon: record.icon,
                colorHex: record.colorHex,
                type: record.type,
                isSystemDefault: record.isSystemDefault,
                sortOrder: record.sortOrder ?? 0
            )
            context.insert(category)
            state.categories[record.id] = category
            accumulator.append(
                makeReportEntry(
                    entityType: "categories",
                    entityId: record.id,
                    action: .imported,
                    severity: .info,
                    message: "Imported category \(record.id).",
                    conflictReason: nil,
                    details: ["nameKey": record.nameKey]
                )
            )
        }
    }

    private func resolveCategoryParents(
        _ records: [BackupCategoryRecord],
        state: inout MergeState,
        accumulator: inout MergeAccumulator
    ) {
        for record in records {
            guard let parentCategoryId = record.parentCategoryId,
                  let category = state.categories[record.id] else {
                continue
            }

            guard let parentCategory = state.categories[parentCategoryId] else {
                let error = BackupImportServiceError.missingReferencedRecord(
                    recordType: "categories",
                    recordID: record.id,
                    referencedType: "categories",
                    referencedID: parentCategoryId
                )
                accumulator.append(
                    makeReportEntry(
                        entityType: "categories",
                        entityId: record.id,
                        action: .failed,
                        severity: .error,
                        message: error.localizedDescription,
                        conflictReason: error.localizedDescription,
                        details: [
                            "referencedType": "categories",
                            "referencedID": parentCategoryId.uuidString
                        ]
                    )
                )
                continue
            }

            category.parentCategory = parentCategory
        }
    }

    private func mergeAccounts(
        _ records: [BackupAccountRecord],
        into context: ModelContext,
        state: inout MergeState,
        accumulator: inout MergeAccumulator
    ) {
        for record in records {
            if let existing = state.accounts[record.id] {
                if accountMatches(existing, record: record) {
                    accumulator.append(
                        makeReportEntry(
                            entityType: "accounts",
                            entityId: record.id,
                            action: .skipped,
                            severity: .info,
                            message: "Skipped unchanged account \(record.id).",
                            conflictReason: nil,
                            details: ["name": record.name]
                        )
                    )
                } else {
                    existing.name = record.name
                    existing.type = record.type
                    existing.typeDefinition = record.typeDefinitionId.flatMap {
                        state.accountTypeDefinitions[$0]
                    }
                    existing.currencyCode = record.currencyCode
                    existing.initialBalance = record.initialBalance
                    existing.icon = record.icon
                    existing.colorHex = record.colorHex
                    existing.includeInTotal = record.includeInTotal
                    existing.createdAt = record.createdAt
                    accumulator.append(
                        makeReportEntry(
                            entityType: "accounts",
                            entityId: record.id,
                            action: .updated,
                            severity: .info,
                            message: "Updated account \(record.id).",
                            conflictReason: nil,
                            details: ["name": record.name]
                        )
                    )
                }
                continue
            }

            let account = Account(
                id: record.id,
                name: record.name,
                type: record.type,
                currencyCode: record.currencyCode,
                initialBalance: record.initialBalance,
                typeDefinition: record.typeDefinitionId.flatMap {
                    state.accountTypeDefinitions[$0]
                },
                icon: record.icon,
                colorHex: record.colorHex,
                includeInTotal: record.includeInTotal,
                createdAt: record.createdAt
            )
            context.insert(account)
            state.accounts[record.id] = account
            accumulator.append(
                makeReportEntry(
                    entityType: "accounts",
                    entityId: record.id,
                    action: .imported,
                    severity: .info,
                    message: "Imported account \(record.id).",
                    conflictReason: nil,
                    details: ["name": record.name]
                )
            )
        }
    }

    private func mergeExchangeRates(
        _ records: [BackupExchangeRateRecord],
        into context: ModelContext,
        state: inout MergeState,
        accumulator: inout MergeAccumulator
    ) {
        for record in records {
            let key = exchangeRateKey(
                baseCurrencyCode: record.baseCurrencyCode,
                quoteCurrencyCode: record.quoteCurrencyCode,
                effectiveDate: record.effectiveDate
            )
            if let existing = state.exchangeRates[key] {
                if exchangeRateMatches(existing, record: record) {
                    accumulator.append(
                        makeReportEntry(
                            entityType: "exchangeRates",
                            entityId: existing.id,
                            action: .skipped,
                            severity: .info,
                            message: "Skipped unchanged exchange rate \(existing.id).",
                            conflictReason: nil,
                            details: [
                                "baseCurrencyCode": record.baseCurrencyCode,
                                "quoteCurrencyCode": record.quoteCurrencyCode
                            ]
                        )
                    )
                } else {
                    existing.id = record.id
                    existing.baseCurrencyCode = record.baseCurrencyCode
                    existing.quoteCurrencyCode = record.quoteCurrencyCode
                    existing.rate = record.rate
                    existing.effectiveDate = record.effectiveDate
                    existing.fetchedAt = record.fetchedAt
                    existing.provider = record.provider
                    accumulator.append(
                        makeReportEntry(
                            entityType: "exchangeRates",
                            entityId: record.id,
                            action: .updated,
                            severity: .info,
                            message: "Updated exchange rate \(record.id).",
                            conflictReason: nil,
                            details: [
                                "baseCurrencyCode": record.baseCurrencyCode,
                                "quoteCurrencyCode": record.quoteCurrencyCode
                            ]
                        )
                    )
                }
                continue
            }

            let exchangeRate = ExchangeRate(
                id: record.id,
                baseCurrencyCode: record.baseCurrencyCode,
                quoteCurrencyCode: record.quoteCurrencyCode,
                rate: record.rate,
                effectiveDate: record.effectiveDate,
                fetchedAt: record.fetchedAt,
                provider: record.provider
            )
            context.insert(exchangeRate)
            state.exchangeRates[key] = exchangeRate
            accumulator.append(
                makeReportEntry(
                    entityType: "exchangeRates",
                    entityId: record.id,
                    action: .imported,
                    severity: .info,
                    message: "Imported exchange rate \(record.id).",
                    conflictReason: nil,
                    details: [
                        "baseCurrencyCode": record.baseCurrencyCode,
                        "quoteCurrencyCode": record.quoteCurrencyCode
                    ]
                )
            )
        }
    }

    private func mergeTransactions(
        _ records: [BackupTransactionRecord],
        into context: ModelContext,
        state: inout MergeState,
        accumulator: inout MergeAccumulator
    ) {
        let archiveTransactionIDs = Set(records.map(\.id))

        for record in records {
            if let accountId = record.accountId, state.accounts[accountId] == nil {
                appendMissingReferenceFailure(
                    accumulator: &accumulator,
                    recordType: "transactions",
                    recordID: record.id,
                    referencedType: "accounts",
                    referencedID: accountId
                )
                continue
            }

            if let categoryId = record.categoryId, state.categories[categoryId] == nil {
                appendMissingReferenceFailure(
                    accumulator: &accumulator,
                    recordType: "transactions",
                    recordID: record.id,
                    referencedType: "categories",
                    referencedID: categoryId
                )
                continue
            }

            if let templateId = record.recurringTemplateId,
               state.transactions[templateId] == nil && !archiveTransactionIDs.contains(templateId) {
                appendMissingReferenceFailure(
                    accumulator: &accumulator,
                    recordType: "transactions",
                    recordID: record.id,
                    referencedType: "transactions",
                    referencedID: templateId
                )
                continue
            }

            let account = record.accountId.flatMap { state.accounts[$0] }
            let category = record.categoryId.flatMap { state.categories[$0] }

            if let existing = state.transactions[record.id] {
                if transactionMatches(existing, record: record) {
                    accumulator.append(
                        makeReportEntry(
                            entityType: "transactions",
                            entityId: record.id,
                            action: .skipped,
                            severity: .info,
                            message: "Skipped unchanged transaction \(record.id).",
                            conflictReason: nil,
                            details: ["currencyCode": record.currencyCode]
                        )
                    )
                } else {
                    update(existing: existing, from: record, account: account, category: category)
                    accumulator.append(
                        makeReportEntry(
                            entityType: "transactions",
                            entityId: record.id,
                            action: .updated,
                            severity: .info,
                            message: "Updated transaction \(record.id).",
                            conflictReason: nil,
                            details: ["currencyCode": record.currencyCode]
                        )
                    )
                }
                continue
            }

            let transaction = Transaction(
                id: record.id,
                amount: record.amount,
                currencyCode: record.currencyCode,
                type: record.type,
                date: record.date,
                notes: record.notes,
                isTravelTransaction: record.isTravelTransaction,
                travelAmount: record.travelAmount,
                travelCurrencyCode: record.travelCurrencyCode,
                travelExchangeRate: record.travelExchangeRate,
                travelExchangeRateEffectiveDate: record.travelExchangeRateEffectiveDate,
                travelExchangeRateProvider: record.travelExchangeRateProvider,
                receiptImageData: record.receiptImageData,
                isRecurringTemplate: record.isRecurringTemplate,
                recurrenceRule: record.recurrenceRule,
                schedulePlanType: record.schedulePlanTypeRawValue.flatMap(SchedulePlanType.init(rawValue:)),
                dueDayOfMonth: record.dueDayOfMonth,
                reminderLeadDays: record.reminderLeadDays,
                installmentTotalCount: record.installmentTotalCount,
                installmentSequenceNumber: record.installmentSequenceNumber,
                recurringTemplateId: record.recurringTemplateId,
                generatedDate: record.generatedDate,
                account: account,
                category: category
            )
            context.insert(transaction)
            state.transactions[record.id] = transaction
            accumulator.append(
                makeReportEntry(
                    entityType: "transactions",
                    entityId: record.id,
                    action: .imported,
                    severity: .info,
                    message: "Imported transaction \(record.id).",
                    conflictReason: nil,
                    details: ["currencyCode": record.currencyCode]
                )
            )
        }
    }

    private func mergeScheduledOccurrenceExceptions(
        _ records: [BackupScheduledOccurrenceExceptionRecord],
        into context: ModelContext,
        state: inout MergeState,
        accumulator: inout MergeAccumulator
    ) {
        for record in records {
            guard state.transactions[record.templateId] != nil else {
                appendMissingReferenceFailure(
                    accumulator: &accumulator,
                    recordType: "scheduledOccurrenceExceptions",
                    recordID: record.id,
                    referencedType: "transactions",
                    referencedID: record.templateId
                )
                continue
            }

            if let existing = state.scheduledOccurrenceExceptions[record.id] {
                if existing.templateId == record.templateId &&
                    existing.occurrenceDate == record.occurrenceDate &&
                    existing.createdAt == record.createdAt {
                    accumulator.append(
                        makeReportEntry(
                            entityType: "scheduledOccurrenceExceptions",
                            entityId: record.id,
                            action: .skipped,
                            severity: .info,
                            message: "Skipped unchanged scheduled occurrence exception \(record.id).",
                            conflictReason: nil,
                            details: ["templateId": record.templateId.uuidString]
                        )
                    )
                } else {
                    existing.templateId = record.templateId
                    existing.occurrenceDate = record.occurrenceDate
                    existing.createdAt = record.createdAt
                    accumulator.append(
                        makeReportEntry(
                            entityType: "scheduledOccurrenceExceptions",
                            entityId: record.id,
                            action: .updated,
                            severity: .info,
                            message: "Updated scheduled occurrence exception \(record.id).",
                            conflictReason: nil,
                            details: ["templateId": record.templateId.uuidString]
                        )
                    )
                }
                continue
            }

            let exception = ScheduledOccurrenceException(
                id: record.id,
                templateId: record.templateId,
                occurrenceDate: record.occurrenceDate,
                createdAt: record.createdAt
            )
            context.insert(exception)
            state.scheduledOccurrenceExceptions[record.id] = exception
            accumulator.append(
                makeReportEntry(
                    entityType: "scheduledOccurrenceExceptions",
                    entityId: record.id,
                    action: .imported,
                    severity: .info,
                    message: "Imported scheduled occurrence exception \(record.id).",
                    conflictReason: nil,
                    details: ["templateId": record.templateId.uuidString]
                )
            )
        }
    }

    private func mergeBudgets(
        _ records: [BackupBudgetRecord],
        into context: ModelContext,
        state: inout MergeState,
        accumulator: inout MergeAccumulator
    ) {
        for record in records {
            if let categoryId = record.categoryId, state.categories[categoryId] == nil {
                appendMissingReferenceFailure(
                    accumulator: &accumulator,
                    recordType: "budgets",
                    recordID: record.id,
                    referencedType: "categories",
                    referencedID: categoryId
                )
                continue
            }

            let category = record.categoryId.flatMap { state.categories[$0] }
            if let existing = state.budgets[record.id] {
                if budgetMatches(existing, record: record) {
                    accumulator.append(
                        makeReportEntry(
                            entityType: "budgets",
                            entityId: record.id,
                            action: .skipped,
                            severity: .info,
                            message: "Skipped unchanged budget \(record.id).",
                            conflictReason: nil,
                            details: ["currencyCode": record.currencyCode]
                        )
                    )
                } else {
                    existing.limitAmount = record.limitAmount
                    existing.currencyCode = record.currencyCode
                    existing.period = record.period
                    existing.alertThreshold = record.alertThreshold
                    existing.alertsEnabled = record.alertsEnabled
                    existing.alertTrackingPeriodStart = record.alertTrackingPeriodStart
                    existing.hasSentWarningAlertInTrackedPeriod =
                        record.hasSentWarningAlertInTrackedPeriod
                    existing.hasSentExceededAlertInTrackedPeriod =
                        record.hasSentExceededAlertInTrackedPeriod
                    existing.createdAt = record.createdAt
                    existing.isActive = record.isActive
                    existing.category = category
                    accumulator.append(
                        makeReportEntry(
                            entityType: "budgets",
                            entityId: record.id,
                            action: .updated,
                            severity: .info,
                            message: "Updated budget \(record.id).",
                            conflictReason: nil,
                            details: ["currencyCode": record.currencyCode]
                        )
                    )
                }
                continue
            }

            let budget = Budget(
                id: record.id,
                limitAmount: record.limitAmount,
                currencyCode: record.currencyCode,
                period: record.period,
                alertThreshold: record.alertThreshold,
                alertsEnabled: record.alertsEnabled,
                alertTrackingPeriodStart: record.alertTrackingPeriodStart,
                hasSentWarningAlertInTrackedPeriod: record.hasSentWarningAlertInTrackedPeriod,
                hasSentExceededAlertInTrackedPeriod: record.hasSentExceededAlertInTrackedPeriod,
                createdAt: record.createdAt,
                isActive: record.isActive,
                category: category
            )
            context.insert(budget)
            state.budgets[record.id] = budget
            accumulator.append(
                makeReportEntry(
                    entityType: "budgets",
                    entityId: record.id,
                    action: .imported,
                    severity: .info,
                    message: "Imported budget \(record.id).",
                    conflictReason: nil,
                    details: ["currencyCode": record.currencyCode]
                )
            )
        }
    }

    private func resolveRelationships(
        in archive: BackupArchive,
        with imported: ImportedArchiveObjects
    ) {
        for record in archive.financialData.categories {
            guard let parentCategoryId = record.parentCategoryId,
                  let category = imported.categories[record.id] else {
                continue
            }
            category.parentCategory = imported.categories[parentCategoryId]
        }

        for record in archive.financialData.transactions {
            guard let transaction = imported.transactions[record.id] else {
                continue
            }
            transaction.account = record.accountId.flatMap { imported.accounts[$0] }
            transaction.category = record.categoryId.flatMap { imported.categories[$0] }
        }

        for record in archive.financialData.budgets {
            guard let budget = imported.budgets[record.id] else {
                continue
            }
            budget.category = record.categoryId.flatMap { imported.categories[$0] }
        }
    }

    private func applyPreferences(
        from preferences: BackupPreferences,
        scope: BackupRestoreScope
    ) {
        switch scope {
        case .financialDataOnly:
            return
        case .financialDataAndCrossDevicePreferences:
            applyCrossDevicePreferences(preferences.crossDevice)
        case .financialDataAndAllPreferences:
            applyCrossDevicePreferences(preferences.crossDevice)
            applyDeviceLocalPreferences(preferences.deviceLocal)
        }
    }

    private func applyCrossDevicePreferences(_ preferences: BackupCrossDevicePreferences) {
        UserCurrencyPreference.currencyCode = preferences.preferredCurrencyCode
        AppLanguagePreference.language = preferences.appLanguage
        TravelCurrencyPreference.isEnabled = preferences.isTravelCurrencyModeEnabled ?? true
        TravelCurrencyPreference.source = preferences.travelCurrencySource
        TravelCurrencyPreference.detectedCurrencyCode = preferences.detectedTravelCurrencyCode
        TravelCurrencyPreference.manualCurrencyCode = preferences.manualTravelCurrencyCode
        ReportsCategoryRowLimitPreference.rowLimit = preferences.reportsCategoryRowLimit
    }

    private func applyDeviceLocalPreferences(_ preferences: BackupDeviceLocalPreferences) {
        TransactionAccountPreference.defaultAccountId = preferences.defaultTransactionAccountId
        TransactionAccountPreference.rememberLastUsedAccount =
            preferences.rememberLastUsedTransactionAccount
        TransactionAccountPreference.lastUsedAccountId = preferences.lastUsedTransactionAccountId
        TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection =
            preferences.autoPresentAccountAfterCategorySelection
    }

    private func makeImportReport(from archive: BackupArchive) -> ImportReport {
        let entries = makeImportedEntries(from: archive)
        return makeImportReport(
            archiveId: archive.integrityMetadata.archiveId,
            schemaVersion: archive.schemaVersion,
            entries: entries,
            conflictReasons: []
        )
    }

    private func makeImportedEntries(from archive: BackupArchive) -> [ImportReportEntry] {
        archive.financialData.currencies.map {
            ImportReportEntry(
                entityType: "currencies",
                entityId: nil,
                action: .imported,
                severity: .info,
                message: "Imported currency \($0.code).",
                conflictReason: nil,
                details: ["code": $0.code]
            )
        } +
        archive.financialData.exchangeRates.map {
            ImportReportEntry(
                entityType: "exchangeRates",
                entityId: $0.id,
                action: .imported,
                severity: .info,
                message: "Imported exchange rate \($0.id).",
                conflictReason: nil,
                details: [
                    "baseCurrencyCode": $0.baseCurrencyCode,
                    "quoteCurrencyCode": $0.quoteCurrencyCode
                ]
            )
        } +
        archive.financialData.categories.map {
            ImportReportEntry(
                entityType: "categories",
                entityId: $0.id,
                action: .imported,
                severity: .info,
                message: "Imported category \($0.id).",
                conflictReason: nil,
                details: ["nameKey": $0.nameKey]
            )
        } +
        archive.financialData.accounts.map {
            ImportReportEntry(
                entityType: "accounts",
                entityId: $0.id,
                action: .imported,
                severity: .info,
                message: "Imported account \($0.id).",
                conflictReason: nil,
                details: ["name": $0.name]
            )
        } +
        archive.financialData.transactions.map {
            ImportReportEntry(
                entityType: "transactions",
                entityId: $0.id,
                action: .imported,
                severity: .info,
                message: "Imported transaction \($0.id).",
                conflictReason: nil,
                details: ["currencyCode": $0.currencyCode]
            )
        } +
        archive.financialData.scheduledOccurrenceExceptions.map {
            ImportReportEntry(
                entityType: "scheduledOccurrenceExceptions",
                entityId: $0.id,
                action: .imported,
                severity: .info,
                message: "Imported scheduled occurrence exception \($0.id).",
                conflictReason: nil,
                details: ["templateId": $0.templateId.uuidString]
            )
        } +
        archive.financialData.budgets.map {
            ImportReportEntry(
                entityType: "budgets",
                entityId: $0.id,
                action: .imported,
                severity: .info,
                message: "Imported budget \($0.id).",
                conflictReason: nil,
                details: ["currencyCode": $0.currencyCode]
            )
        }
    }

    private func makeImportReport(
        archiveId: UUID,
        schemaVersion: Int,
        entries: [ImportReportEntry],
        conflictReasons: [String]
    ) -> ImportReport {
        ImportReport(
            archiveId: archiveId,
            schemaVersion: schemaVersion,
            summary: ImportReportSummary(
                importedCount: entries.filter { $0.action == .imported }.count,
                updatedCount: entries.filter { $0.action == .updated }.count,
                skippedCount: entries.filter { $0.action == .skipped }.count,
                failedCount: entries.filter { $0.action == .failed }.count,
                warningCount: entries.filter { $0.severity == .warning }.count
            ),
            entries: entries,
            conflictReasons: conflictReasons,
            createdAt: .now
        )
    }

    private func makeReportEntry(
        entityType: String,
        entityId: UUID?,
        action: ImportReportAction,
        severity: ImportReportSeverity,
        message: String,
        conflictReason: String?,
        details: [String: String]
    ) -> ImportReportEntry {
        ImportReportEntry(
            entityType: entityType,
            entityId: entityId,
            action: action,
            severity: severity,
            message: message,
            conflictReason: conflictReason,
            details: details
        )
    }

    private func appendMissingReferenceFailure(
        accumulator: inout MergeAccumulator,
        recordType: String,
        recordID: UUID,
        referencedType: String,
        referencedID: UUID
    ) {
        let error = BackupImportServiceError.missingReferencedRecord(
            recordType: recordType,
            recordID: recordID,
            referencedType: referencedType,
            referencedID: referencedID
        )
        accumulator.append(
            makeReportEntry(
                entityType: recordType,
                entityId: recordID,
                action: .failed,
                severity: .error,
                message: error.localizedDescription,
                conflictReason: error.localizedDescription,
                details: [
                    "referencedType": referencedType,
                    "referencedID": referencedID.uuidString
                ]
            )
        )
    }

    private func exchangeRateKey(
        baseCurrencyCode: String,
        quoteCurrencyCode: String,
        effectiveDate: Date
    ) -> String {
        "\(baseCurrencyCode)|\(quoteCurrencyCode)|\(effectiveDate.timeIntervalSince1970)"
    }

    private func currencyMatches(_ currency: Currency, record: BackupCurrencyRecord) -> Bool {
        currency.exchangeRateToBase == record.exchangeRateToBase &&
        currency.lastUpdated == record.lastUpdated &&
        currency.isBaseCurrency == record.isBaseCurrency
    }

    private func categoryMatches(_ category: Category, record: BackupCategoryRecord) -> Bool {
        category.nameKey == record.nameKey &&
        category.icon == record.icon &&
        category.colorHex == record.colorHex &&
        category.type == record.type &&
        category.isSystemDefault == record.isSystemDefault &&
        category.sortOrder == (record.sortOrder ?? 0) &&
        category.parentCategory?.id == record.parentCategoryId
    }

    private func accountMatches(_ account: Account, record: BackupAccountRecord) -> Bool {
        account.name == record.name &&
        account.type == record.type &&
        account.typeDefinition?.id == record.typeDefinitionId &&
        account.currencyCode == record.currencyCode &&
        account.initialBalance == record.initialBalance &&
        account.icon == record.icon &&
        account.colorHex == record.colorHex &&
        account.includeInTotal == record.includeInTotal &&
        account.createdAt == record.createdAt
    }

    private func exchangeRateMatches(
        _ exchangeRate: ExchangeRate,
        record: BackupExchangeRateRecord
    ) -> Bool {
        exchangeRate.id == record.id &&
        exchangeRate.baseCurrencyCode == record.baseCurrencyCode &&
        exchangeRate.quoteCurrencyCode == record.quoteCurrencyCode &&
        exchangeRate.rate == record.rate &&
        exchangeRate.effectiveDate == record.effectiveDate &&
        exchangeRate.fetchedAt == record.fetchedAt &&
        exchangeRate.provider == record.provider
    }

    private func transactionMatches(
        _ transaction: Transaction,
        record: BackupTransactionRecord
    ) -> Bool {
        transaction.amount == record.amount &&
        transaction.currencyCode == record.currencyCode &&
        transaction.type == record.type &&
        transaction.date == record.date &&
        (record.createdAt == nil || transaction.createdAt == record.createdAt) &&
        transaction.notes == record.notes &&
        transaction.isTravelTransaction == record.isTravelTransaction &&
        transaction.travelAmount == record.travelAmount &&
        transaction.travelCurrencyCode == record.travelCurrencyCode &&
        transaction.travelExchangeRate == record.travelExchangeRate &&
        transaction.travelExchangeRateEffectiveDate == record.travelExchangeRateEffectiveDate &&
        transaction.travelExchangeRateProvider == record.travelExchangeRateProvider &&
        transaction.receiptImageData == record.receiptImageData &&
        transaction.isRecurringTemplate == record.isRecurringTemplate &&
        transaction.recurrenceRule == record.recurrenceRule &&
        transaction.schedulePlanTypeRawValue == record.schedulePlanTypeRawValue &&
        transaction.dueDayOfMonth == record.dueDayOfMonth &&
        transaction.reminderLeadDays == record.reminderLeadDays &&
        transaction.installmentTotalCount == record.installmentTotalCount &&
        transaction.installmentSequenceNumber == record.installmentSequenceNumber &&
        transaction.recurringTemplateId == record.recurringTemplateId &&
        transaction.generatedDate == record.generatedDate &&
        transaction.account?.id == record.accountId &&
        transaction.category?.id == record.categoryId
    }

    private func budgetMatches(_ budget: Budget, record: BackupBudgetRecord) -> Bool {
        budget.limitAmount == record.limitAmount &&
        budget.currencyCode == record.currencyCode &&
        budget.period == record.period &&
        budget.alertThreshold == record.alertThreshold &&
        budget.alertsEnabled == record.alertsEnabled &&
        budget.alertTrackingPeriodStart == record.alertTrackingPeriodStart &&
        budget.hasSentWarningAlertInTrackedPeriod == record.hasSentWarningAlertInTrackedPeriod &&
        budget.hasSentExceededAlertInTrackedPeriod == record.hasSentExceededAlertInTrackedPeriod &&
        budget.createdAt == record.createdAt &&
        budget.isActive == record.isActive &&
        budget.category?.id == record.categoryId
    }

    private func update(
        existing transaction: Transaction,
        from record: BackupTransactionRecord,
        account: Account?,
        category: Category?
    ) {
        transaction.amount = record.amount
        transaction.currencyCode = record.currencyCode
        transaction.type = record.type
        transaction.date = record.date
        if let createdAt = record.createdAt {
            transaction.createdAt = createdAt
        }
        transaction.notes = record.notes
        transaction.isTravelTransaction = record.isTravelTransaction
        transaction.travelAmount = record.travelAmount
        transaction.travelCurrencyCode = record.travelCurrencyCode
        transaction.travelExchangeRate = record.travelExchangeRate
        transaction.travelExchangeRateEffectiveDate = record.travelExchangeRateEffectiveDate
        transaction.travelExchangeRateProvider = record.travelExchangeRateProvider
        transaction.receiptImageData = record.receiptImageData
        transaction.isRecurringTemplate = record.isRecurringTemplate
        transaction.recurrenceRule = record.recurrenceRule
        transaction.schedulePlanTypeRawValue = record.schedulePlanTypeRawValue
        transaction.dueDayOfMonth = record.dueDayOfMonth
        transaction.reminderLeadDays = record.reminderLeadDays
        transaction.installmentTotalCount = record.installmentTotalCount
        transaction.installmentSequenceNumber = record.installmentSequenceNumber
        transaction.recurringTemplateId = record.recurringTemplateId
        transaction.generatedDate = record.generatedDate
        transaction.account = account
        transaction.category = category
    }
}
