import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TransactionListViewModel?
    
    private let filterAccount: Account?
    private let externalSearchText: Binding<String>?
    
    @State private var showAddTransaction = false
    @State private var selectedTransaction: TransactionEditorSelection?
    @State private var showFilters = false
    @State private var pendingScheduledDeleteTransactionID: UUID?
    @State private var showScheduledDeleteDialog = false
    @State private var pendingSourceDeleteTransactionID: UUID?
    @State private var showSourceDeleteDialog = false
    
    private var isSearchContext: Bool {
        externalSearchText != nil
    }

    init(
        filterAccount: Account? = nil,
        searchText: Binding<String>? = nil
    ) {
        self.filterAccount = filterAccount
        self.externalSearchText = searchText
    }
    
    var body: some View {
        Group {
            if let viewModel {
                transactionContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(AppLocalization.string("transactions.title", defaultValue: "Transactions"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showFilters = true
                } label: {
                    IconToolbarGlyph(systemName: "line.3.horizontal.decrease")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppLocalization.string("action.filters", defaultValue: "Filters"))
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView(autoPopWhenTabSwitch: true)
                } label: {
                    IconToolbarGlyph(systemName: "gear")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppLocalization.string("tab.settings", defaultValue: "Settings"))
            }
        }
        .task {
            if viewModel == nil {
                viewModel = TransactionListViewModel(modelContext: modelContext)
                viewModel?.selectedAccount = filterAccount
                if let externalSearchText {
                    viewModel?.searchText = externalSearchText.wrappedValue
                }
            }
            await viewModel?.loadTransactions()
        }
        .onChange(of: externalSearchText?.wrappedValue ?? "") { _, newValue in
            guard let viewModel else { return }
            viewModel.searchText = newValue
            viewModel.applyFilters()
        }
        .refreshable {
            await viewModel?.loadTransactions()
        }
        .sheet(isPresented: $showAddTransaction) {
            TransactionEntrySheet(onSave: {
                Task { await viewModel?.loadTransactions() }
            })
        }
        .sheet(item: $selectedTransaction) { selection in
            TransactionEntrySheet(transactionId: selection.id, onSave: {
                Task { await viewModel?.loadTransactions() }
            })
        }
        .sheet(isPresented: $showFilters) {
            if let viewModel {
                TransactionFiltersSheet(viewModel: viewModel)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !isSearchContext {
                FloatingActionButton {
                    showAddTransaction = true
                }
                .accessibilityIdentifier("transactions.addButton")
                .padding(.trailing, 25)
                .padding(.bottom, 20)
            }
        }
        .alert(
            AppLocalization.string(
                "transaction.deleteScheduledFuture.title",
                defaultValue: "This is a subscription transaction"
            ),
            isPresented: $showScheduledDeleteDialog,
            actions: {
                Button(
                    AppLocalization.string(
                        "transaction.deleteScheduledFuture.skip",
                        defaultValue: "Skip this occurrence"
                    )
                ) {
                    guard let transactionID = pendingScheduledDeleteTransactionID else { return }
                    pendingScheduledDeleteTransactionID = nil
                    Task {
                        try? await viewModel?.handleFutureGeneratedDeletion(
                            transactionId: transactionID,
                            action: .skipOccurrence
                        )
                    }
                }

                Button(
                    AppLocalization.string(
                        "transaction.deleteScheduledFuture.stop",
                        defaultValue: "Stop this subscription"
                    ),
                    role: .destructive
                ) {
                    guard let transactionID = pendingScheduledDeleteTransactionID else { return }
                    pendingScheduledDeleteTransactionID = nil
                    Task {
                        try? await viewModel?.handleFutureGeneratedDeletion(
                            transactionId: transactionID,
                            action: .stopPlan
                        )
                    }
                }

                Button("Keep Subscription", role: .cancel) {
                    pendingScheduledDeleteTransactionID = nil
                }
            },
            message: {
                Text(
                    AppLocalization.string(
                        "transaction.deleteScheduledFuture.message",
                        defaultValue: "Do you want to skip only this due date or stop this subscription?"
                    )
                )
            }
        )
        .alert(
            AppLocalization.string(
                "transaction.deleteScheduledFuture.title",
                defaultValue: "This is a subscription transaction"
            ),
            isPresented: $showSourceDeleteDialog,
            actions: {
                Button(
                    AppLocalization.string(
                        "transaction.deleteScheduledSource.deleteOne",
                        defaultValue: "Delete only this transaction"
                    ),
                    role: .destructive
                ) {
                    guard let transactionID = pendingSourceDeleteTransactionID else { return }
                    pendingSourceDeleteTransactionID = nil
                    Task {
                        try? await viewModel?.deleteTransaction(transactionId: transactionID)
                    }
                }

                Button(
                    AppLocalization.string(
                        "transaction.deleteScheduledSource.deleteAll",
                        defaultValue: "Delete entire subscription"
                    ),
                    role: .destructive
                ) {
                    guard let transactionID = pendingSourceDeleteTransactionID else { return }
                    pendingSourceDeleteTransactionID = nil
                    Task {
                        try? await viewModel?.handleFutureGeneratedDeletion(
                            transactionId: transactionID,
                            action: .stopPlan
                        )
                    }
                }

                Button("Keep Transaction", role: .cancel) {
                    pendingSourceDeleteTransactionID = nil
                }
            },
            message: {
                Text(
                    AppLocalization.string(
                        "transaction.deleteScheduledSource.message",
                        defaultValue: "Deleting this source transaction will remove the entire subscription."
                    )
                )
            }
        )
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private func transactionContent(viewModel: TransactionListViewModel) -> some View {
        if !viewModel.hasVisibleTransactions {
            emptyState(viewModel: viewModel)
        } else {
            transactionList(viewModel: viewModel)
        }
    }
    
    @ViewBuilder
    private func transactionList(viewModel: TransactionListViewModel) -> some View {
        List {
            if !isSearchContext && viewModel.shouldShowUpcomingHintBar {
                Section {
                    upcomingScheduledHintRow(viewModel: viewModel)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }

            if !viewModel.visibleUpcomingScheduledRows.isEmpty {
                Section {
                    ForEach(viewModel.visibleUpcomingScheduledRows) { row in
                        transactionRow(row, viewModel: viewModel)
                    }
                } header: {
                    Text(
                        AppLocalization.string(
                            "transaction.schedule.upcoming",
                            defaultValue: "Upcoming"
                        )
                    )
                    .font(.headline)
                    .foregroundStyle(.primary)
                }
            }

            ForEach(viewModel.groupedTransactionRows, id: \.date) { group in
                Section {
                    ForEach(group.rows) { row in
                        transactionRow(row, viewModel: viewModel)
                    }
                } header: {
                    TransactionDateSectionHeader(
                        dateText: formatSectionDate(group.date),
                        weekdayText: formatSectionWeekday(group.date),
                        incomeTotal: group.incomeTotal,
                        expenseTotal: group.expenseTotal,
                        currencyCode: group.currencyCode
                    )
                }
            }
            
            Color.clear
                .frame(height: 80)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    private func upcomingScheduledHintRow(viewModel: TransactionListViewModel) -> some View {
        Button {
            if viewModel.showUpcomingScheduled {
                viewModel.hideUpcomingScheduled()
            } else {
                viewModel.revealUpcomingScheduled()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        AppLocalization.string(
                            "transaction.upcomingHint.title",
                            defaultValue: "Upcoming subscription transactions"
                        )
                    )
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                    Text(upcomingScheduledHintSubtitle(viewModel: viewModel))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(
                    AppLocalization.string(
                        viewModel.showUpcomingScheduled ?
                        "transaction.upcomingHint.action.hide" :
                        "transaction.upcomingHint.action",
                        defaultValue: viewModel.showUpcomingScheduled ? "Hide" : "Show"
                    )
                )
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func upcomingScheduledHintSubtitle(viewModel: TransactionListViewModel) -> String {
        let nextDateText = viewModel.nextUpcomingScheduledDate.map {
            DateFormatterUtility.shared.formatTransactionDate($0)
        } ?? AppLocalization.string("date.today", defaultValue: "Today")

        return AppLocalization.formatted(
            "transaction.upcomingHint.subtitle",
            defaultValue: "%1$lld due in the next %2$lld days • Next %3$@",
            Int64(viewModel.hiddenUpcomingScheduledCount),
            Int64(RecurringTransactionGenerator.defaultLookAheadDays),
            nextDateText
        )
    }

    private func transactionRow(
        _ row: TransactionRowSnapshot,
        viewModel: TransactionListViewModel
    ) -> some View {
        TransactionRowView(snapshot: row)
            .contentShape(Rectangle())
            .onTapGesture {
                openTransactionEditor(for: row.id, viewModel: viewModel)
            }
            .swipeActions(
                edge: .trailing,
                allowsFullSwipe: !row.shouldPromptScheduledDelete
            ) {
                Button {
                    requestDelete(row, viewModel: viewModel)
                } label: {
                    Label(
                        AppLocalization.string("action.delete", defaultValue: "Delete"),
                        systemImage: "trash"
                    )
                }
                .tint(.red)
            }
    }

    private func requestDelete(_ row: TransactionRowSnapshot, viewModel: TransactionListViewModel) {
        if row.shouldPromptScheduledDelete {
            pendingScheduledDeleteTransactionID = row.id
            showScheduledDeleteDialog = true
            return
        }

        if row.isGeneratedFromRecurring,
           viewModel.isSourceRecurringTransaction(transactionId: row.id) {
            pendingSourceDeleteTransactionID = row.id
            showSourceDeleteDialog = true
            return
        }

        Task {
            try? await viewModel.deleteTransaction(transactionId: row.id)
        }
    }

    private func openTransactionEditor(for transactionId: UUID, viewModel: TransactionListViewModel) {
        guard (try? viewModel.transaction(byId: transactionId)) != nil else {
            return
        }
        selectedTransaction = TransactionEditorSelection(id: transactionId)
    }
    
    @ViewBuilder
    private func emptyState(viewModel: TransactionListViewModel) -> some View {
        if viewModel.hasFilters {
            ContentUnavailableView {
                Label(
                    AppLocalization.string("transactions.noResults.title", defaultValue: "No Results"),
                    systemImage: "magnifyingglass"
                )
            } description: {
                Text(AppLocalization.string("transactions.noResults.message", defaultValue: "Try adjusting your filters or search terms."))
            } actions: {
                Button(AppLocalization.string("transactions.clearFilters", defaultValue: "Clear Filters")) {
                    viewModel.clearFilters()
                }
                .buttonStyle(.fluxGlass)
            }
        } else {
            ContentUnavailableView {
                Label(
                    AppLocalization.string("empty.transactions.title", defaultValue: "No Transactions"),
                    systemImage: "tray"
                )
            } description: {
                Text(AppLocalization.string("empty.transactions.message", defaultValue: "Start tracking your finances by adding your first transaction."))
            } actions: {
                if !isSearchContext {
                    Button(AppLocalization.string("empty.transactions.action", defaultValue: "Add Transaction")) {
                        showAddTransaction = true
                    }
                    .buttonStyle(.fluxGlassProminent)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return AppLocalization.string("date.today", defaultValue: "Today")
        } else if calendar.isDateInYesterday(date) {
            return AppLocalization.string("date.yesterday", defaultValue: "Yesterday")
        } else {
            return date.formatted(.dateTime.month().day().year())
        }
    }

    private func formatSectionWeekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide))
    }
}

private struct TransactionDateSectionHeader: View {
    let dateText: String
    let weekdayText: String
    let incomeTotal: Decimal
    let expenseTotal: Decimal
    let currencyCode: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(dateText) · \(weekdayText)")
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .layoutPriority(1)

            Spacer(minLength: 6)

            if let currencyCode {
                HStack(spacing: 8) {
                    Text("+\(CurrencyFormatter.shared.formatCompact(incomeTotal, currencyCode: currencyCode))")
                        .font(.caption)
                        .foregroundStyle(.green)

                    Text("-\(CurrencyFormatter.shared.formatCompact(expenseTotal, currencyCode: currencyCode))")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
        }
        .textCase(nil)
    }
}

struct TransactionEditorSelection: Identifiable, Equatable {
    let id: UUID
}

// MARK: - Transaction Filters Sheet

struct TransactionFiltersSheet: View {
    @Bindable var viewModel: TransactionListViewModel
    @Environment(\.dismiss) private var dismiss
    
    @Query private var accounts: [Account]
    @Query private var categories: [Category]
    
    private var expenseCategories: [Category] {
        categories.filter { $0.type == .expense }
    }
    
    private var incomeCategories: [Category] {
        categories.filter { $0.type == .income }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Account
                Section(AppLocalization.string("filter.account", defaultValue: "Account")) {
                    Picker("", selection: $viewModel.selectedAccount) {
                        Text(AppLocalization.string("filter.allAccounts", defaultValue: "All Accounts"))
                            .tag(nil as Account?)
                        
                        ForEach(accounts) { account in
                            Text(account.name)
                                .tag(account as Account?)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel(AppLocalization.string("filter.account", defaultValue: "Account"))
                }
                
                // Date Range
                Section(AppLocalization.string("filter.dateRange", defaultValue: "Date Range")) {
                    DatePicker(
                        AppLocalization.string("filter.from", defaultValue: "From"),
                        selection: Binding(
                            get: { viewModel.startDate ?? Date.distantPast },
                            set: { viewModel.startDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    
                    DatePicker(
                        AppLocalization.string("filter.to", defaultValue: "To"),
                        selection: Binding(
                            get: { viewModel.endDate ?? Date() },
                            set: { viewModel.endDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    
                    if viewModel.startDate != nil || viewModel.endDate != nil {
                        Button(AppLocalization.string("filter.clearDates", defaultValue: "Clear Dates")) {
                            viewModel.startDate = nil
                            viewModel.endDate = nil
                        }
                        .foregroundStyle(.red)
                    }
                }

                Section {
                    Toggle(
                        AppLocalization.string(
                            "filter.travelTransactions",
                            defaultValue: "Show Foreign Currency Transactions Only"
                        ),
                        isOn: $viewModel.showTravelTransactionsOnly
                    )
                    Toggle(
                        AppLocalization.string(
                            "filter.showUpcomingScheduled",
                            defaultValue: "Include Upcoming Subscriptions"
                        ),
                        isOn: Binding(
                            get: { viewModel.showUpcomingScheduled },
                            set: { newValue in
                                viewModel.showUpcomingScheduled = newValue
                                viewModel.applyFilters()
                            }
                        )
                    )
                } header: {
                    Text(AppLocalization.string("filter.advanced", defaultValue: "Advanced Filters"))
                } footer: {
                    Text(
                        AppLocalization.string(
                            "filter.showUpcomingScheduled.footer",
                            defaultValue: "When turned off, future auto-generated subscription transactions stay hidden."
                        )
                    )
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker(AppLocalization.string("filter.type", defaultValue: "Transaction Type"), selection: $viewModel.selectedType) {
                        Text(AppLocalization.string("filter.all", defaultValue: "All"))
                            .tag(nil as TransactionType?)
                        
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.localizedName)
                                .tag(type as TransactionType?)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }

                ToolbarItem(placement: .cancellationAction) {
                    IconToolbarButton(systemName: "xmark", accessibilityLabel: "Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    IconToolbarButton(systemName: "checkmark", accessibilityLabel: AppLocalization.string("action.apply", defaultValue: "Apply")) {
                        viewModel.applyFilters()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    if viewModel.hasFilters {
                        Button(AppLocalization.string("filter.clearAll", defaultValue: "Clear All Filters")) {
                            viewModel.clearFilters()
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview

#Preview("Transaction List") {
    NavigationStack {
        TransactionListView()
    }
    .modelContainer(for: [Transaction.self, Account.self, Category.self], inMemory: true)
}
