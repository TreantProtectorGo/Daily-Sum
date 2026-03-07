import SwiftUI
import SwiftData

private enum ScheduleFormMode: String, CaseIterable, Identifiable {
    case oneTime
    case recurring

    var id: String { rawValue }
}

// MARK: - Transaction Entry Sheet

/// Sheet for adding or editing a transaction
struct TransactionEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    private let existingTransaction: Transaction?
    private let onSave: () -> Void
    
    // Form state
    @State private var transactionType: TransactionType = .expense
    @State private var amount: Decimal = 0
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var scheduleMode: ScheduleFormMode = .oneTime
    @State private var dueDayOfMonth: Int = Calendar.current.component(.day, from: .now)
    @State private var reminderLeadDays: Int = TransactionReminderScheduler.defaultReminderLeadDays
    @State private var sheetOpenedAt: Date?
    @State private var hasLoggedFirstAmountInput = false
    @State private var amountFieldFocusedAt: Date?
    @State private var selectedDetent: PresentationDetent = .medium
    
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @Query private var accounts: [Account]
    
    init(transaction: Transaction? = nil, onSave: @escaping () -> Void) {
        self.existingTransaction = transaction
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Amount
                amountSection
                
                // Grouped details
                detailsSection

                if transactionType == .expense {
                    scheduleSection
                }
                
                // Notes
                notesSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(AppLocalization.string("action.cancel", defaultValue: "Cancel"))
                }
                
                ToolbarItem(placement: .principal) {
                    transactionTypePicker
                        .frame(width: 220)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveTransaction()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(AppLocalization.string("action.save", defaultValue: "Save"))
                    .disabled(!isFormValid || isSaving)
                }
            }
            .onAppear {
                let mode = existingTransaction == nil ? "create" : "edit"
                sheetOpenedAt = PerformanceLogger.start(
                    "TransactionEntrySheet.Open",
                    metadata: "mode=\(mode)"
                )

                if existingTransaction != nil {
                    loadExistingTransaction()
                } else {
                    resetFormForNewTransaction()
                    applyPreferredAccountIfNeeded()
                }

                PerformanceLogger.mark(
                    "TransactionEntrySheet.Open.Ready",
                    metadata: "accounts=\(accounts.count)"
                )
            }
            .onChange(of: accounts.count) { _, _ in
                applyPreferredAccountIfNeeded()
            }
            .alert(
                AppLocalization.string("error.title", defaultValue: "Error"),
                isPresented: $showError
            ) {
                Button(AppLocalization.string("action.ok", defaultValue: "OK")) { }
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
    }
    
    // MARK: - Form Sections
    
    private var transactionTypePicker: some View {
        Picker(AppLocalization.string("transaction.type", defaultValue: "Type"), selection: $transactionType) {
            ForEach(TransactionType.allCases, id: \.self) { type in
                Text(type.localizedName)
                    .tag(type)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("transaction.type.mode")
        .onChange(of: transactionType) { _, _ in
            // Reset category when type changes
            selectedCategory = nil
            if transactionType != .expense {
                scheduleMode = .oneTime
            }
        }
    }
    
    private var amountSection: some View {
        Section(AppLocalization.string("transaction.amount", defaultValue: "Amount")) {
            AmountInputView(
                amount: $amount,
                currencyCode: selectedAccount?.currencyCode ?? UserCurrencyPreference.resolvedCurrencyCode,
                autoFocus: existingTransaction == nil,
                onFirstUserInput: handleFirstAmountInput,
                onFocusChanged: handleAmountFieldFocusChanged
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
    
    private var detailsSection: some View {
        Section {
            CategoryPickerView(
                selectedCategory: $selectedCategory,
                transactionType: transactionType
            )

            if accounts.isEmpty {
                Text(AppLocalization.string("transaction.noAccounts", defaultValue: "No accounts available. Please create an account first."))
                    .foregroundStyle(.secondary)
            } else {
                Picker(AppLocalization.string("transaction.account", defaultValue: "Account"), selection: $selectedAccount) {
                    Text(AppLocalization.string("transaction.selectAccount", defaultValue: "Select Account"))
                        .tag(nil as Account?)
                    
                    ForEach(accounts) { account in
                        HStack {
                            Image(systemName: account.type.icon)
                                .foregroundStyle(account.type.color)
                            Text(account.name)
                        }
                        .tag(account as Account?)
                    }
                }
            }

            DatePicker(
                AppLocalization.string("transaction.date", defaultValue: "Date"),
                selection: $date,
                displayedComponents: .date
            )
            .onChange(of: date) { _, newValue in
                dueDayOfMonth = Calendar.current.component(.day, from: newValue)
            }
        } header: {
            Text(AppLocalization.string("transaction.details", defaultValue: "Details"))
        }
    }

    private var scheduleSection: some View {
        Section {
            Picker(
                AppLocalization.string("transaction.schedule.mode", defaultValue: "Schedule"),
                selection: $scheduleMode
            ) {
                Text(AppLocalization.string("transaction.schedule.oneTime", defaultValue: "One-time"))
                    .tag(ScheduleFormMode.oneTime)
                Text(AppLocalization.string("transaction.schedule.recurring", defaultValue: "Recurring"))
                    .tag(ScheduleFormMode.recurring)
            }
            .accessibilityIdentifier("transaction.schedule.mode")

            if scheduleMode != .oneTime {
                let dueDayTitle = AppLocalization.string(
                    "transaction.schedule.dueDay",
                    defaultValue: "Due Day"
                )
                Picker(
                    dueDayTitle,
                    selection: $dueDayOfMonth
                ) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)")
                            .tag(day)
                    }
                }
                .pickerStyle(.menu)

                Picker(
                    AppLocalization.string("transaction.schedule.reminder", defaultValue: "Reminder"),
                    selection: $reminderLeadDays
                ) {
                    let daysBeforeText = AppLocalization.string(
                        "transaction.schedule.reminder.daysBefore",
                        defaultValue: "day(s) before"
                    )
                    Text(AppLocalization.string(
                        "transaction.schedule.reminder.sameDay",
                        defaultValue: "Same day"
                    )).tag(0)

                    Text("1 \(daysBeforeText)").tag(1)
                    Text("3 \(daysBeforeText)").tag(3)
                    Text("7 \(daysBeforeText)").tag(7)
                }
            }

        } header: {
            Text(AppLocalization.string("transaction.schedule.header", defaultValue: "Subscription"))
        } footer: {
            if scheduleMode != .oneTime {
                Text(AppLocalization.string(
                    "transaction.schedule.footer",
                    defaultValue: "Subscription expenses auto-generate up to 31 days ahead."
                ))
            }
        }
    }
    
    private var notesSection: some View {
        Section(AppLocalization.string("transaction.notes", defaultValue: "Notes")) {
            TextField(
                AppLocalization.string("transaction.notes.placeholder", defaultValue: "Add notes..."),
                text: $notes,
                axis: .vertical
            )
            .lineLimit(3...6)
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        amount > 0 && selectedAccount != nil
    }
    
    // MARK: - Actions

    private func resetFormForNewTransaction() {
        let now = Date()
        transactionType = .expense
        amount = 0
        selectedCategory = nil
        selectedAccount = nil
        date = now
        notes = ""
        scheduleMode = .oneTime
        dueDayOfMonth = Calendar.current.component(.day, from: now)
        reminderLeadDays = TransactionReminderScheduler.defaultReminderLeadDays
        isSaving = false
        showError = false
        errorMessage = ""
    }
    
    private func loadExistingTransaction() {
        guard let transaction = existingTransaction else { return }
        
        transactionType = transaction.type
        amount = transaction.amount
        selectedCategory = transaction.category
        selectedAccount = transaction.account
        date = transaction.date
        notes = transaction.notes ?? ""
        dueDayOfMonth = transaction.dueDayOfMonth ?? Calendar.current.component(.day, from: transaction.date)
        reminderLeadDays = transaction.reminderLeadDays ?? TransactionReminderScheduler.defaultReminderLeadDays

        if transaction.isRecurringTemplate || transaction.isGeneratedFromRecurring {
            scheduleMode = .recurring
        } else {
            scheduleMode = .oneTime
        }
    }
    
    private func applyPreferredAccountIfNeeded() {
        guard existingTransaction == nil, selectedAccount == nil else { return }
        
        guard !accounts.isEmpty else { return }
        
        if TransactionAccountPreference.rememberLastUsedAccount,
           let lastUsedId = TransactionAccountPreference.lastUsedAccountId,
           let lastUsedAccount = accounts.first(where: { $0.id == lastUsedId }) {
            selectedAccount = lastUsedAccount
            return
        }
        
        if let defaultAccountId = TransactionAccountPreference.defaultAccountId,
           let defaultAccount = accounts.first(where: { $0.id == defaultAccountId }) {
            selectedAccount = defaultAccount
            return
        }
        
        if let cashAccount = accounts.first(where: { $0.type == .cash }) {
            selectedAccount = cashAccount
            return
        }
        
        selectedAccount = accounts.first
    }
    
    private func saveTransaction() {
        guard isFormValid, let account = selectedAccount else { return }
        
        isSaving = true
        let saveStartedAt = PerformanceLogger.start(
            "TransactionEntrySheet.Save",
            metadata: "type=\(transactionType.rawValue),schedule=\(scheduleMode.rawValue)"
        )
        var saveStatus = "success"
        defer {
            isSaving = false
            PerformanceLogger.end(
                "TransactionEntrySheet.Save",
                from: saveStartedAt,
                metadata: "status=\(saveStatus)"
            )
        }
        
        do {
            let service = TransactionService(context: modelContext)
            
            if let existing = existingTransaction {
                let templateForScheduledEdit = try scheduledTemplateForEditing(
                    from: existing,
                    service: service
                )

                if let template = templateForScheduledEdit {
                    if transactionType == .expense, scheduleMode != .oneTime {
                        try service.updateScheduledTemplate(
                            template,
                            amount: amount,
                            startDate: date,
                            dueDayOfMonth: dueDayOfMonth,
                            reminderLeadDays: reminderLeadDays,
                            account: account,
                            notes: notes.isEmpty ? nil : notes,
                            category: selectedCategory,
                            planType: selectedPlanType
                        )
                        let generator = RecurringTransactionGenerator(context: modelContext)
                        let cutoffDate = Calendar.current.date(
                            byAdding: .day,
                            value: RecurringTransactionGenerator.defaultLookAheadDays,
                            to: .now
                        ) ?? .now
                        let generated = try generator.generateTransactions(from: template, upTo: cutoffDate)
                        let reminderScheduler = TransactionReminderScheduler(context: modelContext)
                        Task {
                            await reminderScheduler.removeReminders(forTemplateId: template.id)
                            try? await reminderScheduler.syncReminders(for: generated)
                        }
                    } else {
                        let templateId = template.id
                        let generator = RecurringTransactionGenerator(context: modelContext)
                        try generator.deleteFutureGeneratedTransactions(for: template)

                        template.isRecurringTemplate = false
                        template.recurrenceRule = nil
                        template.schedulePlanType = nil
                        template.dueDayOfMonth = nil
                        template.reminderLeadDays = nil
                        template.installmentTotalCount = nil
                        template.installmentSequenceNumber = nil
                        template.recurringTemplateId = nil
                        template.generatedDate = nil

                        template.type = transactionType
                        template.amount = amount
                        template.category = selectedCategory
                        template.account = account
                        template.date = date
                        template.notes = notes.isEmpty ? nil : notes
                        template.currencyCode = account.currencyCode
                        try modelContext.save()

                        let reminderScheduler = TransactionReminderScheduler(context: modelContext)
                        Task {
                            await reminderScheduler.removeReminders(forTemplateId: templateId)
                        }
                    }
                } else {
                    existing.type = transactionType
                    existing.amount = amount
                    existing.category = selectedCategory
                    existing.account = account
                    existing.date = date
                    existing.notes = notes.isEmpty ? nil : notes
                    existing.currencyCode = account.currencyCode

                    try modelContext.save()
                }
            } else {
                if transactionType == .expense, scheduleMode != .oneTime {
                    let template = try service.createScheduled(
                        amount: amount,
                        startDate: date,
                        dueDayOfMonth: dueDayOfMonth,
                        reminderLeadDays: reminderLeadDays,
                        account: account,
                        category: selectedCategory,
                        notes: notes.isEmpty ? nil : notes,
                        planType: selectedPlanType
                    )
                    let generator = RecurringTransactionGenerator(context: modelContext)
                    let cutoffDate = Calendar.current.date(
                        byAdding: .day,
                        value: RecurringTransactionGenerator.defaultLookAheadDays,
                        to: .now
                    ) ?? .now
                    let generated = try generator.generateTransactions(from: template, upTo: cutoffDate)
                    let reminderScheduler = TransactionReminderScheduler(context: modelContext)
                    Task {
                        try? await reminderScheduler.syncReminders(for: generated)
                    }
                } else {
                    try service.create(
                        amount: amount,
                        type: transactionType,
                        date: date,
                        notes: notes.isEmpty ? nil : notes,
                        account: account,
                        category: selectedCategory
                    )
                }
            }
            
            onSave()
            if TransactionAccountPreference.rememberLastUsedAccount {
                TransactionAccountPreference.lastUsedAccountId = account.id
            }
            dismiss()
            
        } catch {
            saveStatus = "error"
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleFirstAmountInput() {
        guard !hasLoggedFirstAmountInput else { return }
        hasLoggedFirstAmountInput = true

        if let focusedAt = amountFieldFocusedAt {
            PerformanceLogger.end(
                "TransactionEntrySheet.CustomPad.FirstKey",
                from: focusedAt
            )
        }

        guard let openedAt = sheetOpenedAt else {
            PerformanceLogger.mark("TransactionEntrySheet.CustomPad.FirstKey")
            return
        }

        PerformanceLogger.end(
            "TransactionEntrySheet.TimeToFirstAmountInput",
            from: openedAt
        )
    }

    private func handleAmountFieldFocusChanged(_ isFocused: Bool) {
        if isFocused {
            amountFieldFocusedAt = Date()
            PerformanceLogger.mark("TransactionEntrySheet.CustomPad.Open")
            selectedDetent = .large
        } else {
            amountFieldFocusedAt = nil
        }
    }

    private func scheduledTemplateForEditing(
        from transaction: Transaction,
        service: TransactionService
    ) throws -> Transaction? {
        if transaction.isRecurringTemplate {
            return transaction
        }

        guard let templateID = transaction.recurringTemplateId else {
            return nil
        }

        return try service.fetch(byId: templateID)
    }

    private var selectedPlanType: TransactionService.ScheduledPlanKind {
        .recurring
    }
}

// MARK: - Preview

#Preview("Add Transaction") {
    TransactionEntrySheet { }
        .modelContainer(for: [Transaction.self, Account.self, Category.self], inMemory: true)
}
