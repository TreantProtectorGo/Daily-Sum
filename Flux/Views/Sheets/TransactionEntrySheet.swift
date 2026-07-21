import SwiftUI
import SwiftData

private enum ScheduleFormMode: String, CaseIterable, Identifiable {
    case oneTime
    case recurring

    var id: String { rawValue }
}

private struct TravelInputCurrencyTransition: Equatable {
    let previousCurrencyCode: String?
    let nextCurrencyCode: String?
}

private struct TravelCurrencyConversionContext {
    let id: UUID
    let transition: TravelInputCurrencyTransition
    let accountID: UUID
    let accountCurrencyCode: String
    let inputAmount: Decimal
    let transactionDate: Date
}

enum TransactionEntryFormValidation {
    static func canSave(
        amount: Decimal,
        selectedAccount: Account?,
        selectedCategory: Category?
    ) -> Bool {
        amount > 0 && selectedAccount != nil && selectedCategory != nil
    }
}

enum TransactionEntryTypeChangeSource {
    case userSelection
    case programmatic
}

enum TransactionEntryCategorySelection {
    static func resolvedCategory(
        currentCategory: Category?,
        previousType: TransactionType,
        nextType: TransactionType,
        changeSource: TransactionEntryTypeChangeSource
    ) -> Category? {
        guard previousType != nextType else { return currentCategory }

        switch changeSource {
        case .userSelection:
            return nil
        case .programmatic:
            return currentCategory
        }
    }
}

enum TransactionEntryTypeEditing {
    static func canEditType(existingTransaction: Transaction?) -> Bool {
        existingTransaction == nil
    }
}

enum TransactionEntryInitialType {
    static func resolved(_ requestedType: TransactionType?) -> TransactionType {
        requestedType ?? .expense
    }
}

enum TransactionEntryPresentation {
    static func navigationTitle(
        existingTransaction: Transaction?,
        transactionType: TransactionType
    ) -> String {
        if existingTransaction == nil {
            return AppLocalization.string(
                "transaction.add",
                defaultValue: "Add Transaction"
            )
        }

        switch transactionType {
        case .expense:
            return AppLocalization.string(
                "transaction.edit.expense",
                defaultValue: "Edit Expense"
            )
        case .income:
            return AppLocalization.string(
                "transaction.edit.income",
                defaultValue: "Edit Income"
            )
        }
    }
}

enum TransactionEntryCategoryPresentation {
    static func shouldAutoPresentAfterAmountConfirmation(
        existingTransaction: Transaction?,
        amount: Decimal,
        selectedCategory: Category?
    ) -> Bool {
        existingTransaction == nil && amount > 0 && selectedCategory == nil
    }
}

enum TransactionEntryAccountPresentation {
    static func shouldAutoPresentAfterCategorySelection(
        isEnabled: Bool,
        selectedCategory: Category?,
        availableAccountsCount: Int
    ) -> Bool {
        isEnabled && selectedCategory != nil && availableAccountsCount > 1
    }
}

enum TransactionEntryAccountSelection {
    static func availableAccounts(
        from accounts: [Account],
        existingTransaction: Transaction?,
        isTravelTransaction: Bool,
        existingTravelSnapshot: TravelTransactionSnapshot?
    ) -> [Account] {
        if let existingTravelSnapshot,
           existingTransaction != nil,
           isTravelTransaction {
            return uniqueAccounts(accounts.filter {
                TravelCurrencyState.normalizedCurrencyCode($0.currencyCode)
                    == existingTravelSnapshot.accountCurrencyCode
            })
        }

        return uniqueAccounts(accounts)
    }

    static func reconciledSelectedAccount(
        _ selectedAccount: Account?,
        availableAccounts: [Account]
    ) -> Account? {
        guard let selectedAccount else {
            return nil
        }

        if availableAccounts.contains(where: { $0.id == selectedAccount.id }) {
            return selectedAccount
        }

        return availableAccounts.first
    }

    private static func uniqueAccounts(_ accounts: [Account]) -> [Account] {
        var seenAccountIDs = Set<UUID>()
        return accounts.filter { account in
            seenAccountIDs.insert(account.id).inserted
        }
    }
}

enum TransactionEntryCurrencySelection {
    static func foreignCurrencyCode(
        candidateCurrencyCode: String?,
        accountCurrencyCode: String?
    ) -> String? {
        let candidateCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(
            candidateCurrencyCode
        )
        let accountCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(
            accountCurrencyCode
        )
        guard candidateCurrencyCode != accountCurrencyCode else { return nil }
        return candidateCurrencyCode
    }

