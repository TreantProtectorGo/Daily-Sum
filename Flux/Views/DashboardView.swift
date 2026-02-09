import SwiftUI
import SwiftData

// MARK: - Dashboard View

/// Main dashboard screen showing financial overview
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    
    @State private var showAddTransaction = false
    @State private var showAddAccount = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let viewModel {
                        // Total Balance Card
                        balanceCard(viewModel: viewModel)
                        
                        // Monthly Summary
                        monthlySummarySection(viewModel: viewModel)
                        
                        // Accounts Section
                        accountsSection(viewModel: viewModel)
                        
                        // Recent Transactions Section
                        recentTransactionsSection(viewModel: viewModel)
                        
                        // Budget Overview Section
                        budgetOverviewSection(viewModel: viewModel)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "dashboard.title", defaultValue: "Dashboard"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    addMenu
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
        }
    }
    
    // MARK: - Balance Card
    
    @ViewBuilder
    private func balanceCard(viewModel: DashboardViewModel) -> some View {
        GlassCard(cornerRadius: 20, padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "dashboard.totalBalance", defaultValue: "Total Balance"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(currency: viewModel.totalBalance, code: viewModel.defaultCurrencyCode)
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
                        Text(String(localized: "dashboard.income", defaultValue: "Income"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    AmountText(
                        viewModel.monthlyIncome,
                        currencyCode: viewModel.defaultCurrencyCode,
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
                        Text(String(localized: "dashboard.expenses", defaultValue: "Expenses"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    AmountText(
                        -viewModel.monthlyExpenses,
                        currencyCode: viewModel.defaultCurrencyCode,
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
                String(localized: "dashboard.accounts", defaultValue: "Accounts"),
                systemImage: "building.columns"
            )
            
            if viewModel.hasAccounts {
                VStack(spacing: 8) {
                    ForEach(viewModel.accounts.prefix(3)) { account in
                        AccountRowView(account: account)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .glassBackground(cornerRadius: 12, isInteractive: true)
                    }
                    
                    if viewModel.accounts.count > 3 {
                        NavigationLink {
                            // TODO: Full accounts list
                            Text("All Accounts")
                        } label: {
                            HStack {
                                Text(String(localized: "dashboard.viewAll", defaultValue: "View All"))
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
                    title: String(localized: "empty.accounts.title", defaultValue: "No Accounts"),
                    message: String(localized: "empty.accounts.message", defaultValue: "Add your accounts to start managing your finances."),
                    systemImage: "building.columns",
                    actionTitle: String(localized: "empty.accounts.action", defaultValue: "Add Account")
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
                String(localized: "dashboard.recentTransactions", defaultValue: "Recent Transactions"),
                systemImage: "clock"
            )
            
            if viewModel.hasTransactions {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentTransactions.prefix(5)) { transaction in
                        GlassTransactionRow(transaction: transaction)
                    }
                    
                    if viewModel.recentTransactions.count > 5 {
                        NavigationLink {
                            TransactionListView()
                        } label: {
                            HStack {
                                Text(String(localized: "dashboard.viewAll", defaultValue: "View All"))
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
                    title: String(localized: "empty.transactions.title", defaultValue: "No Transactions"),
                    message: String(localized: "empty.transactions.message", defaultValue: "Start tracking your finances by adding your first transaction."),
                    systemImage: "tray",
                    actionTitle: String(localized: "empty.transactions.action", defaultValue: "Add Transaction")
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
                String(localized: "dashboard.budgets", defaultValue: "Budgets"),
                systemImage: "chart.pie"
            )
            
            if viewModel.hasBudgets {
                VStack(spacing: 8) {
                    ForEach(viewModel.topBudgets) { budget in
                        BudgetCard(budget: budget)
                    }
                    
                    HStack {
                        Text(String(localized: "dashboard.viewAllInReports", defaultValue: "View all in Reports tab"))
                        Image(systemName: "arrow.right")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
                }
            } else {
                GlassEmptyState(
                    title: String(localized: "empty.budgets.title", defaultValue: "No Budgets"),
                    message: String(localized: "empty.budgets.message", defaultValue: "Create budgets to track your spending goals."),
                    systemImage: "chart.pie",
                    actionTitle: String(localized: "empty.budgets.action", defaultValue: "Create Budget")
                ) {
                    // TODO: Show add budget sheet
                }
            }
        }
    }
    
    // MARK: - Add Menu
    
    private var addMenu: some View {
        Menu {
            Button {
                showAddTransaction = true
            } label: {
                Label(
                    String(localized: "action.addTransaction", defaultValue: "Add Transaction"),
                    systemImage: "plus.circle"
                )
            }
            
            Button {
                showAddAccount = true
            } label: {
                Label(
                    String(localized: "action.addAccount", defaultValue: "Add Account"),
                    systemImage: "building.columns"
                )
            }
        } label: {
            Image(systemName: "plus")
        }
    }
}

// MARK: - Preview

#Preview("Dashboard") {
    do {
        let container = try ModelContainerConfiguration.createPreviewContainer()
        return DashboardView()
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
