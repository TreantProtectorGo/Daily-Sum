import Foundation
import SwiftData

/// Generates transaction instances from recurring templates
@MainActor
struct RecurringTransactionGenerator {
    static let defaultLookAheadDays = 31

    private let context: ModelContext

    /// Number of days ahead to generate scheduled transactions.
    var lookAheadDays: Int = Self.defaultLookAheadDays

    init(context: ModelContext) {
        self.context = context
    }

    /// Generates all pending scheduled transactions up to the look-ahead date
    @discardableResult
    func generatePendingTransactions() throws -> [Transaction] {
        let transactionService = TransactionService(context: context)
        let templates = try transactionService.fetchRecurringTemplates()
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: lookAheadDays,
            to: Date.now
        )!

        var generatedTransactions: [Transaction] = []

        for template in templates {
            let generated = try generateTransactions(
                from: template,
                upTo: cutoffDate
            )
            generatedTransactions.append(contentsOf: generated)
        }

        return generatedTransactions
    }

    /// Generates transactions from a single template up to a cutoff date.
    func generateTransactions(
        from template: Transaction,
        upTo cutoffDate: Date,
        notBefore minimumDate: Date? = nil,
        saveChanges: Bool = true
    ) throws -> [Transaction] {
        guard template.isRecurringTemplate,
              let rule = template.recurrenceRule else {
            return []
        }

        let allGenerated = try fetchGeneratedTransactions(for: template)
        let lastGenerated = allGenerated.max {
            ($0.originalScheduledOccurrenceDate ?? $0.date) <
                ($1.originalScheduledOccurrenceDate ?? $1.date)
        }
        var existingOccurrenceKeys = Set(allGenerated.map {
            occurrenceKey(
                for: $0.originalScheduledOccurrenceDate ?? $0.date,
                recurrenceRule: rule
            )
        })
        let skippedDays = try fetchSkippedDayKeys(forTemplateId: template.id)

        let dueDay = min(max(template.dueDayOfMonth ?? Calendar.current.component(.day, from: template.date), 1), 31)
        let startDate: Date
        if minimumDate == nil {
            startDate = nextGenerationStartDate(
                for: template,
                lastGenerated: lastGenerated,
                dueDay: dueDay,
                recurrenceRule: rule
            )
        } else {
            // Regeneration after a template edit must reconsider every occurrence in the sync
            // window. A confirmed future row can be later than a pending row that was removed;
            // using only the latest generated row would otherwise leave that earlier gap empty.
            startDate = firstOccurrenceDate(
                for: template,
                dueDay: dueDay,
                recurrenceRule: rule
            )
        }

        var generated: [Transaction] = []
        var currentDate = startDate

        if let minimumDate {
            let minimumDay = dayKey(for: minimumDate)
            while dayKey(for: currentDate) < minimumDay {
                currentDate = nextOccurrenceDate(
                    after: currentDate,
                    dueDay: dueDay,
                    recurrenceRule: rule
                )
            }
        }

        while currentDate <= cutoffDate {
            let currentDayKey = dayKey(for: currentDate)
            let currentOccurrenceKey = occurrenceKey(
                for: currentDate,
                recurrenceRule: rule
            )
            let alreadyExists = existingOccurrenceKeys.contains(currentOccurrenceKey)
            let isSkipped = skippedDays.contains(currentDayKey)

            if !alreadyExists && !isSkipped {
                let transaction = Transaction.fromTemplate(
                    template,
                    forDate: currentDate
                )
                context.insert(transaction)
                generated.append(transaction)
                existingOccurrenceKeys.insert(currentOccurrenceKey)
            }

            currentDate = nextOccurrenceDate(
                after: currentDate,
                dueDay: dueDay,
                recurrenceRule: rule
            )
        }

        if !generated.isEmpty && saveChanges {
            try context.save()
        }

        return generated
    }

    private func fetchGeneratedTransactions(for template: Transaction) throws -> [Transaction] {
        let templateId = template.id
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.recurringTemplateId == templateId },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    private func fetchSkippedDayKeys(forTemplateId templateId: UUID) throws -> Set<Date> {
        let descriptor = FetchDescriptor<ScheduledOccurrenceException>(
            predicate: #Predicate<ScheduledOccurrenceException> { $0.templateId == templateId }
        )
        let exceptions = try context.fetch(descriptor)
        return Set(exceptions.map(\.occurrenceDate))
    }

    private func nextGenerationStartDate(
        for template: Transaction,
        lastGenerated: Transaction?,
        dueDay: Int,
        recurrenceRule: RecurrenceRule
    ) -> Date {
        let scheduleStart = firstOccurrenceDate(
            for: template,
            dueDay: dueDay,
            recurrenceRule: recurrenceRule
        )

        guard let lastGenerated else {
            return scheduleStart
        }

        let afterLastGenerated = nextOccurrenceDate(
            after: lastGenerated.originalScheduledOccurrenceDate ?? lastGenerated.date,
            dueDay: dueDay,
            recurrenceRule: recurrenceRule
        )
        return max(scheduleStart, afterLastGenerated)
    }

    private func firstOccurrenceDate(
        for template: Transaction,
        dueDay: Int,
        recurrenceRule: RecurrenceRule
    ) -> Date {
        let scheduleStart: Date
        if recurrenceRule == .monthly {
            let aligned = clampedMonthlyDate(
                inMonthOf: template.date,
                dueDay: dueDay,
                timeSource: template.date
            )
            scheduleStart = aligned < template.date
                ? nextMonthlyDate(after: aligned, dueDay: dueDay)
                : aligned
        } else {
            scheduleStart = template.date
        }
        return scheduleStart
    }

    private func nextOccurrenceDate(
        after date: Date,
        dueDay: Int,
        recurrenceRule: RecurrenceRule
    ) -> Date {
        if recurrenceRule == .monthly {
            return nextMonthlyDate(after: date, dueDay: dueDay)
        }
        return recurrenceRule.nextDate(from: date)
    }

    private func nextMonthlyDate(after date: Date, dueDay: Int, calendar: Calendar = .current) -> Date {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else {
            return date
        }
        return clampedMonthlyDate(inMonthOf: nextMonth, dueDay: dueDay, timeSource: date, calendar: calendar)
    }

    private func clampedMonthlyDate(
        inMonthOf referenceDate: Date,
        dueDay: Int,
        timeSource: Date,
        calendar: Calendar = .current
    ) -> Date {
        // Keep the template's local time-of-day for compatibility with existing schedules and
        // reminder times. Day-based duplicate/skip comparisons are normalized separately.
        let monthComponents = calendar.dateComponents([.year, .month], from: referenceDate)
        guard
            let year = monthComponents.year,
            let month = monthComponents.month,
            let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
            let dayRange = calendar.range(of: .day, in: .month, for: startOfMonth)
        else {
            return referenceDate
        }

        let maxDay = dayRange.count
        let clampedDay = min(max(dueDay, 1), maxDay)
        var timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: timeSource)
        timeComponents.year = year
        timeComponents.month = month
        timeComponents.day = clampedDay

        return calendar.date(from: timeComponents) ?? referenceDate
    }

    /// Deletes pending future occurrences and detaches every preserved occurrence before a
    /// template is converted to a standalone transaction.
    func deleteFutureGeneratedTransactions(for template: Transaction) throws {
        let templateId = template.id
        let now = Date.now
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.recurringTemplateId == templateId }
        )
        let generatedTransactions = try context.fetch(descriptor)
        var changed = false
        for transaction in generatedTransactions {
            if transaction.date > now && transaction.isPendingScheduledOccurrence {
                context.delete(transaction)
            } else {
                transaction.recurringTemplateId = nil
            }
            changed = true
        }

        if changed {
            try context.save()
        }
    }

    private func dayKey(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    private func occurrenceKey(
        for date: Date,
        recurrenceRule: RecurrenceRule,
        calendar: Calendar = .current
    ) -> Date {
        guard recurrenceRule == .monthly else {
            return dayKey(for: date, calendar: calendar)
        }
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components).map {
            calendar.startOfDay(for: $0)
        } ?? dayKey(for: date, calendar: calendar)
    }
}