    static func availableCurrencies(accountCurrencyCode: String?) -> [SupportedCurrency] {
        let accountCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(
            accountCurrencyCode
        )
        return SupportedCurrency.allCases.filter {
            $0.rawValue != accountCurrencyCode
        }
    }
}

enum TransactionEntryCurrencyConversion {
    static func shouldApplyResult(
        expectedConversionID: UUID,
        activeConversionID: UUID?,
        expectedAccountID: UUID,
        selectedAccountID: UUID?,
        expectedInputCurrencyCode: String?,
        currentInputCurrencyCode: String?,
        expectedInputAmount: Decimal,
        currentInputAmount: Decimal
    ) -> Bool {
        expectedConversionID == activeConversionID &&
            expectedAccountID == selectedAccountID &&
            expectedInputCurrencyCode == currentInputCurrencyCode &&
            expectedInputAmount == currentInputAmount
    }
}

// MARK: - Transaction Entry Sheet

/// Sheet for adding or editing a transaction
struct TransactionEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    private let existingTransactionID: UUID?
    private let initialTransactionType: TransactionType
    private let onSave: () -> Void
    @State private var existingTransaction: Transaction?
    
    // Form state
    @State private var transactionType: TransactionType = .expense
    @State private var amount: Decimal = 0
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var isTravelTransaction = false
    @State private var hasTravelTransactionOverride = false
    @State private var manualTransactionCurrencyCode: String?
    @State private var isConvertingTravelCurrency = false
    @State private var activeTravelCurrencyConversion: TravelCurrencyConversionContext?
    @State private var suppressedTravelInputTransition: TravelInputCurrencyTransition?
    @State private var travelPreview: TravelTransactionSnapshot?
    @State private var scheduleMode: ScheduleFormMode = .oneTime
    @State private var dueDayOfMonth: Int = Calendar.current.component(.day, from: .now)
    @State private var reminderLeadDays: Int = TransactionReminderScheduler.defaultReminderLeadDays
    @State private var sheetOpenedAt: Date?
    @State private var hasLoggedFirstAmountInput = false
    @State private var amountFieldFocusedAt: Date?
    @State private var categoryPresentationTrigger = 0
    @State private var accountPresentationTrigger = 0
    @State private var amountInputSession = AmountInputSession()
    
    @State private var isSaving = false
    @State private var showSubscriptionSyncScopeDialog = false
    @State private var showError = false
    @State private var errorMessage = ""

    @AppStorage(UserCurrencyPreference.storageKey) private var preferredCurrencyCode = UserCurrencyPreference.resolvedCurrencyCode
    @AppStorage(TravelCurrencyPreference.modeEnabledStorageKey) private var isTravelCurrencyModeEnabled = true
    @AppStorage(TravelCurrencyPreference.sourceStorageKey) private var travelCurrencySource = TravelCurrencySource.automatic.rawValue
    @AppStorage(TravelCurrencyPreference.detectedCurrencyStorageKey) private var detectedTravelCurrencyCode = ""
    @AppStorage(TravelCurrencyPreference.manualCurrencyStorageKey) private var manualTravelCurrencyCode = ""
    
    @Query private var accounts: [Account]
    
    init(
        transaction: Transaction? = nil,
        initialType: TransactionType? = nil,
        onSave: @escaping () -> Void
    ) {
        self.existingTransactionID = transaction?.id
        self.initialTransactionType = TransactionEntryInitialType.resolved(initialType)
        self.onSave = onSave
        _transactionType = State(
            initialValue: initialTransactionType
        )
    }

    init(transactionId: UUID, onSave: @escaping () -> Void) {
        self.existingTransactionID = transactionId
        self.initialTransactionType = .expense
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Amount
                amountSection
                    .disabled(isConvertingTravelCurrency)
                
                // Grouped details
                detailsSection
                    .disabled(isConvertingTravelCurrency)

                if transactionType == .expense {
                    scheduleSection
                }
                
                // Notes
                notesSection
            }
            .navigationTitle(
                TransactionEntryPresentation.navigationTitle(
                    existingTransaction: existingTransaction,
                    transactionType: transactionType
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    IconToolbarButton(systemName: "xmark", accessibilityLabel: AppLocalization.string("action.close", defaultValue: "Close")) {
                        dismiss()
                    }
                }
                
                if TransactionEntryTypeEditing.canEditType(existingTransaction: existingTransaction) {
                    ToolbarItem(placement: .principal) {
                        transactionTypePicker
                            .frame(width: 220)
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    IconToolbarButton(systemName: "checkmark", accessibilityLabel: AppLocalization.string("action.apply", defaultValue: "Apply")) {
                        handleSaveRequest()
                    }
                    .accessibilityIdentifier("transaction.save.button")
                    .disabled(!isFormValid || isSaving)
                }
            }
            .onAppear {
                let mode = existingTransactionID == nil ? "create" : "edit"
                sheetOpenedAt = PerformanceLogger.start(
                    "TransactionEntrySheet.Open",
                    metadata: "mode=\(mode)"
                )
    
                if existingTransactionID != nil {
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
            .onChange(of: selectedAccount?.id) { _, _ in
                handleSelectedAccountChange()
            }
            .onChange(of: travelInputCurrencyCode) { previousCurrencyCode, nextCurrencyCode in
                handleTravelInputCurrencyChange(
                    from: previousCurrencyCode,
                    to: nextCurrencyCode
                )
            }
            .onChange(of: detectedTravelCurrencyCode) { _, _ in
                applyTravelTransactionDefaultIfNeeded()
            }
            .task {
                await refreshDetectedTravelCurrency()
            }
            .task(id: travelPreviewRefreshKey) {
                await refreshTravelPreviewIfNeeded()
            }
            .confirmationDialog(
                AppLocalization.string(
                    "transaction.subscription.sync.title",
                    defaultValue: "Sync generated transactions"
                ),
                isPresented: $showSubscriptionSyncScopeDialog,
                titleVisibility: .visible
            ) {
                Button(
                    AppLocalization.string(
                        "transaction.subscription.sync.todayAndFuture",
                        defaultValue: "Sync Today and Future"
                    )
                ) {
                    Task {
                        await saveTransaction(syncScope: .todayAndFuture)
                    }
                }
                Button(
                    AppLocalization.string(
                        "transaction.subscription.sync.allGenerated",
                        defaultValue: "Sync All Generated Transactions"
                    )
                ) {
                    Task {
                        await saveTransaction(syncScope: .allGenerated)
                    }
                }
                Button(
                    AppLocalization.string("action.cancel", defaultValue: "Cancel"),
                    role: .cancel
                ) { }
            } message: {
                Text(
                    AppLocalization.string(
                        "transaction.subscription.sync.message",
                        defaultValue: "Choose whether changes apply to today and future transactions only, or also update past generated transactions."
                    )
                )
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
        .dockedAmountNumberPad(
            session: amountInputSession,
            amount: $amount,
            onFirstUserInput: handleFirstAmountInput,
            onFocusChanged: handleAmountFieldFocusChanged,
            onConfirm: handleAmountInputConfirmed
        )
        .presentationDetents([.large])
    }
    
    // MARK: - Form Sections
    
    private var transactionTypePicker: some View {
        Picker(
            AppLocalization.string("transaction.type", defaultValue: "Type"),
            selection: Binding(
                get: { transactionType },
                set: handleTransactionTypeSelection
            )
        ) {
            ForEach(TransactionType.allCases, id: \.self) { type in
                Text(type.localizedName)
                    .tag(type)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("transaction.type.mode")
        .disabled(
            !TransactionEntryTypeEditing.canEditType(existingTransaction: existingTransaction) ||
                isConvertingTravelCurrency
        )
    }
    
    private var amountSection: some View {
        Section {
            if travelInputCurrencyCode != nil {
                VStack(spacing: 0) {
                    AmountInputView(
                        amount: $amount,
                        currencyCode: amountInputCurrencyCode,
                        autoFocus: existingTransaction == nil,
                        useGlassBackground: false,
                        session: amountInputSession,
                        onFocusChanged: handleAmountFieldFocusChanged
                    )

                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 16)

                    travelPreviewView()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .glassBackground(cornerRadius: 12, isInteractive: true, style: .section)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } else {
                AmountInputView(
                    amount: $amount,
                    currencyCode: amountInputCurrencyCode,
                    autoFocus: existingTransaction == nil,
                    session: amountInputSession,
                    onFocusChanged: handleAmountFieldFocusChanged
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }
    
    private var detailsSection: some View {
        Section {
            CategoryPickerView(
                selectedCategory: $selectedCategory,
                transactionType: transactionType,
                presentationTrigger: categoryPresentationTrigger,
                onSelectionCompleted: handleCategorySelectionCompleted
            )

            if accounts.isEmpty {
                Text(AppLocalization.string("transaction.noAccounts", defaultValue: "No accounts available. Please create an account first."))
                    .foregroundStyle(.secondary)
            } else {
                AccountPickerView(
                    selectedAccount: $selectedAccount,
                    showBalance: true,
                    expansionTrigger: accountPresentationTrigger,
                    availableAccounts: availableAccounts
                )
            }

            DatePicker(
                AppLocalization.string("transaction.date", defaultValue: "Date"),
                selection: $date,
                displayedComponents: .date
            )
            .onChange(of: date) { _, newValue in
                dueDayOfMonth = Calendar.current.component(.day, from: newValue)
            }

            Toggle(
                AppLocalization.string(
                    "transaction.travel",
                    defaultValue: "Foreign Currency Transaction"
                ),
                isOn: Binding(
                    get: { isTravelTransaction },
                    set: handleTravelTransactionToggleChange
                )
            )

            if existingTravelSnapshot == nil, isTravelTransaction {
                TransactionCurrencyPickerView(
                    selectedCurrencyCode: travelInputCurrencyCode,
                    suggestedCurrencyCode: suggestedTransactionCurrencyCode,
                    availableCurrencies: availableTransactionCurrencies
                ) { selectedCurrencyCode in
                    handleManualTransactionCurrencySelection(selectedCurrencyCode)
                }
                .disabled(isConvertingTravelCurrency)
            }
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
        Section {
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
        TransactionEntryFormValidation.canSave(
            amount: amount,
            selectedAccount: selectedAccount,
            selectedCategory: selectedCategory
        ) && (!isTravelTransaction || travelInputCurrencyCode != nil) &&
            !isConvertingTravelCurrency
    }

    private var existingTravelSnapshot: TravelTransactionSnapshot? {
        existingTransaction?.resolvedTravelSnapshot
    }

    private var travelInputCurrencyCode: String? {
        let selectedCurrencyCode =
            manualTransactionCurrencyCode ?? resolvedCurrentTravelCurrencyCode
        let inputCurrencyCode = TravelTransactionSnapshots.inputCurrencyCode(
            existingTransaction: existingTransaction,
            isTravelTransaction: isTravelTransaction,
            currentTravelCurrencyCode: selectedCurrencyCode
        )

        guard existingTransaction == nil else {
            return inputCurrencyCode
        }
        return TransactionEntryCurrencySelection.foreignCurrencyCode(
            candidateCurrencyCode: inputCurrencyCode,
            accountCurrencyCode: selectedAccount?.currencyCode
        )
    }

    private var availableTransactionCurrencies: [SupportedCurrency] {
        TransactionEntryCurrencySelection.availableCurrencies(
            accountCurrencyCode: selectedAccount?.currencyCode
        )
    }

    private var suggestedTransactionCurrencyCode: String? {
        TransactionEntryCurrencySelection.foreignCurrencyCode(
            candidateCurrencyCode: resolvedCurrentTravelCurrencyCode,
            accountCurrencyCode: selectedAccount?.currencyCode
        )
    }

    private var amountInputCurrencyCode: String {
        travelInputCurrencyCode
            ?? selectedAccount?.currencyCode
            ?? UserCurrencyPreference.resolvedCurrencyCode
    }

    private var availableAccounts: [Account] {
        TransactionEntryAccountSelection.availableAccounts(
            from: accounts,
            existingTransaction: existingTransaction,
            isTravelTransaction: isTravelTransaction,
            existingTravelSnapshot: existingTravelSnapshot
        )
    }

    private var travelPreviewRefreshKey: String {
        [
            existingTransaction?.id.uuidString ?? "new",
            transactionType.rawValue,
            isTravelTransaction.description,
            selectedAccount?.id.uuidString ?? "no-account",
            NSDecimalNumber(decimal: amount).stringValue,
            String(Int(date.timeIntervalSinceReferenceDate)),
            travelInputCurrencyCode ?? "no-travel-currency"
        ].joined(separator: "|")
    }

    @ViewBuilder
    private func travelPreviewView() -> some View {
        HStack {
            if let travelPreview {
                let accountAmountText = CurrencyFormatter.shared.format(
                    travelPreview.accountAmount,
                    currencyCode: travelPreview.accountCurrencyCode
                )
                Text(
                    existingTransaction == nil
                        ? "= \(accountAmountText)"
                        : AppLocalization.string(
                            "transaction.travel.settledAs",
                            defaultValue: "Settled as"
                        ) + " " + accountAmountText
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Actions

    private func handleSaveRequest() {
        let isEditingSubscription = existingTransaction?.isRecurringTemplate == true ||
            existingTransaction?.recurringTemplateId != nil
        let willRemainRecurring = transactionType == .expense && scheduleMode == .recurring

        if isEditingSubscription && willRemainRecurring {
            showSubscriptionSyncScopeDialog = true
        } else {
            Task {
                await saveTransaction(syncScope: .todayAndFuture)
            }
        }
    }

    private func resetFormForNewTransaction() {
        let now = Date()
        transactionType = initialTransactionType
        amount = 0
        selectedCategory = nil
        selectedAccount = nil
        date = now
        notes = ""
        isTravelTransaction = false
        hasTravelTransactionOverride = false
        manualTransactionCurrencyCode = nil
        isConvertingTravelCurrency = false
        activeTravelCurrencyConversion = nil
        suppressedTravelInputTransition = nil
        travelPreview = nil
        scheduleMode = .oneTime
        dueDayOfMonth = Calendar.current.component(.day, from: now)
        reminderLeadDays = TransactionReminderScheduler.defaultReminderLeadDays
        isSaving = false
        showError = false
        errorMessage = ""
    }
    
    private func loadExistingTransaction() {
        guard let transaction = fetchExistingTransaction() else { return }
        existingTransaction = transaction
        
        transactionType = transaction.type
        amount = transaction.amount
        selectedCategory = transaction.category
        selectedAccount = transaction.account
        date = transaction.date
        notes = transaction.notes ?? ""
        isTravelTransaction = transaction.resolvedTravelSnapshot != nil
        hasTravelTransactionOverride = true
        travelPreview = transaction.resolvedTravelSnapshot
        if let existingTravelSnapshot = transaction.resolvedTravelSnapshot {
            amount = existingTravelSnapshot.travelAmount
        }
        dueDayOfMonth = transaction.dueDayOfMonth ?? Calendar.current.component(.day, from: transaction.date)
        reminderLeadDays = transaction.reminderLeadDays ?? TransactionReminderScheduler.defaultReminderLeadDays

        if transaction.isRecurringTemplate || transaction.isGeneratedFromRecurring {
            scheduleMode = .recurring
        } else {
            scheduleMode = .oneTime
        }
    }

    private func fetchExistingTransaction() -> Transaction? {
        guard let transactionID = existingTransactionID else { return nil }
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.id == transactionID }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func handleTransactionTypeSelection(_ nextType: TransactionType) {
        guard TransactionEntryTypeEditing.canEditType(existingTransaction: existingTransaction) else {
            return
        }

        selectedCategory = TransactionEntryCategorySelection.resolvedCategory(
            currentCategory: selectedCategory,
            previousType: transactionType,
            nextType: nextType,
            changeSource: .userSelection
        )
        transactionType = nextType
        if nextType != .expense {
            scheduleMode = .oneTime
        }
        if existingTransaction == nil {
            applyTravelTransactionDefaultIfNeeded()
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
            applyTravelTransactionDefaultIfNeeded()
            return
        }
        
        selectedAccount = accounts.first
        applyTravelTransactionDefaultIfNeeded()
    }

    private func applyTravelTransactionDefaultIfNeeded() {
        guard existingTransaction == nil else { return }

        let userOverride = hasTravelTransactionOverride ? isTravelTransaction : nil
        let defaultTransactionCurrencyCode = resolvedCurrentTravelCurrencyCode ==
            TravelCurrencyState.normalizedCurrencyCode(selectedAccount?.currencyCode)
                ? nil
                : resolvedCurrentTravelCurrencyCode
        let resolvedValue = TransactionTravelDefaults.resolveIsTravelTransaction(
            transactionType: transactionType,
            currentTravelCurrencyCode: defaultTransactionCurrencyCode,
            userOverride: userOverride
        )
        updateTravelCurrencyState {
            isTravelTransaction = resolvedValue
        }
        if !resolvedValue {
            travelPreview = nil
        } else {
            reconcileSelectedAccountWithAvailableAccounts()
        }
    }

    private func reconcileSelectedAccountWithAvailableAccounts() {
        selectedAccount = TransactionEntryAccountSelection.reconciledSelectedAccount(
            selectedAccount,
            availableAccounts: availableAccounts
        )
    }

    private func handleSelectedAccountChange() {
        let selectedCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(
            manualTransactionCurrencyCode ?? resolvedCurrentTravelCurrencyCode
        )
        let accountCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(
            selectedAccount?.currencyCode
        )
        if existingTransaction == nil,
           isTravelTransaction,
           selectedCurrencyCode != nil,
           selectedCurrencyCode == accountCurrencyCode {
            let hadManualSelection = manualTransactionCurrencyCode != nil
            updateTravelCurrencyState(convertAmount: false) {
                isTravelTransaction = false
                travelPreview = nil
                if hadManualSelection {
                    hasTravelTransactionOverride = true
                }
            }
        }
        applyTravelTransactionDefaultIfNeeded()
    }

    private func handleTravelInputCurrencyChange(
        from previousCurrencyCode: String?,
        to nextCurrencyCode: String?
    ) {
        let transition = TravelInputCurrencyTransition(
            previousCurrencyCode: previousCurrencyCode,
            nextCurrencyCode: nextCurrencyCode
        )
        if suppressedTravelInputTransition == transition {
            suppressedTravelInputTransition = nil
            return
        }

        guard previousCurrencyCode != nextCurrencyCode else { return }
        convertAmountPreservingSettlementValue(for: transition)
    }

    private func updateTravelCurrencyState(
        convertAmount: Bool = true,
        _ update: () -> Void
    ) {
        let previousCurrencyCode = travelInputCurrencyCode
        update()
        let nextCurrencyCode = travelInputCurrencyCode
        guard previousCurrencyCode != nextCurrencyCode else { return }

        let transition = TravelInputCurrencyTransition(
            previousCurrencyCode: previousCurrencyCode,
            nextCurrencyCode: nextCurrencyCode
        )
        suppressedTravelInputTransition = transition
        if convertAmount {
            convertAmountPreservingSettlementValue(for: transition)
        } else {
            cancelActiveTravelCurrencyConversion()
        }
    }

    private func convertAmountPreservingSettlementValue(
        for transition: TravelInputCurrencyTransition
    ) {
        cancelActiveTravelCurrencyConversion()
        travelPreview = nil

        guard let account = selectedAccount,
              amount > 0 else { return }

        let context = TravelCurrencyConversionContext(
            id: UUID(),
            transition: transition,
            accountID: account.id,
            accountCurrencyCode: account.currencyCode,
            inputAmount: amount,
            transactionDate: date
        )
        activeTravelCurrencyConversion = context
        isConvertingTravelCurrency = true

        Task {
            let conversionService = CurrencyConversionService(context: modelContext)
            let nextConversionCurrencyCode = transition.nextCurrencyCode
                ?? TravelCurrencyState.normalizedCurrencyCode(account.currencyCode)
                ?? account.currencyCode.uppercased()
            do {
                let convertedAmount = try await
                    TravelTransactionCurrencyChange.convertInputAmountPreservingAccountValue(
                        currentInputAmount: context.inputAmount,
                        previousInputCurrencyCode: transition.previousCurrencyCode,
                        nextInputCurrencyCode: nextConversionCurrencyCode,
                        accountCurrencyCode: context.accountCurrencyCode,
                        date: context.transactionDate,
                        conversionService: conversionService
                    )
                guard activeTravelCurrencyConversion?.id == context.id else { return }
                guard TransactionEntryCurrencyConversion.shouldApplyResult(
                    expectedConversionID: context.id,
                    activeConversionID: activeTravelCurrencyConversion?.id,
                    expectedAccountID: context.accountID,
                    selectedAccountID: selectedAccount?.id,
                    expectedInputCurrencyCode: transition.nextCurrencyCode,
                    currentInputCurrencyCode: travelInputCurrencyCode,
                    expectedInputAmount: context.inputAmount,
                    currentInputAmount: amount
                ) else {
                    finishTravelCurrencyConversion(id: context.id)
                    return
                }
                amount = convertedAmount
                finishTravelCurrencyConversion(id: context.id)
            } catch {
                guard activeTravelCurrencyConversion?.id == context.id else { return }
                rollbackTravelCurrencyTransition(context)
            }
        }
    }

    private func finishTravelCurrencyConversion(id: UUID) {
        guard activeTravelCurrencyConversion?.id == id else { return }
        activeTravelCurrencyConversion = nil
        isConvertingTravelCurrency = false
    }

    private func cancelActiveTravelCurrencyConversion() {
        activeTravelCurrencyConversion = nil
        isConvertingTravelCurrency = false
    }

    private func rollbackTravelCurrencyTransition(
        _ context: TravelCurrencyConversionContext
    ) {
        updateTravelCurrencyState(convertAmount: false) {
            if let previousCurrencyCode = context.transition.previousCurrencyCode {
                manualTransactionCurrencyCode = previousCurrencyCode
                isTravelTransaction = true
                hasTravelTransactionOverride = true
            } else {
                manualTransactionCurrencyCode = nil
                isTravelTransaction = false
                hasTravelTransactionOverride = true
            }
        }
    }

    private func handleManualTransactionCurrencySelection(_ currencyCode: String?) {
        let selectedCurrencyCode = TravelCurrencyState.normalizedCurrencyCode(currencyCode)
        updateTravelCurrencyState {
            manualTransactionCurrencyCode = selectedCurrencyCode
        }
    }

    private func handleTravelTransactionToggleChange(_ newValue: Bool) {
        hasTravelTransactionOverride = true

        if newValue {
            enableTravelTransactionMode()
        } else {
            disableTravelTransactionMode()
        }
    }

    private func enableTravelTransactionMode() {
        if let existingTravelSnapshot {
            updateTravelCurrencyState(convertAmount: false) {
                isTravelTransaction = true
                amount = existingTravelSnapshot.travelAmount
                travelPreview = existingTravelSnapshot
            }
            return
        }

        updateTravelCurrencyState {
            isTravelTransaction = true
        }
        reconcileSelectedAccountWithAvailableAccounts()
    }

    private func disableTravelTransactionMode() {
        let accountAmount = travelPreview?.accountAmount
            ?? existingTravelSnapshot?.accountAmount
            ?? existingTransaction?.amount

        if let accountAmount {
            updateTravelCurrencyState(convertAmount: false) {
                isTravelTransaction = false
                travelPreview = nil
                amount = accountAmount
            }
        } else {
            updateTravelCurrencyState {
                isTravelTransaction = false
                travelPreview = nil
            }
        }
    }

    private var resolvedCurrentTravelCurrencyCode: String? {
        TravelCurrencyState.resolve(
            defaultCurrencyCode: UserCurrencyPreference.resolvedDisplayCurrencyCode(
                preferredCurrencyCode: preferredCurrencyCode
            ),
            isEnabled: isTravelCurrencyModeEnabled,
            source: TravelCurrencySource(rawValue: travelCurrencySource) ?? .automatic,
            detectedCurrencyCode: detectedTravelCurrencyCode,
            manualTravelCurrencyCode: manualTravelCurrencyCode
        )
        .currentTravelCurrencyCode
    }

    private func refreshDetectedTravelCurrency() async {
        let refresher = TravelCurrencyPreferenceRefresher()
        guard let refreshedCurrencyCode = await refresher.refreshDetectedTravelCurrency() else {
            return
        }
        detectedTravelCurrencyCode = refreshedCurrencyCode
    }
    
    private func saveTransaction(
        syncScope: ScheduledTransactionSyncScope = .todayAndFuture
    ) async {
        guard isFormValid,
              let account = selectedAccount,
              let selectedCategory else { return }
        
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
            let resolvedTravelSnapshot = try await resolveTravelSnapshotForSave(account: account)
            let resolvedIsTravelTransaction = resolvedTravelSnapshot != nil
            
            if let existing = existingTransaction {
                let templateForScheduledEdit = try scheduledTemplateForEditing(
                    from: existing,
                    service: service
                )

                if let template = templateForScheduledEdit {
                    if transactionType == .expense, scheduleMode != .oneTime {
                        let syncReferenceDate = Date.now
                        let cutoffDate = Calendar.current.date(
                            byAdding: .day,
                            value: RecurringTransactionGenerator.defaultLookAheadDays,
                            to: syncReferenceDate
                        ) ?? syncReferenceDate
                        let generated = try service.updateScheduledTemplate(
                            template,
                            amount: amount,
                            startDate: date,
                            dueDayOfMonth: dueDayOfMonth,
                            reminderLeadDays: reminderLeadDays,
                            account: account,
                            notes: notes.isEmpty ? nil : notes,
                            isTravelTransaction: resolvedIsTravelTransaction,
                            travelSnapshot: resolvedTravelSnapshot,
                            category: selectedCategory,
                            planType: selectedPlanType,
                            syncScope: syncScope,
                            now: syncReferenceDate,
                            regenerateThrough: cutoffDate
                        )
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
                        template.category = selectedCategory
                        template.account = account
                        template.date = date
                        template.notes = notes.isEmpty ? nil : notes
                        TravelTransactionSnapshots.apply(
                            resolvedTravelSnapshot,
                            to: template
                        )
                        if resolvedTravelSnapshot == nil {
                            template.amount = amount
                            template.currencyCode = account.currencyCode
                        }
                        try modelContext.save()

                        let reminderScheduler = TransactionReminderScheduler(context: modelContext)
                        Task {
                            await reminderScheduler.removeReminders(forTemplateId: templateId)
                        }
                    }
                } else {
                    existing.type = transactionType
                    existing.category = selectedCategory
                    existing.account = account
                    existing.date = date
                    existing.notes = notes.isEmpty ? nil : notes
                    TravelTransactionSnapshots.apply(
                        resolvedTravelSnapshot,
                        to: existing
                    )
                    if resolvedTravelSnapshot == nil {
                        existing.amount = amount
                        existing.currencyCode = account.currencyCode
                    }

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
                        isTravelTransaction: resolvedIsTravelTransaction,
                        travelSnapshot: resolvedTravelSnapshot,
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
                        isTravelTransaction: resolvedIsTravelTransaction,
                        travelSnapshot: resolvedTravelSnapshot,
                        account: account,
                        category: selectedCategory
                    )
                }
            }
            
            TransactionDataChangeStore.shared.markChanged()
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

    private func resolveTravelSnapshotForSave(account: Account) async throws -> TravelTransactionSnapshot? {
        guard isTravelTransaction,
              let travelCurrencyCode = travelInputCurrencyCode else {
            return nil
        }

        if let existingTravelSnapshot,
           existingTransaction != nil {
            return TravelTransactionSnapshots.recomputeLockedSnapshot(
                existingSnapshot: existingTravelSnapshot,
                updatedTravelAmount: amount
            )
        }

        let conversionService = CurrencyConversionService(context: modelContext)
        return try await TravelTransactionSnapshots.buildSnapshot(
            travelAmount: amount,
            travelCurrencyCode: travelCurrencyCode,
            accountCurrencyCode: account.currencyCode,
            date: date,
            conversionService: conversionService
        )
    }

    private func refreshTravelPreviewIfNeeded() async {
        guard isTravelTransaction,
              let account = selectedAccount,
              amount > 0,
              let travelCurrencyCode = travelInputCurrencyCode else {
            travelPreview = isTravelTransaction ? existingTravelSnapshot : nil
            return
        }

        let refreshKey = travelPreviewRefreshKey

        do {
            let snapshot: TravelTransactionSnapshot
            if let existingTravelSnapshot,
               existingTransaction != nil {
                guard TravelCurrencyState.normalizedCurrencyCode(account.currencyCode)
                        == existingTravelSnapshot.accountCurrencyCode else {
                    travelPreview = nil
                    return
                }

                snapshot = TravelTransactionSnapshots.recomputeLockedSnapshot(
                    existingSnapshot: existingTravelSnapshot,
                    updatedTravelAmount: amount
                )
            } else {
                let conversionService = CurrencyConversionService(context: modelContext)
                snapshot = try await TravelTransactionSnapshots.buildSnapshot(
                    travelAmount: amount,
                    travelCurrencyCode: travelCurrencyCode,
                    accountCurrencyCode: account.currencyCode,
                    date: date,
                    conversionService: conversionService
                )
            }

            guard refreshKey == travelPreviewRefreshKey else { return }
            travelPreview = snapshot
        } catch {
            guard refreshKey == travelPreviewRefreshKey else { return }
            travelPreview = nil
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
        } else {
            amountFieldFocusedAt = nil
        }
    }

    private func handleAmountInputConfirmed() {
        guard TransactionEntryCategoryPresentation.shouldAutoPresentAfterAmountConfirmation(
            existingTransaction: existingTransaction,
            amount: amount,
            selectedCategory: selectedCategory
        ) else {
            return
        }

        categoryPresentationTrigger += 1
    }

    private func handleCategorySelectionCompleted(_ category: Category?) {
        guard TransactionEntryAccountPresentation.shouldAutoPresentAfterCategorySelection(
            isEnabled: TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection,
            selectedCategory: category,
            availableAccountsCount: availableAccounts.count
        ) else {
            return
        }

        accountPresentationTrigger += 1
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
