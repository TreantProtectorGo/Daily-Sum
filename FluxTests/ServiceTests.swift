import XCTest
import SwiftData
import UserNotifications
@testable import Flux

@MainActor
final class ServiceTests: XCTestCase {
    private final class MockUserNotificationCenter: UserNotificationCenterProtocol {
        var authorizationStatus: UNAuthorizationStatus = .authorized
        private(set) var addedRequests: [UNNotificationRequest] = []
        private(set) var removedIdentifiers: [String] = []
        private(set) var removedAllPending = false

        func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
            authorizationStatus = .authorized
            return true
        }

        func authorizationStatusValue() async -> UNAuthorizationStatus {
            authorizationStatus
        }

        func add(_ request: UNNotificationRequest) async throws {
            addedRequests.append(request)
        }

        func pendingNotificationRequests() async -> [UNNotificationRequest] {
            addedRequests
        }

        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
            removedIdentifiers.append(contentsOf: identifiers)
        }

        func removeAllPendingNotificationRequests() {
            removedAllPending = true
        }
    }

    private final class MockExchangeRateProvider: ExchangeRateProvider {
        let providerName = "mock-provider"
        private(set) var callCount = 0
        private let snapshotDate: Date
        private let rates: [String: Decimal]

        init(snapshotDate: Date, rates: [String: Decimal]) {
            self.snapshotDate = snapshotDate
            self.rates = rates
        }

        func fetchRates(
            baseCurrencyCode: String,
            quoteCurrencyCodes: [String],
            on date: Date?
        ) async throws -> ExchangeRateSnapshot {
            callCount += 1

            let requestedRates = quoteCurrencyCodes.reduce(into: [String: Decimal]()) {
                result,
                quoteCode in
                result[quoteCode] = rates[quoteCode] ?? 1
            }

            return ExchangeRateSnapshot(
                baseCurrencyCode: baseCurrencyCode,
                effectiveDate: date ?? snapshotDate,
                rates: requestedRates,
                provider: providerName
            )
        }
    }

    var container: ModelContainer!
    var context: ModelContext!
    var originalLastSuccessfulRateSyncDate: Date?
    var originalInstallmentPurgeFlag: Any?
    
    override func setUp() async throws {
        container = try ModelContainerConfiguration.createTestContainer()
        context = container.mainContext
        originalLastSuccessfulRateSyncDate = ExchangeRateSyncPreference.lastSuccessfulSyncDate
        ExchangeRateSyncPreference.lastSuccessfulSyncDate = nil
        originalInstallmentPurgeFlag = UserDefaults.standard.object(forKey: "flux.installment.purge.v1.done")
    }
    
    override func tearDown() async throws {
        ExchangeRateSyncPreference.lastSuccessfulSyncDate = originalLastSuccessfulRateSyncDate
        originalLastSuccessfulRateSyncDate = nil
        if let originalInstallmentPurgeFlag {
            UserDefaults.standard.set(originalInstallmentPurgeFlag, forKey: "flux.installment.purge.v1.done")
        } else {
            UserDefaults.standard.removeObject(forKey: "flux.installment.purge.v1.done")
        }
        originalInstallmentPurgeFlag = nil
        container = nil
        context = nil
    }
    
    // MARK: - TransactionService Tests
    
    func testTransactionServiceCRUD() async throws {
        let service = TransactionService(context: context)
        
        // Create account and category first
        let account = Account(name: "Test", type: .cash, currencyCode: "USD", initialBalance: 1000)
        context.insert(account)
        
        let category = Category(nameKey: "Food", icon: "fork.knife", colorHex: "#FF0000", type: .expense, isSystemDefault: false)
        context.insert(category)
        try context.save()
        
        // Create
        let transaction = try service.create(
            amount: 50,
            type: .expense,
            date: .now,
            notes: "Test transaction",
            account: account,
            category: category
        )
        XCTAssertEqual(transaction.amount, 50)
        
        // Read
        let fetched = try service.fetch(byId: transaction.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.notes, "Test transaction")
        
        // Update
        try service.update(transaction, amount: 75, notes: "Updated notes")
        XCTAssertEqual(transaction.amount, 75)
        XCTAssertEqual(transaction.notes, "Updated notes")
        
        // Delete
        try service.delete(transaction)
        let afterDelete = try service.fetch(byId: transaction.id)
        XCTAssertNil(afterDelete)
    }
    
    func testTransactionServiceFiltering() async throws {
        let service = TransactionService(context: context)
        
        let account = Account(name: "Test", type: .cash, currencyCode: "USD")
        context.insert(account)
        
        let category = Category(nameKey: "Food", icon: "fork.knife", colorHex: "#FF0000", type: .expense, isSystemDefault: false)
        context.insert(category)
        try context.save()
        
        // Create multiple transactions
        for i in 0..<5 {
            let _ = try service.create(
                amount: Decimal(i * 10 + 10),
                type: i % 2 == 0 ? .expense : .income,
                date: Calendar.current.date(byAdding: .day, value: -i, to: .now)!,
                account: account,
                category: category
            )
        }
        
        // Test type filtering
        let expenses = try service.fetch(type: .expense)
        XCTAssertEqual(expenses.count, 3)
        
        let income = try service.fetch(type: .income)
        XCTAssertEqual(income.count, 2)
        
        // Test limit
        let limited = try service.fetch(limit: 2)
        XCTAssertEqual(limited.count, 2)
    }

    func testRecurringGeneratorMonthlyDayAnchorsToMonthEnd() throws {
        let account = Account(name: "Bills", type: .cash, currencyCode: "USD")
        context.insert(account)
        try context.save()
        let generator = RecurringTransactionGenerator(context: context)
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        let cutoffDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 2))!

        let template = Transaction(
            amount: 55,
            currencyCode: "USD",
            type: .expense,
            date: startDate,
            notes: "Utility Bill",
            isRecurringTemplate: true,
            recurrenceRule: .monthly,
            schedulePlanType: .recurring,
            dueDayOfMonth: 31,
            reminderLeadDays: 1,
            account: account,
            category: nil
        )
        context.insert(template)
        try context.save()

        let generated = try generator.generateTransactions(from: template, upTo: cutoffDate)
        let days = generated.map {
            calendar.component(.day, from: $0.date)
        }

        XCTAssertEqual(days, [31, 28, 31])
    }

    func testGeneratorSkipsOccurrenceExceptions() throws {
        let account = Account(name: "Credit Card", type: .cash, currencyCode: "USD")
        context.insert(account)
        try context.save()

        let generator = RecurringTransactionGenerator(context: context)
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let cutoffDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!

        let template = Transaction(
            amount: 120,
            currencyCode: "USD",
            type: .expense,
            date: startDate,
            notes: "Laptop Plan",
            isRecurringTemplate: true,
            recurrenceRule: .monthly,
            schedulePlanType: .recurring,
            dueDayOfMonth: 15,
            reminderLeadDays: 1,
            account: account,
            category: nil
        )
        context.insert(template)
        let skippedDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 15))!
        let skippedException = ScheduledOccurrenceException(
            templateId: template.id,
            occurrenceDate: calendar.startOfDay(for: skippedDate)
        )
        context.insert(skippedException)
        try context.save()

        let generated = try generator.generateTransactions(from: template, upTo: cutoffDate)
        XCTAssertFalse(generated.contains(where: { calendar.isDate($0.date, inSameDayAs: skippedDate) }))
    }

    func testGeneratorDefaultLookAheadIncludesAtLeastOneFutureMonthlyOccurrence() throws {
        let account = Account(name: "Monthly", type: .cash, currencyCode: "USD")
        context.insert(account)
        try context.save()

        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.date(from: DateComponents(
            year: 2026,
            month: 1,
            day: 1,
            hour: 12
        ))!
        let cutoffDate = calendar.date(
            byAdding: .day,
            value: RecurringTransactionGenerator.defaultLookAheadDays,
            to: startDate
        )!

        let template = Transaction(
            amount: 90,
            currencyCode: "USD",
            type: .expense,
            date: startDate,
            notes: "Monthly",
            isRecurringTemplate: true,
            recurrenceRule: .monthly,
            schedulePlanType: .recurring,
            dueDayOfMonth: 1,
            reminderLeadDays: 1,
            account: account,
            category: nil
        )
        context.insert(template)
        try context.save()

        let generator = RecurringTransactionGenerator(context: context)
        let generated = try generator.generateTransactions(from: template, upTo: cutoffDate)

        XCTAssertTrue(generated.contains(where: { $0.date > startDate }))
    }

    func testCreateScheduledTemplateSmoke() async throws {
        let service = TransactionService(context: context)
        let account = Account(name: "Bills", type: .cash, currencyCode: "USD")
        context.insert(account)
        try context.save()

        let template = try service.createScheduled(
            amount: 120,
            startDate: .now,
            dueDayOfMonth: 15,
            reminderLeadDays: 1,
            account: account,
            category: nil,
            notes: "Smoke",
            planType: .recurring
        )

        XCTAssertTrue(template.isRecurringTemplate)
        XCTAssertEqual(template.type, .expense)
        XCTAssertEqual(template.schedulePlanType, .recurring)
    }

    func testUpdateScheduledTemplateRemovesFutureGeneratedOnly() async throws {
        let service = TransactionService(context: context)
        let account = Account(name: "Bills", type: .cash, currencyCode: "USD")
        context.insert(account)
        try context.save()

        let now = Date.now
        let template = try service.createScheduled(
            amount: 90,
            startDate: Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now,
            dueDayOfMonth: 20,
            reminderLeadDays: 1,
            account: account,
            category: nil,
            notes: "Plan",
            planType: .recurring
        )

        let pastGeneratedId: UUID = {
            let transaction = Transaction.fromTemplate(
                template,
                forDate: Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now
            )
            let id = transaction.id
            context.insert(transaction)
            return id
        }()
        _ = {
            let transaction = Transaction.fromTemplate(
                template,
                forDate: Calendar.current.date(byAdding: .day, value: 5, to: now) ?? now
            )
            context.insert(transaction)
        }()
        _ = {
            let transaction = Transaction.fromTemplate(
                template,
                forDate: Calendar.current.date(byAdding: .day, value: 20, to: now) ?? now
            )
            context.insert(transaction)
        }()
        try context.save()

        try service.updateScheduledTemplate(
            template,
            amount: 120,
            startDate: now,
            dueDayOfMonth: 25,
            reminderLeadDays: 3,
            account: account,
            notes: "Updated plan",
            category: nil,
            planType: .recurring
        )

        let templateId = template.id
        let remainingGenerated = try context.fetch(
            FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { $0.recurringTemplateId == templateId }
            )
        )

        XCTAssertEqual(remainingGenerated.count, 1)
        XCTAssertEqual(remainingGenerated.first?.id, pastGeneratedId)
        XCTAssertEqual(template.amount, 120)
        XCTAssertEqual(template.dueDayOfMonth, 25)
        XCTAssertEqual(template.reminderLeadDays, 3)
        XCTAssertEqual(template.notes, "Updated plan")
    }

    func testDeleteScheduledTemplateRemovesFutureGeneratedKeepsPastGenerated() async throws {
        let service = TransactionService(context: context)
        let account = Account(name: "Loan", type: .cash, currencyCode: "USD")
        context.insert(account)
        try context.save()

        let now = Date.now
        let template = try service.createScheduled(
            amount: 150,
            startDate: Calendar.current.date(byAdding: .month, value: -2, to: now) ?? now,
            dueDayOfMonth: 10,
            reminderLeadDays: 1,
            account: account,
            category: nil,
            notes: "Recurring plan",
            planType: .recurring
        )
        let templateId = template.id

        let pastGeneratedId: UUID = {
            let transaction = Transaction.fromTemplate(
                template,
                forDate: Calendar.current.date(byAdding: .day, value: -15, to: now) ?? now
            )
            let id = transaction.id
            context.insert(transaction)
            return id
        }()
        let futureGeneratedId: UUID = {
            let transaction = Transaction.fromTemplate(
                template,
                forDate: Calendar.current.date(byAdding: .day, value: 15, to: now) ?? now
            )
            let id = transaction.id
            context.insert(transaction)
            return id
        }()
        try context.save()

        try service.delete(template)

        let deletedTemplate = try service.fetch(byId: templateId)
        XCTAssertNil(deletedTemplate)

        let remainingPast = try service.fetch(byId: pastGeneratedId)
        XCTAssertNotNil(remainingPast)

        let removedFuture = try service.fetch(byId: futureGeneratedId)
        XCTAssertNil(removedFuture)
    }

    func testHandleFutureGeneratedDeletionSkipCreatesExceptionAndRemovesOccurrence() async throws {
        let service = TransactionService(context: context)
        let account = Account(name: "Bills", type: .cash, currencyCode: "USD")
        context.insert(account)
        try context.save()

        let dueDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        let template = try service.createScheduled(
            amount: 88,
            startDate: .now,
            dueDayOfMonth: Calendar.current.component(.day, from: dueDate),
            reminderLeadDays: 1,
            account: account,
            category: nil,
            notes: "Gym",
            planType: .recurring
        )

        let generated = Transaction.fromTemplate(template, forDate: dueDate)
        context.insert(generated)
        try context.save()

        try await service.handleFutureGeneratedDeletion(generated, action: .skipOccurrence)

        let removed = try service.fetch(byId: generated.id)
        XCTAssertNil(removed)

        let key = Calendar.current.startOfDay(for: dueDate)
        let templateId = template.id
        let exceptions = try context.fetch(
            FetchDescriptor<ScheduledOccurrenceException>(
                predicate: #Predicate<ScheduledOccurrenceException> {
                    $0.templateId == templateId && $0.occurrenceDate == key
                }
            )
        )
        XCTAssertEqual(exceptions.count, 1)
    }

    func testHandleFutureGeneratedDeletionStopRemovesTemplateAndFutureKeepsPast() async throws {
        let service = TransactionService(context: context)
        let account = Account(name: "Bills", type: .cash, currencyCode: "USD")
        context.insert(account)
        try context.save()

        let now = Date.now
        let template = try service.createScheduled(
            amount: 120,
            startDate: Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now,
            dueDayOfMonth: 12,
            reminderLeadDays: 1,
            account: account,
            category: nil,
            notes: "Plan",
            planType: .recurring
        )

        let pastGenerated = Transaction.fromTemplate(
            template,
            forDate: Calendar.current.date(byAdding: .day, value: -5, to: now) ?? now
        )
        context.insert(pastGenerated)

        let futureGenerated = Transaction.fromTemplate(
            template,
            forDate: Calendar.current.date(byAdding: .day, value: 5, to: now) ?? now
        )
        context.insert(futureGenerated)
        try context.save()

        try await service.handleFutureGeneratedDeletion(futureGenerated, action: .stopPlan)

        XCTAssertNil(try service.fetch(byId: template.id))
        XCTAssertNotNil(try service.fetch(byId: pastGenerated.id))
        XCTAssertNil(try service.fetch(byId: futureGenerated.id))
    }

    func testHandleFutureGeneratedDeletionStopFromPastGeneratedRemovesPlanAndSelectedOccurrence() async throws {
        let service = TransactionService(context: context)
        let account = Account(name: "Utilities", type: .cash, currencyCode: "USD")
        context.insert(account)
        try context.save()

        let now = Date.now
        let template = try service.createScheduled(
            amount: 66,
            startDate: Calendar.current.date(byAdding: .month, value: -2, to: now) ?? now,
            dueDayOfMonth: 7,
            reminderLeadDays: 1,
            account: account,
            category: nil,
            notes: "Past generated selected",
            planType: .recurring
        )

        let selectedPast = Transaction.fromTemplate(
            template,
            forDate: Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now
        )
        context.insert(selectedPast)

        let futureGenerated = Transaction.fromTemplate(
            template,
            forDate: Calendar.current.date(byAdding: .day, value: 6, to: now) ?? now
        )
        context.insert(futureGenerated)
        try context.save()

        try await service.handleFutureGeneratedDeletion(selectedPast, action: .stopPlan)

        XCTAssertNil(try service.fetch(byId: template.id))
        XCTAssertNil(try service.fetch(byId: selectedPast.id))
        XCTAssertNil(try service.fetch(byId: futureGenerated.id))
    }

    func testPurgeAllInstallmentDataIfNeededRemovesLegacyInstallmentTransactions() async throws {
        let service = TransactionService(context: context)
        let account = Account(name: "Legacy", type: .cash, currencyCode: "USD")
        context.insert(account)

        let template = Transaction(
            amount: 77,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            isRecurringTemplate: true,
            recurrenceRule: .monthly,
            dueDayOfMonth: 10,
            reminderLeadDays: 1,
            installmentTotalCount: 3,
            account: account
        )
        template.schedulePlanTypeRawValue = "installment"
        context.insert(template)

        let generated = Transaction(
            amount: 77,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now,
            schedulePlanType: nil,
            installmentSequenceNumber: 1,
            recurringTemplateId: template.id,
            account: account
        )
        generated.schedulePlanTypeRawValue = "installment"
        context.insert(generated)
        try context.save()

        UserDefaults.standard.removeObject(forKey: "flux.installment.purge.v1.done")
        try await service.purgeAllInstallmentDataIfNeeded()

        XCTAssertNil(try service.fetch(byId: template.id))
        XCTAssertNil(try service.fetch(byId: generated.id))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "flux.installment.purge.v1.done"))
    }

    func testReminderSchedulerUsesDeterministicIdentifiers() async throws {
        let account = Account(name: "Reminder Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let templateDate = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 2, day: 28)
        )!

        let template = Transaction(
            amount: 45,
            currencyCode: "USD",
            type: .expense,
            date: templateDate,
            notes: "Subscription",
            isRecurringTemplate: true,
            recurrenceRule: .monthly,
            schedulePlanType: .recurring,
            dueDayOfMonth: 28,
            reminderLeadDays: 3,
            account: account,
            category: nil
        )
        context.insert(template)
        let generated = Transaction.fromTemplate(template, forDate: templateDate)
        context.insert(generated)
        try context.save()

        let center = MockUserNotificationCenter()
        let scheduler = TransactionReminderScheduler(
            context: context,
            notificationCenter: center
        )
        try await scheduler.syncReminders(for: [generated])

        let expectedIdentifier = TransactionReminderScheduler.identifier(
            templateId: template.id,
            dueDate: templateDate
        )

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(center.addedRequests.first?.identifier, expectedIdentifier)
    }

    func testReminderSchedulerRemovesTemplateNotificationsByPrefix() async throws {
        let templateID = UUID()
        let dueDate = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 3, day: 15)
        )!
        let center = MockUserNotificationCenter()
        let identifier = TransactionReminderScheduler.identifier(
            templateId: templateID,
            dueDate: dueDate
        )
        let content = UNMutableNotificationContent()
        content.title = "Title"
        content.body = "Body"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        try await center.add(request)

        let scheduler = TransactionReminderScheduler(
            context: context,
            notificationCenter: center
        )

        await scheduler.removeReminders(forTemplateId: templateID)

        XCTAssertEqual(center.removedIdentifiers, [identifier])
    }

    func testBudgetAlertSchedulerSchedulesWarningNotificationOnce() async throws {
        let category = Category(
            nameKey: "Food",
            icon: "fork.knife",
            colorHex: "#FF6600",
            type: .expense,
            isSystemDefault: false
        )
        context.insert(category)

        let account = Account(name: "Wallet", type: .cash, currencyCode: "USD", initialBalance: 1000)
        context.insert(account)

        let budget = Budget(
            limitAmount: 100,
            currencyCode: "USD",
            period: .monthly,
            alertThreshold: 0.8,
            category: category
        )
        context.insert(budget)

        let date = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 3, day: 25, hour: 10)
        )!
        context.insert(Transaction(
            amount: 80,
            currencyCode: "USD",
            type: .expense,
            date: date,
            account: account,
            category: category
        ))
        try context.save()

        let center = MockUserNotificationCenter()
        let scheduler = BudgetAlertScheduler(
            context: context,
            notificationCenter: center,
            calendar: Calendar(identifier: .gregorian)
        )

        try await scheduler.syncAlerts(for: date)
        try await scheduler.syncAlerts(for: date)

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(
            center.addedRequests.first?.identifier,
            BudgetAlertScheduler.identifier(
                budgetId: budget.id,
                periodStart: budget.period.dateRange(containing: date, calendar: Calendar(identifier: .gregorian)).start,
                stage: .warning
            )
        )
        let trigger = try XCTUnwrap(center.addedRequests.first?.trigger as? UNTimeIntervalNotificationTrigger)
        XCTAssertEqual(trigger.timeInterval, 1, accuracy: 0.1)
        XCTAssertFalse(trigger.repeats)
    }

    func testBudgetAlertSchedulerSchedulesExceededNotification() async throws {
        let category = Category(
            nameKey: "Travel",
            icon: "airplane",
            colorHex: "#00AA88",
            type: .expense,
            isSystemDefault: false
        )
        context.insert(category)

        let account = Account(name: "Card", type: .cash, currencyCode: "USD", initialBalance: 1000)
        context.insert(account)

        let budget = Budget(
            limitAmount: 100,
            currencyCode: "USD",
            period: .monthly,
            alertThreshold: 0.8,
            category: category
        )
        context.insert(budget)

        let date = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 3, day: 25, hour: 10)
        )!
        context.insert(Transaction(
            amount: 120,
            currencyCode: "USD",
            type: .expense,
            date: date,
            account: account,
            category: category
        ))
        try context.save()

        let center = MockUserNotificationCenter()
        let scheduler = BudgetAlertScheduler(
            context: context,
            notificationCenter: center,
            calendar: Calendar(identifier: .gregorian)
        )

        try await scheduler.syncAlerts(for: date)

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(
            center.addedRequests.first?.identifier,
            BudgetAlertScheduler.identifier(
                budgetId: budget.id,
                periodStart: budget.period.dateRange(containing: date, calendar: Calendar(identifier: .gregorian)).start,
                stage: .exceeded
            )
        )
    }

    func testForegroundNotificationPresentationDelegateUsesBannerListAndSound() {
        let options = ForegroundNotificationPresentationDelegate.presentationOptions

        XCTAssertTrue(options.contains(.banner))
        XCTAssertTrue(options.contains(.list))
        XCTAssertTrue(options.contains(.sound))
    }

    func testSettingsViewModelReportsAllNotificationsToggleStateFromAuthorizationStatus() {
        let viewModel = SettingsViewModel(modelContext: context)

        viewModel.notificationAuthorizationStatus = .authorized
        XCTAssertTrue(viewModel.allNotificationsEnabled)

        viewModel.notificationAuthorizationStatus = .notDetermined
        XCTAssertFalse(viewModel.allNotificationsEnabled)
    }

    func testSettingsViewModelTurningOnNotificationsWhenDeniedOpensSystemSettings() async {
        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.notificationAuthorizationStatus = .denied

        let action = await viewModel.setAllNotificationsEnabled(true)

        XCTAssertEqual(action, .openSystemSettings)
    }

    func testNotificationAuthorizationStartupPolicyOnlyRequestsWhenStatusIsNotDetermined() {
        XCTAssertTrue(NotificationAuthorizationStartupPolicy.shouldRequestOnAppLaunch(for: .notDetermined))
        XCTAssertFalse(NotificationAuthorizationStartupPolicy.shouldRequestOnAppLaunch(for: .authorized))
        XCTAssertFalse(NotificationAuthorizationStartupPolicy.shouldRequestOnAppLaunch(for: .denied))
    }

    func testBudgetAllCategoriesPresentationUsesBudgetPickerPlaceholderIcon() {
        XCTAssertEqual(
            BudgetAllCategoriesPresentation.icon,
            CategoryPickerMode.budgetExpense.placeholderIcon
        )
    }

    // MARK: - AccountService Tests
    
    func testAccountServiceTotalBalance() async throws {
        let service = AccountService(context: context)
        
        // Create accounts
        let _ = try service.create(
            name: "Checking",
            type: .bank,
            currencyCode: "USD",
            initialBalance: 1000
        )
        
        let _ = try service.create(
            name: "Savings",
            type: .bank,
            currencyCode: "USD",
            initialBalance: 5000
        )
        
        let total = try service.totalBalance(convertToBase: false)
        XCTAssertEqual(total, 6000)
    }
    
    func testAccountCurrencyUpdatePropagatesToTransactions() async throws {
        let accountService = AccountService(context: context)
        let transactionService = TransactionService(context: context)
        
        let account = try accountService.create(
            name: "Wallet",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 100
        )
        
        let transaction = try transactionService.create(
            amount: 25,
            type: .expense,
            account: account,
            category: nil
        )
        
        XCTAssertEqual(transaction.currencyCode, "USD")
        
        try accountService.update(account, currencyCode: "TWD")
        
        XCTAssertEqual(account.currencyCode, "TWD")
        XCTAssertEqual(transaction.currencyCode, "TWD")
    }
    
    func testAccountServiceUpdateInitialBalance() async throws {
        let accountService = AccountService(context: context)
        
        let account = try accountService.create(
            name: "Wallet",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 100
        )
        
        XCTAssertEqual(account.initialBalance, 100)
        
        try accountService.update(account, initialBalance: 250)
        
        XCTAssertEqual(account.initialBalance, 250)
    }
    
    func testAccountServiceAdjustCurrentBalanceCreatesDeltaTransaction() async throws {
        let accountService = AccountService(context: context)
        let transactionService = TransactionService(context: context)
        
        let account = try accountService.create(
            name: "Wallet",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 100
        )
        
        _ = try transactionService.create(
            amount: 40,
            type: .expense,
            account: account,
            category: nil
        )
        
        XCTAssertEqual(account.currentBalance, 60)
        
        let adjustment = try accountService.adjustCurrentBalance(
            account,
            to: 50,
            note: "Manual balance adjustment"
        )
        
        XCTAssertNotNil(adjustment)
        XCTAssertEqual(adjustment?.type, .expense)
        XCTAssertEqual(adjustment?.amount, 10)
        XCTAssertEqual(adjustment?.notes, "Manual balance adjustment")
        XCTAssertEqual(account.currentBalance, 50)
    }
    
    // MARK: - CategoryService Tests
    
    func testCategoryServiceHierarchy() async throws {
        let service = CategoryService(context: context)
        
        let parent = try service.create(
            name: "Food",
            icon: "fork.knife",
            colorHex: "#FF0000",
            type: .expense
        )
        
        let _ = try service.create(
            name: "Restaurants",
            icon: "cup.and.saucer",
            colorHex: "#FF5555",
            type: .expense,
            parentCategory: parent
        )
        
        let topLevel = try service.fetchTopLevel(type: .expense)
        XCTAssertEqual(topLevel.count, 1)
        
        let subcategories = try service.fetchSubcategories(of: parent)
        XCTAssertEqual(subcategories.count, 1)
    }
    
    func testCategoryServiceTypeMismatch() async throws {
        let service = CategoryService(context: context)
        
        let expenseCategory = try service.create(
            name: "Food",
            icon: "fork.knife",
            colorHex: "#FF0000",
            type: .expense
        )
        
        // Should throw error when trying to add income subcategory to expense parent
        do {
            let _ = try service.create(
                name: "Salary",
                icon: "banknote",
                colorHex: "#00FF00",
                type: .income,
                parentCategory: expenseCategory
            )
            XCTFail("Should have thrown typeMismatch error")
        } catch let error as CategoryService.CategoryError {
            XCTAssertEqual(error, .typeMismatch)
        }
    }
    
    // MARK: - BudgetService Tests
    
    func testBudgetServiceTriggersWarningAtEightyPercentOncePerPeriod() async throws {
        let categoryService = CategoryService(context: context)
        let transactionService = TransactionService(context: context)
        let budgetService = BudgetService(context: context)
        let accountService = AccountService(context: context)
        
        let category = try categoryService.create(
            name: "Shopping",
            icon: "bag",
            colorHex: "#FF0000",
            type: .expense
        )
        
        let account = try accountService.create(
            name: "Test",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 10000
        )
        
        let budget = try budgetService.create(
            category: category,
            limitAmount: 100,
            currencyCode: "USD",
            alertThreshold: 0.8
        )
        
        let _ = try transactionService.create(
            amount: 80,
            type: .expense,
            account: account,
            category: category
        )
        
        let triggered = try budgetService.triggeredAlerts()
        XCTAssertEqual(triggered.count, 1)
        XCTAssertEqual(triggered.first?.budget.id, budget.id)
        XCTAssertEqual(triggered.first?.stage, .warning)

        let secondTriggered = try budgetService.triggeredAlerts()
        XCTAssertTrue(secondTriggered.isEmpty)
    }

    func testBudgetServiceIgnoresLegacyAlertsEnabledFlag() async throws {
        let categoryService = CategoryService(context: context)
        let transactionService = TransactionService(context: context)
        let budgetService = BudgetService(context: context)
        let accountService = AccountService(context: context)

        let category = try categoryService.create(
            name: "Food",
            icon: "fork.knife",
            colorHex: "#FF6600",
            type: .expense
        )

        let account = try accountService.create(
            name: "Cash",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 10000
        )

        let budget = try budgetService.create(
            category: category,
            limitAmount: 100,
            currencyCode: "USD",
            alertThreshold: 0.8,
            alertsEnabled: false
        )

        let _ = try transactionService.create(
            amount: 80,
            type: .expense,
            account: account,
            category: category
        )

        let triggered = try budgetService.triggeredAlerts()
        XCTAssertEqual(triggered.count, 1)
        XCTAssertEqual(triggered.first?.budget.id, budget.id)
        XCTAssertEqual(triggered.first?.stage, .warning)
    }

    func testBudgetServiceTriggersExceededAtOneHundredPercentOncePerPeriod() async throws {
        let categoryService = CategoryService(context: context)
        let transactionService = TransactionService(context: context)
        let budgetService = BudgetService(context: context)
        let accountService = AccountService(context: context)

        let category = try categoryService.create(
            name: "Bills",
            icon: "doc.text",
            colorHex: "#3366FF",
            type: .expense
        )

        let account = try accountService.create(
            name: "Checking",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 10000
        )

        let budget = try budgetService.create(
            category: category,
            limitAmount: 100,
            currencyCode: "USD",
            alertThreshold: 0.8
        )

        let _ = try transactionService.create(
            amount: 120,
            type: .expense,
            account: account,
            category: category
        )

        let triggered = try budgetService.triggeredAlerts()
        XCTAssertEqual(triggered.count, 1)
        XCTAssertEqual(triggered.first?.budget.id, budget.id)
        XCTAssertEqual(triggered.first?.stage, .exceeded)
        XCTAssertTrue(budget.hasSentWarningAlertInTrackedPeriod)
        XCTAssertTrue(budget.hasSentExceededAlertInTrackedPeriod)

        let secondTriggered = try budgetService.triggeredAlerts()
        XCTAssertTrue(secondTriggered.isEmpty)
    }

    func testBudgetServiceDoesNotRetriggerWarningAfterUsageDropsInSamePeriod() async throws {
        let categoryService = CategoryService(context: context)
        let transactionService = TransactionService(context: context)
        let budgetService = BudgetService(context: context)
        let accountService = AccountService(context: context)

        let category = try categoryService.create(
            name: "Food",
            icon: "fork.knife",
            colorHex: "#FF6600",
            type: .expense
        )

        let account = try accountService.create(
            name: "Cash",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 10000
        )

        _ = try budgetService.create(
            category: category,
            limitAmount: 100,
            currencyCode: "USD",
            alertThreshold: 0.8
        )

        let expense = try transactionService.create(
            amount: 80,
            type: .expense,
            account: account,
            category: category
        )

        XCTAssertEqual(try budgetService.triggeredAlerts().first?.stage, .warning)

        try transactionService.delete(expense)

        let _ = try transactionService.create(
            amount: 80,
            type: .expense,
            account: account,
            category: category
        )

        let triggeredAgain = try budgetService.triggeredAlerts()
        XCTAssertTrue(triggeredAgain.isEmpty)
    }

    func testBudgetServiceResetsProgressiveAlertsForNewPeriod() async throws {
        let categoryService = CategoryService(context: context)
        let transactionService = TransactionService(context: context)
        let budgetService = BudgetService(context: context)
        let accountService = AccountService(context: context)
        let calendar = Calendar(identifier: .gregorian)

        let category = try categoryService.create(
            name: "Travel",
            icon: "airplane",
            colorHex: "#00AA88",
            type: .expense
        )

        let account = try accountService.create(
            name: "Debit",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 10000
        )

        _ = try budgetService.create(
            category: category,
            limitAmount: 100,
            currencyCode: "USD",
            period: .monthly,
            alertThreshold: 0.8
        )

        let januaryDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let februaryDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 15))!

        let januaryExpense = try transactionService.create(
            amount: 80,
            type: .expense,
            date: januaryDate,
            account: account,
            category: category
        )

        XCTAssertEqual(
            try budgetService.triggeredAlerts(for: januaryDate).first?.stage,
            .warning
        )

        try transactionService.delete(januaryExpense)

        let _ = try transactionService.create(
            amount: 80,
            type: .expense,
            date: februaryDate,
            account: account,
            category: category
        )

        XCTAssertEqual(
            try budgetService.triggeredAlerts(for: februaryDate).first?.stage,
            .warning
        )
    }
    
    func testBudgetServiceRejectsDuplicateCategoryAndPeriod() async throws {
        let categoryService = CategoryService(context: context)
        let budgetService = BudgetService(context: context)
        
        let category = try categoryService.create(
            name: "Transport",
            icon: "car",
            colorHex: "#2E86DE",
            type: .expense
        )
        
        _ = try budgetService.create(
            category: category,
            limitAmount: 200,
            currencyCode: "USD",
            period: .monthly
        )
        
        do {
            _ = try budgetService.create(
                category: category,
                limitAmount: 300,
                currencyCode: "USD",
                period: .monthly
            )
            XCTFail("Expected duplicate budget validation to fail")
        } catch let error as BudgetService.BudgetError {
            XCTAssertEqual(error, .duplicateBudget)
        }
    }

    func testBudgetServiceRejectsDuplicateAllCategoriesAndPeriod() async throws {
        let budgetService = BudgetService(context: context)

        let allCategoriesBudget = try budgetService.create(
            category: nil,
            limitAmount: 500,
            currencyCode: "USD",
            period: .monthly
        )
        XCTAssertNil(allCategoriesBudget.category)

        do {
            _ = try budgetService.create(
                category: nil,
                limitAmount: 600,
                currencyCode: "USD",
                period: .monthly
            )
            XCTFail("Expected duplicate all-categories budget validation to fail")
        } catch let error as BudgetService.BudgetError {
            XCTAssertEqual(error, .duplicateBudget)
        }
    }

    func testBudgetServiceUpdateCanClearCategoryToAllCategories() async throws {
        let categoryService = CategoryService(context: context)
        let budgetService = BudgetService(context: context)

        let category = try categoryService.create(
            name: "Food",
            icon: "fork.knife",
            colorHex: "#FF0000",
            type: .expense
        )

        let budget = try budgetService.create(
            category: category,
            limitAmount: 300,
            currencyCode: "USD",
            period: .monthly
        )
        XCTAssertNotNil(budget.category)

        try budgetService.update(
            budget,
            category: nil,
            shouldUpdateCategory: true
        )

        XCTAssertNil(budget.category)
    }

    func testBudgetListViewModelReloadRefreshesPerBudgetStatus() async throws {
        let currencyCode = UserCurrencyPreference.resolvedCurrencyCode
        let budgetService = BudgetService(context: context)
        let viewModel = BudgetListViewModel(modelContext: context)

        let budget = try budgetService.create(
            category: nil,
            limitAmount: 50,
            currencyCode: currencyCode,
            period: .monthly
        )

        await viewModel.loadBudgets()
        XCTAssertEqual(viewModel.status(for: budget)?.spent, Decimal.zero)
        XCTAssertEqual(viewModel.totalSpent, Decimal.zero)

        let transaction = Transaction(
            amount: 30,
            currencyCode: currencyCode,
            type: .expense,
            date: .now
        )
        context.insert(transaction)
        try context.save()

        await viewModel.loadBudgets()

        XCTAssertEqual(viewModel.status(for: budget)?.spent, Decimal(30))
        XCTAssertEqual(viewModel.status(for: budget)?.remaining, Decimal(20))
        XCTAssertEqual(viewModel.totalSpent, Decimal(30))
        XCTAssertEqual(viewModel.budgetsNearLimit, 0)
    }

    // MARK: - ExchangeRateRefreshScheduler Tests

    func testExchangeRateRefreshSchedulerRefreshesWhenStale() async throws {
        let now = Date(timeIntervalSince1970: 1_739_571_200) // 2025-02-15 UTC
        let staleDate = now.addingTimeInterval(-(60 * 60 * 25))
        ExchangeRateSyncPreference.lastSuccessfulSyncDate = staleDate

        let provider = MockExchangeRateProvider(
            snapshotDate: now,
            rates: ["TWD": 32]
        )
        let scheduler = ExchangeRateRefreshScheduler(
            refreshInterval: 60 * 60 * 24,
            provider: provider
        )

        let refreshed = try await scheduler.refreshLatestRatesIfNeeded(
            context: context,
            baseCurrencyCode: "USD",
            now: now
        )

        XCTAssertTrue(refreshed)
        XCTAssertEqual(provider.callCount, 1)
        XCTAssertEqual(ExchangeRateSyncPreference.lastSuccessfulSyncDate, now)

        var descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate<ExchangeRate> {
                $0.baseCurrencyCode == "USD" && $0.quoteCurrencyCode == "TWD"
            }
        )
        descriptor.fetchLimit = 1
        XCTAssertEqual(try context.fetch(descriptor).first?.rate, 32)
    }

    func testExchangeRateRefreshSchedulerSkipsWhenRecent() async throws {
        let now = Date(timeIntervalSince1970: 1_739_571_200) // 2025-02-15 UTC
        let recentDate = now.addingTimeInterval(-(60 * 60))
        ExchangeRateSyncPreference.lastSuccessfulSyncDate = recentDate

        let provider = MockExchangeRateProvider(
            snapshotDate: now,
            rates: ["TWD": 32]
        )
        let scheduler = ExchangeRateRefreshScheduler(
            refreshInterval: 60 * 60 * 24,
            provider: provider
        )

        let refreshed = try await scheduler.refreshLatestRatesIfNeeded(
            context: context,
            baseCurrencyCode: "USD",
            now: now
        )

        XCTAssertFalse(refreshed)
        XCTAssertEqual(provider.callCount, 0)
        XCTAssertEqual(ExchangeRateSyncPreference.lastSuccessfulSyncDate, recentDate)
    }
}
