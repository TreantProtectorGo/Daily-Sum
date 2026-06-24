import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    @AppStorage(UserCurrencyPreference.storageKey) private var preferredCurrencyCode = UserCurrencyPreference.resolvedCurrencyCode
    let onViewAllTransactions: (() -> Void)?
    let onViewAllBudgets: (() -> Void)?
    
    @State private var showAddTransaction = false
    @State private var showAddAccount = false
    @State private var showAddBudget = false
    @State private var selectedAccount: Account?
    @State private var selectedTransaction: TransactionEditorSelection?
    @State private var selectedBudget: Budget?

    init(
        onViewAllTransactions: (() -> Void)? = nil,
        onViewAllBudgets: (() -> Void)? = nil
    ) {
        self.onViewAllTransactions = onViewAllTransactions
        self.onViewAllBudgets = onViewAllBudgets
    }

    private var displayCurrencyCode: String {
        UserCurrencyPreference.resolvedDisplayCurrencyCode(
            preferredCurrencyCode: preferredCurrencyCode
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let viewModel {
                        BalanceOverviewCard(
                            totalBalance: viewModel.totalBalance,
                            accountCount: viewModel.accounts.count,
                            hasAccounts: viewModel.hasAccounts,
                            currencyCode: displayCurrencyCode
                        )
                        
                        accountsSection(viewModel: viewModel)
                        
                        recentTransactionsSection(viewModel: viewModel)
                        
                        budgetOverviewSection(viewModel: viewModel)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
                .padding(.bottom, 80)
            }
            .navigationTitle(AppLocalization.string("dashboard.title", defaultValue: "主頁"))
            .toolbar {
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
            .refreshable {
                await viewModel?.refresh()
            }
            .task {
                if viewModel == nil {
                    viewModel = DashboardViewModel(modelContext: modelContext)
                }
                await viewModel?.loadData()
            }
            .onChange(of: preferredCurrencyCode) { _, _ in
                Task {
                    await viewModel?.loadData()
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                TransactionEntrySheet(onSave: {
                    Task { await viewModel?.refresh() }
                })
            }
            .sheet(isPresented: $showAddAccount) {
                AccountEntrySheet(onSave: {
                    Task { await viewModel?.refresh() }
                })
            }
            .sheet(item: $selectedAccount) { account in
                AccountEntrySheet(account: account, onSave: {
                    Task { await viewModel?.refresh() }
                })
            }
            .sheet(item: $selectedTransaction) { selection in
                TransactionEntrySheet(transactionId: selection.id, onSave: {
                    Task { await viewModel?.refresh() }
                })
            }
            .sheet(item: $selectedBudget) { budget in
                BudgetEntrySheet(budget: budget, onSave: {
                    Task { await viewModel?.refresh() }
                })
            }
            .sheet(isPresented: $showAddBudget) {
                BudgetEntrySheet(onSave: {
                    Task { await viewModel?.refresh() }
                })
            }
            .overlay(alignment: .bottomTrailing) {
                ExpandableFAB(items: [
                    .init(
                        label: AppLocalization.string("action.addTransaction", defaultValue: "Transaction"),
                        systemImage: "plus.circle"
                    ) {
                        showAddTransaction = true
                    },
                    .init(
                        label: AppLocalization.string("action.addAccount", defaultValue: "Account"),
                        systemImage: "building.columns"
                    ) {
                        showAddAccount = true
                    }
                ])
                .padding(.trailing, 25)
                .padding(.bottom, 20)
            }
        }
    }
    // MARK: - Accounts Section
    
    @ViewBuilder
    private func accountsSection(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            accountsSectionHeader(viewModel: viewModel)
            
            if viewModel.hasAccounts {
                VStack(spacing: 8) {
                    ForEach(viewModel.accounts.prefix(3)) { account in
                        GlassAccountRow(account: account) {
                            selectedAccount = account
                        }
                    }
                }
            } else {
                GlassEmptyState(
                    title: AppLocalization.string("empty.accounts.title", defaultValue: "No Accounts"),
                    message: AppLocalization.string("empty.accounts.message", defaultValue: "Add your accounts to start managing your finances."),
                    systemImage: "building.columns",
                    actionTitle: AppLocalization.string("empty.accounts.action", defaultValue: "Add Account")
                ) {
                    showAddAccount = true
                }
            }
        }
    }

    @ViewBuilder
    private func accountsSectionHeader(viewModel: DashboardViewModel) -> some View {
        GlassSectionHeader(
            AppLocalization.string("dashboard.accounts", defaultValue: "Accounts"),
            systemImage: "building.columns"
        ) {
            if viewModel.accounts.count > 3 {
                NavigationLink {
                    AccountsListView {
                        Task { await viewModel.refresh() }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(AppLocalization.string("dashboard.viewAll", defaultValue: "View All"))
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("dashboard.accounts.viewAll")
            }
        }
    }
    
    // MARK: - Recent Transactions Section
    
    @ViewBuilder
    private func recentTransactionsSection(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassSectionHeader(
                AppLocalization.string("dashboard.recentTransactions", defaultValue: "Recent Transactions"),
                systemImage: "clock"
            )
            
            if viewModel.hasTransactions {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentTransactionRows.prefix(5)) { row in
                        GlassTransactionRow(snapshot: row) {
                            selectedTransaction = TransactionEditorSelection(id: row.id)
                        }
                    }
                    
                    if viewModel.recentTransactionRows.count > 5 {
                        if let onViewAllTransactions {
                            DashboardViewAllFooterLink(action: onViewAllTransactions)
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("dashboard.recentTransactions.viewAll")
                            .padding(.top, 4)
                        } else {
                            NavigationLink {
                                TransactionListView()
                            } label: {
                                DashboardViewAllFooterLabel()
                            }
                            .accessibilityIdentifier("dashboard.recentTransactions.viewAll")
                            .padding(.top, 4)
                        }
                    }
                }
            } else {
                GlassEmptyState(
                    title: AppLocalization.string("empty.transactions.title", defaultValue: "No Transactions"),
                    message: AppLocalization.string("empty.transactions.message", defaultValue: "Start tracking your finances by adding your first transaction."),
                    systemImage: "tray",
                    actionTitle: AppLocalization.string("empty.transactions.action", defaultValue: "Add Transaction")
                ) {
                    showAddTransaction = true
                }
            }
        }
    }

    // MARK: - Budget Overview Section
    
    @ViewBuilder
    private func budgetOverviewSection(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassSectionHeader(
                AppLocalization.string("dashboard.budgets", defaultValue: "Budgets"),
                systemImage: "chart.pie"
            )
            
            if viewModel.hasBudgets {
                VStack(spacing: 8) {
                    ForEach(viewModel.topBudgets) { budget in
                        BudgetCard(budget: budget) {
                            selectedBudget = budget
                        }
                    }
                    
                    if let onViewAllBudgets {
                        DashboardViewAllFooterLink(action: onViewAllBudgets)
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("dashboard.budgets.viewAll")
                            .padding(.top, 4)
                    } else {
                        NavigationLink {
                            ReportsView(initialTab: .budgets, showsTabPicker: false)
                        } label: {
                            DashboardViewAllFooterLabel()
                        }
                        .accessibilityIdentifier("dashboard.budgets.viewAll")
                        .padding(.top, 4)
                    }
                }
            } else {
                GlassEmptyState(
                    title: AppLocalization.string("empty.budgets.title", defaultValue: "No Budgets"),
                    message: AppLocalization.string("empty.budgets.message", defaultValue: "Create budgets to track your spending goals."),
                    systemImage: "chart.pie",
                    actionTitle: AppLocalization.string("empty.budgets.action", defaultValue: "Create Budget")
                ) {
                    showAddBudget = true
                }
            }
        }
    }
}

private struct DashboardViewAllFooterLink: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DashboardViewAllFooterLabel()
        }
    }
}

private struct DashboardViewAllFooterLabel: View {
    var body: some View {
        HStack {
            Text(AppLocalization.string("dashboard.viewAll", defaultValue: "View All"))
            Image(systemName: "chevron.right")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

#Preview("Dashboard") {
    do {
        let container = try ModelContainerConfiguration.createPreviewContainer()
        return DashboardView()
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
