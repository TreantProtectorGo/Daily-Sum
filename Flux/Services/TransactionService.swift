import Foundation
import SwiftData

enum TransactionScheduledPlanKind: Equatable {
    case recurring
}

enum ScheduledFutureDeleteAction {
    case skipOccurrence
    case stopPlan
}

/// Service for managing Transaction CRUD operations
@MainActor
final class TransactionService {
    typealias ScheduledPlanKind = TransactionScheduledPlanKind

    private let context: ModelContext
    private let calendar: Calendar

    private enum Constants {
        static let installmentPurgeV1Key = "flux.installment.purge.v1.done"
    }

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    // MARK: - Create

    /// Creates a new transaction
    @discardableResult
    func create(
        amount: Decimal,
        type: TransactionType,
        date: Date = .now,
        notes: String? = nil,
        isTravelTransaction: Bool = false,
        travelSnapshot: TravelTransactionSnapshot? = nil,
        account: Account,
        category: Category?,
        receiptImageData: Data? = nil
    ) throws -> Transaction {
        let transaction = Transaction(
            amount: travelSnapshot?.accountAmount ?? amount,
            currencyCode: travelSnapshot?.accountCurrencyCode ?? account.currencyCode,
            type: type,
            date: date,
            notes: notes,
            isTravelTransaction: travelSnapshot != nil ? true : isTravelTransaction,
            travelAmount: travelSnapshot?.travelAmount,
            travelCurrencyCode: travelSnapshot?.travelCurrencyCode,
            travelExchangeRate: travelSnapshot?.exchangeRate,
            travelExchangeRateEffectiveDate: travelSnapshot?.effectiveDate,
            travelExchangeRateProvider: travelSnapshot?.provider,
            receiptImageData: receiptImageData,
            account: account,
            category: category
        )
        context.insert(transaction)
        try context.save()
        syncBudgetAlerts()
        return transaction
    }

    /// Creates a recurring transaction template
    @discardableResult
    func createRecurring(
        amount: Decimal,
        type: TransactionType,
        startDate: Date,
        recurrenceRule: RecurrenceRule,
        notes: String? = nil,
        isTravelTransaction: Bool = false,
        travelSnapshot: TravelTransactionSnapshot? = nil,
        account: Account,
        category: Category?
    ) throws -> Transaction {
        let template = Transaction(
            amount: travelSnapshot?.accountAmount ?? amount,
            currencyCode: travelSnapshot?.accountCurrencyCode ?? account.currencyCode,
            type: type,
            date: startDate,
            notes: notes,
            isTravelTransaction: travelSnapshot != nil ? true : isTravelTransaction,
            travelAmount: travelSnapshot?.travelAmount,
            travelCurrencyCode: travelSnapshot?.travelCurrencyCode,
            travelExchangeRate: travelSnapshot?.exchangeRate,
            travelExchangeRateEffectiveDate: travelSnapshot?.effectiveDate,
            travelExchangeRateProvider: travelSnapshot?.provider,
            isRecurringTemplate: true,
            recurrenceRule: recurrenceRule,
            schedulePlanType: .recurring,
            dueDayOfMonth: calendar.component(.day, from: startDate),
            reminderLeadDays: 1,
            account: account,
            category: category
        )
        context.insert(template)
        try context.save()
        return template
    }

