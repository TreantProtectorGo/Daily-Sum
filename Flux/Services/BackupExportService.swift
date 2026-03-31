import Foundation
import SwiftData
import UIKit

@MainActor
protocol BackupExportServicing {
    func makeBackupArchive() throws -> BackupArchive
}

@MainActor
final class BackupExportService: BackupExportServicing {
    private let modelContext: ModelContext

    init(context: ModelContext) {
        self.modelContext = context
    }

    func makeBackupArchive() throws -> BackupArchive {
        let financialData = try makeFinancialData()
        let preferences = makePreferences()
        let archive = BackupArchive(
            schemaVersion: BackupArchive.currentSchemaVersion,
            appVersion: appVersion,
            exportedAt: .now,
            exportSourceDevice: UIDevice.current.name,
            financialData: financialData,
            preferences: preferences,
            integrityMetadata: BackupIntegrityMetadata(
                archiveId: UUID(),
                contentHash: "",
                recordCounts: recordCounts(for: financialData),
                createdByBuild: buildNumber,
                compressionFormat: nil
            )
        )

        let encodedArchive = try BackupArchiveCodec.encode(archive)
        return try BackupArchiveCodec.decode(encodedArchive)
    }

    private func makeFinancialData() throws -> BackupFinancialData {
        let currencies = try modelContext.fetch(
            FetchDescriptor<Currency>(
                sortBy: [SortDescriptor(\.code)]
            )
        )
        let exchangeRates = try modelContext.fetch(
            FetchDescriptor<ExchangeRate>(
                sortBy: [
                    SortDescriptor(\.baseCurrencyCode),
                    SortDescriptor(\.quoteCurrencyCode),
                    SortDescriptor(\.effectiveDate),
                    SortDescriptor(\.id)
                ]
            )
        )
        let categories = try modelContext.fetch(
            FetchDescriptor<Category>(
                sortBy: [
                    SortDescriptor(\.nameKey),
                    SortDescriptor(\.id)
                ]
            )
        )
        let accounts = try modelContext.fetch(
            FetchDescriptor<Account>(
                sortBy: [
                    SortDescriptor(\.createdAt),
                    SortDescriptor(\.name),
                    SortDescriptor(\.id)
                ]
            )
        )
        let transactions = try modelContext.fetch(
            FetchDescriptor<Transaction>(
                sortBy: [
                    SortDescriptor(\.date),
                    SortDescriptor(\.id)
                ]
            )
        )
        let scheduledOccurrenceExceptions = try modelContext.fetch(
            FetchDescriptor<ScheduledOccurrenceException>(
                sortBy: [
                    SortDescriptor(\.occurrenceDate),
                    SortDescriptor(\.templateId),
                    SortDescriptor(\.id)
                ]
            )
        )
        let budgets = try modelContext.fetch(
            FetchDescriptor<Budget>(
                sortBy: [
                    SortDescriptor(\.createdAt),
                    SortDescriptor(\.id)
                ]
            )
        )

        return BackupFinancialData(
            currencies: currencies.map { currency in
                BackupCurrencyRecord(
                    code: currency.code,
                    exchangeRateToBase: currency.exchangeRateToBase,
                    lastUpdated: currency.lastUpdated,
                    isBaseCurrency: currency.isBaseCurrency
                )
            },
            exchangeRates: exchangeRates.map { exchangeRate in
                BackupExchangeRateRecord(
                    id: exchangeRate.id,
                    baseCurrencyCode: exchangeRate.baseCurrencyCode,
                    quoteCurrencyCode: exchangeRate.quoteCurrencyCode,
                    rate: exchangeRate.rate,
                    effectiveDate: exchangeRate.effectiveDate,
                    fetchedAt: exchangeRate.fetchedAt,
                    provider: exchangeRate.provider
                )
            },
            categories: categories.map { category in
                BackupCategoryRecord(
                    id: category.id,
                    nameKey: category.nameKey,
                    icon: category.icon,
                    colorHex: category.colorHex,
                    type: category.type,
                    isSystemDefault: category.isSystemDefault,
                    parentCategoryId: category.parentCategory?.id
                )
            },
            accounts: accounts.map { account in
                BackupAccountRecord(
                    id: account.id,
                    name: account.name,
                    type: account.type,
                    currencyCode: account.currencyCode,
                    initialBalance: account.initialBalance,
                    icon: account.icon,
                    colorHex: account.colorHex,
                    includeInTotal: account.includeInTotal,
                    createdAt: account.createdAt
                )
            },
            transactions: transactions.map { transaction in
                BackupTransactionRecord(
                    id: transaction.id,
                    amount: transaction.amount,
                    currencyCode: transaction.currencyCode,
                    type: transaction.type,
                    date: transaction.date,
                    notes: transaction.notes,
                    isTravelTransaction: transaction.isTravelTransaction,
                    travelAmount: transaction.travelAmount,
                    travelCurrencyCode: transaction.travelCurrencyCode,
                    travelExchangeRate: transaction.travelExchangeRate,
                    travelExchangeRateEffectiveDate: transaction.travelExchangeRateEffectiveDate,
                    travelExchangeRateProvider: transaction.travelExchangeRateProvider,
                    receiptImageData: transaction.receiptImageData,
                    isRecurringTemplate: transaction.isRecurringTemplate,
                    recurrenceRule: transaction.recurrenceRule,
                    schedulePlanTypeRawValue: transaction.schedulePlanTypeRawValue,
                    dueDayOfMonth: transaction.dueDayOfMonth,
                    reminderLeadDays: transaction.reminderLeadDays,
                    installmentTotalCount: transaction.installmentTotalCount,
                    installmentSequenceNumber: transaction.installmentSequenceNumber,
                    recurringTemplateId: transaction.recurringTemplateId,
                    generatedDate: transaction.generatedDate,
                    accountId: transaction.account?.id,
                    categoryId: transaction.category?.id
                )
            },
            scheduledOccurrenceExceptions: scheduledOccurrenceExceptions.map { exception in
                BackupScheduledOccurrenceExceptionRecord(
                    id: exception.id,
                    templateId: exception.templateId,
                    occurrenceDate: exception.occurrenceDate,
                    createdAt: exception.createdAt
                )
            },
            budgets: budgets.map { budget in
                BackupBudgetRecord(
                    id: budget.id,
                    limitAmount: budget.limitAmount,
                    currencyCode: budget.currencyCode,
                    period: budget.period,
                    alertThreshold: budget.alertThreshold,
                    alertsEnabled: budget.alertsEnabled,
                    alertTrackingPeriodStart: budget.alertTrackingPeriodStart,
                    hasSentWarningAlertInTrackedPeriod: budget.hasSentWarningAlertInTrackedPeriod,
                    hasSentExceededAlertInTrackedPeriod: budget.hasSentExceededAlertInTrackedPeriod,
                    createdAt: budget.createdAt,
                    isActive: budget.isActive,
                    categoryId: budget.category?.id
                )
            }
        )
    }

