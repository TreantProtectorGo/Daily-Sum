import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TransactionListViewModel?
    
    private let filterAccount: Account?
    private let externalSearchText: Binding<String>?
    
    @State private var showAddTransaction = false
    @State private var selectedTransaction: Transaction?
    @State private var showFilters = false
    
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
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .accessibilityLabel(AppLocalization.string("action.filters", defaultValue: "Filters"))
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView(autoPopWhenTabSwitch: true)
                } label: {
                    Image(systemName: "gear")
                }
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
        .sheet(item: $selectedTransaction) { transaction in
            TransactionEntrySheet(transaction: transaction, onSave: {
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
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private func transactionContent(viewModel: TransactionListViewModel) -> some View {
        if viewModel.filteredTransactions.isEmpty {
            emptyState(viewModel: viewModel)
        } else {
            transactionList(viewModel: viewModel)
        }
    }
    
    @ViewBuilder
    private func transactionList(viewModel: TransactionListViewModel) -> some View {
        List {
            ForEach(viewModel.groupedTransactions, id: \.date) { group in
                Section {
                    ForEach(group.transactions) { transaction in
                        TransactionRowView(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTransaction = transaction
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        try? await viewModel.deleteTransaction(transaction)
                                    }
                                } label: {
                                    Label(
                                        AppLocalization.string("action.delete", defaultValue: "Delete"),
                                        systemImage: "trash"
                                    )
                                }
                                .tint(.red)
                            }
                    }
                } header: {
                    Text(formatSectionDate(group.date))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
            
            Color.clear
                .frame(height: 80)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
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
                    Picker(AppLocalization.string("filter.account", defaultValue: "Account"), selection: $viewModel.selectedAccount) {
                        Text(AppLocalization.string("filter.all", defaultValue: "All"))
                            .tag(nil as Account?)
                        
                        ForEach(accounts) { account in
                            Text(account.name)
                                .tag(account as Account?)
                        }
                    }
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(AppLocalization.string("action.cancel", defaultValue: "Cancel"))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        viewModel.applyFilters()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(AppLocalization.string("action.apply", defaultValue: "Apply"))
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