    /// Creates a scheduled monthly expense template.
    @discardableResult
    func createScheduled(
        amount: Decimal,
        startDate: Date,
        dueDayOfMonth: Int,
        reminderLeadDays: Int,
        account: Account,
        category: Category?,
        notes: String? = nil,
        isTravelTransaction: Bool = false,
        travelSnapshot: TravelTransactionSnapshot? = nil,
        planType: ScheduledPlanKind
    ) throws -> Transaction {
        let normalizedDueDay = min(max(dueDayOfMonth, 1), 31)
        let normalizedLead = max(0, reminderLeadDays)

        switch planType {
        case .recurring:
            break
        }

        let template = Transaction(
            amount: travelSnapshot?.accountAmount ?? amount,
            currencyCode: travelSnapshot?.accountCurrencyCode ?? account.currencyCode,
            type: .expense,
            date: startDate,
            notes: notes,
            isTravelTransaction: travelSnapshot != nil ? true : isTravelTransaction,
            travelAmount: travelSnapshot?.travelAmount,
            travelCurrencyCode: travelSnapshot?.travelCurrencyCode,
            travelExchangeRate: travelSnapshot?.exchangeRate,
            travelExchangeRateEffectiveDate: travelSnapshot?.effectiveDate,
            travelExchangeRateProvider: travelSnapshot?.provider,
            isRecurringTemplate: true,
            recurrenceRule: .monthly,
            schedulePlanType: .recurring,
            dueDayOfMonth: normalizedDueDay,
            reminderLeadDays: normalizedLead,
            installmentTotalCount: nil,
            account: account,
            category: category
        )
        context.insert(template)
        try context.save()
        return template
    }

    // MARK: - Read