    private func makePreferences() -> BackupPreferences {
        BackupPreferences(
            crossDevice: BackupCrossDevicePreferences(
                preferredCurrencyCode: UserCurrencyPreference.currencyCode,
                appLanguage: AppLanguagePreference.language,
                travelCurrencySource: TravelCurrencyPreference.source,
                detectedTravelCurrencyCode: TravelCurrencyPreference.detectedCurrencyCode,
                manualTravelCurrencyCode: TravelCurrencyPreference.manualCurrencyCode,
                reportsCategoryRowLimit: ReportsCategoryRowLimitPreference.rowLimit
            ),
            deviceLocal: BackupDeviceLocalPreferences(
                defaultTransactionAccountId: TransactionAccountPreference.defaultAccountId,
                rememberLastUsedTransactionAccount: TransactionAccountPreference.rememberLastUsedAccount,
                lastUsedTransactionAccountId: TransactionAccountPreference.lastUsedAccountId,
                autoPresentAccountAfterCategorySelection:
                    TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection
            )
        )
    }

    private func recordCounts(for financialData: BackupFinancialData) -> BackupRecordCounts {
        BackupRecordCounts(
            currencies: financialData.currencies.count,
            exchangeRates: financialData.exchangeRates.count,
            categories: financialData.categories.count,
            accounts: financialData.accounts.count,
            transactions: financialData.transactions.count,
            scheduledOccurrenceExceptions: financialData.scheduledOccurrenceExceptions.count,
            budgets: financialData.budgets.count
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
