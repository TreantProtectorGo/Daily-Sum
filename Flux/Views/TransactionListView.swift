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
        .navigationTitle(String(localized: "transactions.title", defaultValue: "Transactions"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: viewModel?.hasFilters == true ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
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
            FloatingActionButton {
                showAddTransaction = true
            }
            .accessibilityIdentifier("transactions.addButton")
            .padding(.trailing, 20)
            .padding(.bottom, 20)
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
                                        String(localized: "action.delete", defaultValue: "Delete"),
                                        systemImage: "trash"
                                    )
                                }
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
                    String(localized: "transactions.noResults.title", defaultValue: "No Results"),
                    systemImage: "magnifyingglass"
                )
            } description: {
                Text(String(localized: "transactions.noResults.message", defaultValue: "Try adjusting your filters or search terms."))
            } actions: {
                Button(String(localized: "transactions.clearFilters", defaultValue: "Clear Filters")) {
                    viewModel.clearFilters()
                }
                .buttonStyle(.fluxGlass)
            }
        } else {
            ContentUnavailableView {
                Label(
                    String(localized: "empty.transactions.title", defaultValue: "No Transactions"),
                    systemImage: "tray"
                )
            } description: {
                Text(String(localized: "empty.transactions.message", defaultValue: "Start tracking your finances by adding your first transaction."))
            } actions: {
                Button(String(localized: "empty.transactions.action", defaultValue: "Add Transaction")) {
                    showAddTransaction = true
                }
                .buttonStyle(.fluxGlassProminent)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return String(localized: "date.today", defaultValue: "Today")
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "date.yesterday", defaultValue: "Yesterday")
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
                // Transaction Type
                Section(String(localized: "filter.type", defaultValue: "Transaction Type")) {
                    Picker(String(localized: "filter.type", defaultValue: "Type"), selection: $viewModel.selectedType) {
                        Text(String(localized: "filter.all", defaultValue: "All"))
                            .tag(nil as TransactionType?)
                        
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.localizedName)
                                .tag(type as TransactionType?)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Account
                Section(String(localized: "filter.account", defaultValue: "Account")) {
                    Picker(String(localized: "filter.account", defaultValue: "Account"), selection: $viewModel.selectedAccount) {
                        Text(String(localized: "filter.all", defaultValue: "All"))
                            .tag(nil as Account?)
                        
                        ForEach(accounts) { account in
                            Text(account.name)
                                .tag(account as Account?)
                        }
                    }
                }
                
                // Date Range
                Section(String(localized: "filter.dateRange", defaultValue: "Date Range")) {
                    DatePicker(
                        String(localized: "filter.from", defaultValue: "From"),
                        selection: Binding(
                            get: { viewModel.startDate ?? Date.distantPast },
                            set: { viewModel.startDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    
                    DatePicker(
                        String(localized: "filter.to", defaultValue: "To"),
                        selection: Binding(
                            get: { viewModel.endDate ?? Date() },
                            set: { viewModel.endDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    
                    if viewModel.startDate != nil || viewModel.endDate != nil {
                        Button(String(localized: "filter.clearDates", defaultValue: "Clear Dates")) {
                            viewModel.startDate = nil
                            viewModel.endDate = nil
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "filter.title", defaultValue: "Filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel", defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.apply", defaultValue: "Apply")) {
                        viewModel.applyFilters()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    if viewModel.hasFilters {
                        Button(String(localized: "filter.clearAll", defaultValue: "Clear All Filters")) {
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
