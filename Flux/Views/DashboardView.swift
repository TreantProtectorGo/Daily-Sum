import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    @AppStorage(UserCurrencyPreference.storageKey) private var preferredCurrencyCode = UserCurrencyPreference.resolvedCurrencyCode
    
    @State private var showAddTransaction = false
    @State private var showAddAccount = false
    @State private var showAddBudget = false
    @State private var selectedAccount: Account?
    @State private var selectedTransaction: TransactionEditorSelection?
    @State private var selectedBudget: Budget?

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
                        balanceCard(viewModel: viewModel)
                        
                        monthlySummarySection(viewModel: viewModel)
                        
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
            .navigationTitle(AppLocalization.string("dashboard.title", defaultValue: "Dashboard"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(autoPopWhenTabSwitch: true)
                    } label: {
                        Image(systemName: "gear")
                    }
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
    
    // MARK: - Balance Card
    
    @ViewBuilder
    private func balanceCard(viewModel: DashboardViewModel) -> some View {
        GlassCard(cornerRadius: 20, padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text(AppLocalization.string("dashboard.totalBalance", defaultValue: "Total Balance"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(currency: viewModel.totalBalance, code: displayCurrencyCode)
                    .font(.system(size: 36, weight: .bold))
                
                if viewModel.hasAccounts {
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns.fill")
                            .font(.caption)
                        Text("\(viewModel.accounts.count) accounts")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Monthly Summary
    
    @ViewBuilder
    private func monthlySummarySection(viewModel: DashboardViewModel) -> some View {
        HStack(spacing: 12) {
            // Income
            GlassCard(cornerRadius: 16, padding: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(AppColors.income)
                        Text(AppLocalization.string("dashboard.income", defaultValue: "Income"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    AmountText(
                        viewModel.monthlyIncome,
                        currencyCode: displayCurrencyCode,
                        font: .title3,
                        fontWeight: .semibold
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Expenses
            GlassCard(cornerRadius: 16, padding: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(AppColors.expense)
                        Text(AppLocalization.string("dashboard.expenses", defaultValue: "Expenses"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    AmountText(
                        -viewModel.monthlyExpenses,
                        currencyCode: displayCurrencyCode,
                        font: .title3,
                        fontWeight: .semibold
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    // MARK: - Accounts Section
    
    @ViewBuilder
    private func accountsSection(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassSectionHeader(
                AppLocalization.string("dashboard.accounts", defaultValue: "Accounts"),
                systemImage: "building.columns"
            )
            
            if viewModel.hasAccounts {
                VStack(spacing: 8) {
                    ForEach(viewModel.accounts.prefix(3)) { account in
                        GlassAccountRow(account: account) {
                                selectedAccount = account
                        }
                    }
                    
                    if viewModel.accounts.count > 3 {
                        NavigationLink {
                            // TODO: Full accounts list
                            Text("All Accounts")
                        } label: {
                            HStack {
                                Text(AppLocalization.string("dashboard.viewAll", defaultValue: "View All"))
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
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
                        NavigationLink {
                            TransactionListView()
                        } label: {
                            HStack {
                                Text(AppLocalization.string("dashboard.viewAll", defaultValue: "View All"))
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
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
                    
                    HStack {
                        Text(AppLocalization.string("dashboard.viewAllInReports", defaultValue: "View all in Reports tab"))
                        Image(systemName: "arrow.right")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
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

#Preview("Dashboard") {
    do {
        let container = try ModelContainerConfiguration.createPreviewContainer()
        return DashboardView()
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