    /// Fetches all transactions (excluding templates) with optional filters
    func fetch(
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        type: TransactionType? = nil,
        account: Account? = nil,
        category: Category? = nil,
        limit: Int? = nil,
        sortDescending: Bool = true
    ) throws -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: sortDescending ? .reverse : .forward)]
        )

        descriptor.predicate = #Predicate<Transaction> { !$0.isRecurringTemplate }

        if let limit {
            descriptor.fetchLimit = limit
        }

        var results = try context.fetch(descriptor)

        if let startDate {
            results = results.filter { $0.date >= startDate }
        }
        if let endDate {
            results = results.filter { $0.date < endDate }
        }
        if let type {
            results = results.filter { $0.type == type }
        }
        if let account {
            results = results.filter { $0.account?.id == account.id }
        }
        if let category {
            results = results.filter { $0.category?.id == category.id }
        }

        return results
    }

    /// Fetches a transaction by ID
    func fetch(byId id: UUID) throws -> Transaction? {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    /// Fetches all recurring templates
    func fetchRecurringTemplates() throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.isRecurringTemplate },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Update

    /// Updates a transaction
    func update(
        _ transaction: Transaction,
        amount: Decimal? = nil,
        type: TransactionType? = nil,
        date: Date? = nil,
        notes: String? = nil,
        isTravelTransaction: Bool? = nil,
        travelSnapshot: TravelTransactionSnapshot? = nil,
        category: Category? = nil,
        receiptImageData: Data? = nil
    ) throws {
        if let travelSnapshot {
            TravelTransactionSnapshots.apply(travelSnapshot, to: transaction)
        } else {
            if let amount { transaction.amount = amount }
            if let isTravelTransaction {
                if isTravelTransaction {
                    transaction.isTravelTransaction = true
                } else {
                    TravelTransactionSnapshots.apply(nil, to: transaction)
                }
            }
        }
        if let type { transaction.type = type }
        if let date { transaction.date = date }
        if let notes { transaction.notes = notes }
        if let category { transaction.category = category }
        if let receiptImageData { transaction.receiptImageData = receiptImageData }

        try context.save()
        syncBudgetAlerts()
    }

    /// Updates a scheduled template and removes future generated entries so they can be regenerated.
    func updateScheduledTemplate(
        _ template: Transaction,
        amount: Decimal,
        startDate: Date,
        dueDayOfMonth: Int,
        reminderLeadDays: Int,
        account: Account,
        notes: String?,
        isTravelTransaction: Bool = false,
        travelSnapshot: TravelTransactionSnapshot? = nil,
        category: Category?,
        planType: ScheduledPlanKind
    ) throws {
        guard template.isRecurringTemplate else { return }

        switch planType {
        case .recurring:
            break
        }

        try deleteFutureGeneratedTransactions(forTemplateId: template.id)

        template.amount = travelSnapshot?.accountAmount ?? amount
        template.type = .expense
        template.date = startDate
        template.currencyCode = travelSnapshot?.accountCurrencyCode ?? account.currencyCode
        template.account = account
        template.notes = notes
        template.isTravelTransaction = travelSnapshot != nil ? true : isTravelTransaction
        template.travelAmount = travelSnapshot?.travelAmount
        template.travelCurrencyCode = travelSnapshot?.travelCurrencyCode
        template.travelExchangeRate = travelSnapshot?.exchangeRate
        template.travelExchangeRateEffectiveDate = travelSnapshot?.effectiveDate
        template.travelExchangeRateProvider = travelSnapshot?.provider
        template.category = category
        template.recurrenceRule = .monthly
        template.dueDayOfMonth = min(max(dueDayOfMonth, 1), 31)
        template.reminderLeadDays = max(0, reminderLeadDays)
        template.schedulePlanType = .recurring
        template.installmentTotalCount = nil
        template.installmentSequenceNumber = nil

        try context.save()
    }

    // MARK: - Delete

    /// Handles deleting a future generated scheduled transaction.
    func handleFutureGeneratedDeletion(
        _ transaction: Transaction,
        action: ScheduledFutureDeleteAction
    ) async throws {
        guard let templateId = transaction.recurringTemplateId else {
            try delete(transaction)
            return
        }

        switch action {
        case .skipOccurrence:
            try await skipScheduledOccurrence(templateId: templateId, dueDate: transaction.date)
        case .stopPlan:
            let selectedTransactionId = transaction.id
            try await stopScheduledPlan(templateId: templateId)
            if let remainingSelectedTransaction = try fetch(byId: selectedTransactionId),
               !remainingSelectedTransaction.isRecurringTemplate {
                try delete(remainingSelectedTransaction)
            }
        }
    }

    /// Marks one occurrence as skipped and removes the generated transaction for that due date.
    func skipScheduledOccurrence(templateId: UUID, dueDate: Date) async throws {
        let targetDay = dayKey(for: dueDate)

        let exceptionDescriptor = FetchDescriptor<ScheduledOccurrenceException>(
            predicate: #Predicate<ScheduledOccurrenceException> {
                $0.templateId == templateId && $0.occurrenceDate == targetDay
            }
        )
        let existingException = try context.fetch(exceptionDescriptor).first
        if existingException == nil {
            let exception = ScheduledOccurrenceException(
                templateId: templateId,
                occurrenceDate: targetDay
            )
            context.insert(exception)
        }

        let generatedDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> {
                $0.recurringTemplateId == templateId
            }
        )
        let generated = try context.fetch(generatedDescriptor)
        for transaction in generated where dayKey(for: transaction.date) == targetDay {
            context.delete(transaction)
        }

        try context.save()

        let reminderScheduler = TransactionReminderScheduler(context: context)
        await reminderScheduler.removeReminder(forTemplateId: templateId, dueDate: dueDate)
    }

    /// Stops one scheduled plan and removes all future generated entries.
    func stopScheduledPlan(templateId: UUID) async throws {
        let template = try fetch(byId: templateId)

        try deleteFutureGeneratedTransactions(forTemplateId: templateId)
        try deleteOccurrenceExceptions(forTemplateId: templateId)

        if let template {
            context.delete(template)
        }

        try context.save()

        let reminderScheduler = TransactionReminderScheduler(context: context)
        await reminderScheduler.removeReminders(forTemplateId: templateId)
    }

    /// Deletes a transaction
    func delete(_ transaction: Transaction) throws {
        if transaction.isRecurringTemplate {
            let templateId = transaction.id
            try deleteFutureGeneratedTransactions(forTemplateId: templateId)
            try deleteOccurrenceExceptions(forTemplateId: templateId)
            context.delete(transaction)
            try context.save()
            syncBudgetAlerts()

            if !RuntimeEnvironment.isRunningTests {
                Task { @MainActor in
                    let reminderScheduler = TransactionReminderScheduler(context: context)
                    await reminderScheduler.removeReminders(forTemplateId: templateId)
                }
            }
            return
        }

        context.delete(transaction)
        try context.save()
        syncBudgetAlerts()
    }

    /// Deletes multiple transactions
    func delete(_ transactions: [Transaction]) throws {
        for transaction in transactions {
            if transaction.isRecurringTemplate {
                try deleteFutureGeneratedTransactions(forTemplateId: transaction.id)
                try deleteOccurrenceExceptions(forTemplateId: transaction.id)
            }
            context.delete(transaction)
        }
        try context.save()
        syncBudgetAlerts()

        let templateIds = transactions
            .filter(\.isRecurringTemplate)
            .map(\.id)

        if !templateIds.isEmpty && !RuntimeEnvironment.isRunningTests {
            Task { @MainActor in
                let reminderScheduler = TransactionReminderScheduler(context: context)
                for templateId in templateIds {
                    await reminderScheduler.removeReminders(forTemplateId: templateId)
                }
            }
        }
    }

    private func syncBudgetAlerts() {
        guard !RuntimeEnvironment.isRunningTests else {
            return
        }

        Task { @MainActor in
            let scheduler = BudgetAlertScheduler(context: context)
            try? await scheduler.syncAlerts()
        }
    }

    /// Deletes all installment-related legacy data once.
    func purgeAllInstallmentDataIfNeeded() async throws {
        if UserDefaults.standard.bool(forKey: Constants.installmentPurgeV1Key) {
            return
        }

        let transactionDescriptor = FetchDescriptor<Transaction>()
        let allTransactions = try context.fetch(transactionDescriptor)
        let installmentTransactions = allTransactions.filter { transaction in
            transaction.schedulePlanTypeRawValue == "installment" ||
            transaction.installmentTotalCount != nil ||
            transaction.installmentSequenceNumber != nil
        }

        if !installmentTransactions.isEmpty {
            let affectedTemplateIds = Set(
                installmentTransactions.compactMap { transaction in
                    if transaction.isRecurringTemplate {
                        return transaction.id
                    }
                    return transaction.recurringTemplateId
                }
            )

            for transaction in installmentTransactions {
                context.delete(transaction)
            }

            for templateId in affectedTemplateIds {
                try deleteOccurrenceExceptions(forTemplateId: templateId)
            }

            try context.save()

            let reminderScheduler = TransactionReminderScheduler(context: context)
            for templateId in affectedTemplateIds {
                await reminderScheduler.removeReminders(forTemplateId: templateId)
            }
        }

        UserDefaults.standard.set(true, forKey: Constants.installmentPurgeV1Key)
    }

    private func deleteFutureGeneratedTransactions(forTemplateId templateId: UUID) throws {
        let now = Date.now
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> {
                $0.recurringTemplateId == templateId && $0.date > now
            }
        )
        let futureGenerated = try context.fetch(descriptor)
        for generated in futureGenerated {
            context.delete(generated)
        }
    }

    private func deleteOccurrenceExceptions(forTemplateId templateId: UUID) throws {
        let descriptor = FetchDescriptor<ScheduledOccurrenceException>(
            predicate: #Predicate<ScheduledOccurrenceException> { $0.templateId == templateId }
        )
        let exceptions = try context.fetch(descriptor)
        for exception in exceptions {
            context.delete(exception)
        }
    }

    private func dayKey(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    // MARK: - Aggregations

    /// Calculates total for transactions in a date range
    func total(
        from startDate: Date,
        to endDate: Date,
        type: TransactionType? = nil,
        account: Account? = nil
    ) throws -> Decimal {
        let transactions = try fetch(
            from: startDate,
            to: endDate,
            type: type,
            account: account
        )

        return transactions.reduce(Decimal.zero) { sum, tx in
            sum + tx.signedAmount
        }
    }

    /// Groups transactions by category for a date range
    func groupedByCategory(
        from startDate: Date,
        to endDate: Date,
        type: TransactionType
    ) throws -> [Category: Decimal] {
        let transactions = try fetch(from: startDate, to: endDate, type: type)

        var grouped: [Category: Decimal] = [:]
        for transaction in transactions {
            if let category = transaction.category {
                grouped[category, default: 0] += transaction.amount
            }
        }
        return grouped
    }
}
