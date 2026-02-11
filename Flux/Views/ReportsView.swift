import SwiftUI
import SwiftData

enum ReportsTab: String, CaseIterable, Identifiable {
    case reports
    case budgets
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .reports:
            String(localized: "reports.tab.reports", defaultValue: "Reports")
        case .budgets:
            String(localized: "reports.tab.budgets", defaultValue: "Budgets")
        }
    }
    
    var icon: String {
        switch self {
        case .reports: "chart.bar.fill"
        case .budgets: "chart.pie.fill"
        }
    }
}

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: ReportsTab = .reports
    @State private var reportsViewModel: ReportsViewModel?
    @State private var budgetViewModel: BudgetListViewModel?
    @State private var showAddBudget = false
    @State private var selectedBudget: Budget?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                tabContent
            }
            .navigationTitle(String(localized: "reports.title", defaultValue: "Reports"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(String(localized: "tab.settings", defaultValue: "Settings"))
                }
            }
            .task {
                if reportsViewModel == nil {
                    reportsViewModel = ReportsViewModel(modelContext: modelContext)
                }
                if budgetViewModel == nil {
                    budgetViewModel = BudgetListViewModel(modelContext: modelContext)
                }
                await reportsViewModel?.loadReports()
                await budgetViewModel?.loadBudgets()
            }
            .refreshable {
                if selectedTab == .reports {
                    await reportsViewModel?.loadReports()
                } else {
                    await budgetViewModel?.loadBudgets()
                }
            }
            .sheet(isPresented: $showAddBudget) {
                BudgetEntrySheet(onSave: {
                    Task { await budgetViewModel?.loadBudgets() }
                })
            }
            .sheet(item: $selectedBudget) { budget in
                BudgetEntrySheet(budget: budget, onSave: {
                    Task { await budgetViewModel?.loadBudgets() }
                })
            }
            .overlay(alignment: .bottomTrailing) {
                if selectedTab == .budgets {
                    FloatingActionButton {
                        showAddBudget = true
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    @ViewBuilder
    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(ReportsTab.allCases) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .reports:
            if let viewModel = reportsViewModel {
                reportsContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .budgets:
            if let viewModel = budgetViewModel {
                budgetContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    @ViewBuilder
    private func reportsContent(viewModel: ReportsViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                periodSelector(viewModel: viewModel)
                
                summarySection(viewModel: viewModel)
                
                if !viewModel.expensesByCategory.isEmpty {
                    categoryBreakdownSection(
                        title: String(localized: "reports.expensesByCategory", defaultValue: "Expenses by Category"),
                        categories: viewModel.expensesByCategory,
                        total: viewModel.totalExpenses
                    )
                }
                
                if !viewModel.incomeByCategory.isEmpty {
                    categoryBreakdownSection(
                        title: String(localized: "reports.incomeByCategory", defaultValue: "Income by Category"),
                        categories: viewModel.incomeByCategory,
                        total: viewModel.totalIncome
                    )
                }
                
                if !viewModel.monthlyTrends.isEmpty {
                    monthlyTrendsSection(viewModel: viewModel)
                }
                
                if viewModel.expensesByCategory.isEmpty && viewModel.incomeByCategory.isEmpty {
                    EmptyStateView.noDataForPeriod()
                        .padding(.top, 40)
                }
            }
            .padding()
            .glassContainer(spacing: 20)
        }
    }
    
    @ViewBuilder
    private func budgetContent(viewModel: BudgetListViewModel) -> some View {
        if viewModel.budgets.isEmpty {
            budgetEmptyState
        } else {
            List {
                budgetSummaryCard(viewModel: viewModel)
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                if !viewModel.activeBudgets.isEmpty {
                    budgetSection(
                        title: String(localized: "budgets.active", defaultValue: "Active Budgets"),
                        budgets: viewModel.activeBudgets,
                        viewModel: viewModel
                    )
                }

                if !viewModel.inactiveBudgets.isEmpty {
                    budgetSection(
                        title: String(localized: "budgets.inactive", defaultValue: "Inactive Budgets"),
                        budgets: viewModel.inactiveBudgets,
                        viewModel: viewModel
                    )
                }

                Color.clear
                    .frame(height: 80)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func periodSelector(viewModel: ReportsViewModel) -> some View {
        Picker("", selection: periodSelectionBinding(viewModel: viewModel)) {
            ForEach([
                ReportsViewModel.ReportPeriod.month,
                ReportsViewModel.ReportPeriod.quarter,
                ReportsViewModel.ReportPeriod.year,
                ReportsViewModel.ReportPeriod.all
            ], id: \.id) { period in
                Text(period.localizedName).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private func periodSelectionBinding(viewModel: ReportsViewModel) -> Binding<ReportsViewModel.ReportPeriod> {
        let supportedPeriods: Set<ReportsViewModel.ReportPeriod> = [.month, .quarter, .year, .all]
        
        return Binding(
            get: {
                if supportedPeriods.contains(viewModel.selectedPeriod) {
                    return viewModel.selectedPeriod
                }
                return .month
            },
            set: { newPeriod in
                viewModel.selectedPeriod = newPeriod
                Task { await viewModel.loadReports() }
            }
        )
    }
    
    @ViewBuilder
    private func summarySection(viewModel: ReportsViewModel) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                GlassCard(cornerRadius: 16, padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(AppColors.income)
                            Text(String(localized: "reports.totalIncome", defaultValue: "Total Income"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(currency: viewModel.totalIncome, code: SupportedCurrency.defaultFromLocale.rawValue)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GlassCard(cornerRadius: 16, padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(AppColors.expense)
                            Text(String(localized: "reports.totalExpenses", defaultValue: "Total Expenses"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(currency: viewModel.totalExpenses, code: SupportedCurrency.defaultFromLocale.rawValue)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            HStack(spacing: 12) {
                GlassCard(cornerRadius: 16, padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "reports.netIncome", defaultValue: "Net Income"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        AmountText(
                            viewModel.netIncome,
                            currencyCode: SupportedCurrency.defaultFromLocale.rawValue,
                            showSign: true,
                            font: .title3,
                            fontWeight: .bold
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GlassCard(cornerRadius: 16, padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "reports.savingsRate", defaultValue: "Savings Rate"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(viewModel.savingsRate, format: .number.precision(.fractionLength(1)))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(viewModel.savingsRate >= 0 ? AppColors.income : AppColors.expense)
                            Text("%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    @ViewBuilder
    private func categoryBreakdownSection(
        title: String,
        categories: [ReportsViewModel.CategorySummary],
        total: Decimal
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            GlassCard(cornerRadius: 16, padding: 16) {
                VStack(spacing: 16) {
                    ForEach(categories.prefix(5)) { category in
                        CategoryBreakdownRow(
                            category: category,
                            currencyCode: SupportedCurrency.defaultFromLocale.rawValue
                        )
                    }
                    
                    if categories.count > 5 {
                        HStack {
                            Text("And \(categories.count - 5) more...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func monthlyTrendsSection(viewModel: ReportsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "reports.monthlyTrends", defaultValue: "Monthly Trends"))
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            GlassCard(cornerRadius: 16, padding: 16) {
                VStack(spacing: 12) {
                    ForEach(viewModel.monthlyTrends.suffix(6)) { trend in
                        MonthlyTrendRow(
                            trend: trend,
                            currencyCode: SupportedCurrency.defaultFromLocale.rawValue
                        )
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func budgetSummaryCard(viewModel: BudgetListViewModel) -> some View {
        GlassCard(cornerRadius: 20, padding: 20) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "budgets.totalSpent", defaultValue: "Total Spent"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(CurrencyFormatter.shared.format(viewModel.totalSpent, currencyCode: SupportedCurrency.defaultFromLocale.rawValue))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(localized: "budgets.totalBudget", defaultValue: "Total Budget"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(CurrencyFormatter.shared.format(viewModel.totalBudgeted, currencyCode: SupportedCurrency.defaultFromLocale.rawValue))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.budgetProgressColor(for: viewModel.overallProgress))
                            .frame(width: min(geometry.size.width * CGFloat(viewModel.overallProgress), geometry.size.width))
                    }
                }
                .frame(height: 12)
                
                HStack {
                    budgetStatBadge(
                        value: viewModel.budgetsOverLimit,
                        label: String(localized: "budgets.overLimit", defaultValue: "Over Limit"),
                        color: AppColors.budgetDanger
                    )
                    
                    Spacer()
                    
                    budgetStatBadge(
                        value: viewModel.budgetsNearLimit,
                        label: String(localized: "budgets.nearLimit", defaultValue: "Near Limit"),
                        color: AppColors.budgetWarning
                    )
                    
                    Spacer()
                    
                    budgetStatBadge(
                        value: viewModel.activeBudgets.count - viewModel.budgetsOverLimit - viewModel.budgetsNearLimit,
                        label: String(localized: "budgets.onTrack", defaultValue: "On Track"),
                        color: AppColors.budgetSafe
                    )
                }
            }
        }
    }
    
    private func budgetStatBadge(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private func budgetSection(title: String, budgets: [Budget], viewModel: BudgetListViewModel) -> some View {
        Section {
            ForEach(budgets) { budget in
                BudgetRowCard(
                    budget: budget,
                    onTap: { selectedBudget = budget },
                    onToggleActive: {
                        Task { try? await viewModel.toggleBudgetActive(budget) }
                    },
                    onDelete: {
                        Task { try? await viewModel.deleteBudget(budget) }
                    }
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { try? await viewModel.deleteBudget(budget) }
                    } label: {
                        Label(
                            String(localized: "action.delete", defaultValue: "Delete"),
                            systemImage: "trash"
                        )
                    }
                    .tint(.red)
                }
            }
        } header: {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var budgetEmptyState: some View {
        ContentUnavailableView {
            Label(
                String(localized: "empty.budgets.title", defaultValue: "No Budgets"),
                systemImage: "chart.pie"
            )
        } description: {
            Text(String(localized: "empty.budgets.message", defaultValue: "Create budgets to track your spending goals."))
        } actions: {
            Button(String(localized: "empty.budgets.action", defaultValue: "Create Budget")) {
                showAddBudget = true
            }
            .buttonStyle(.fluxGlassProminent)
        }
    }
}

struct CategoryBreakdownRow: View {
    let category: ReportsViewModel.CategorySummary
    let currencyCode: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(category.color)
                    .frame(width: 12, height: 12)
                
                Text(category.categoryName)
                    .font(.subheadline)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(currency: category.amount, code: currencyCode)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(category.percentage, format: .number.precision(.fractionLength(1)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    + Text("%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(category.color)
                        .frame(width: geometry.size.width * CGFloat(category.percentage / 100))
                }
            }
            .frame(height: 4)
        }
    }
}

struct MonthlyTrendRow: View {
    let trend: ReportsViewModel.MonthlyTrend
    let currencyCode: String
    
    @Environment(\.regionalSettings) private var regionalSettings
    
    var body: some View {
        HStack {
            Text(trend.month.formatted(.dateTime.month(.abbreviated).year()))
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(currency: trend.income, code: currencyCode)
                    .font(.caption)
                    .foregroundStyle(AppColors.income)
                Text(String(localized: "reports.income", defaultValue: "Income"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(currency: trend.expenses, code: currencyCode)
                    .font(.caption)
                    .foregroundStyle(AppColors.expense)
                Text(String(localized: "reports.expenses", defaultValue: "Expenses"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80)
            
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(
                    trend.net,
                    currencyCode: currencyCode,
                    showSign: true,
                    font: .caption,
                    fontWeight: .semibold
                )
                Text(String(localized: "reports.net", defaultValue: "Net"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 70)
        }
    }
}

struct BudgetRowCard: View {
    let budget: Budget
    let onTap: () -> Void
    let onToggleActive: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let category = budget.category {
                        CategoryIcon(category: category, size: .small)
                        Text(category.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Image(systemName: "chart.pie.fill")
                            .foregroundStyle(.secondary)
                        Text(String(localized: "budget.allCategories", defaultValue: "All Categories"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Text(budget.period.localizedName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                    
                    if !budget.isActive {
                        Image(systemName: "pause.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                
                BudgetProgressView(
                    budget: budget,
                    showsCategoryHeader: false,
                    isCompact: true
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(12)
        }
        .buttonStyle(.plain)
        .glassBackground(cornerRadius: 14, isInteractive: true)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label(
                    String(localized: "action.edit", defaultValue: "Edit"),
                    systemImage: "pencil"
                )
            }
            
            Button {
                onToggleActive()
            } label: {
                Label(
                    budget.isActive
                        ? String(localized: "action.deactivate", defaultValue: "Deactivate")
                        : String(localized: "action.activate", defaultValue: "Activate"),
                    systemImage: budget.isActive ? "pause.circle" : "play.circle"
                )
            }
            
            Divider()
            
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(
                    String(localized: "action.delete", defaultValue: "Delete"),
                    systemImage: "trash"
                )
            }
        }
        .confirmationDialog(
            String(localized: "budget.deleteConfirmation.title", defaultValue: "Delete Budget?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "action.delete", defaultValue: "Delete"), role: .destructive) {
                onDelete()
            }
        } message: {
            Text(String(localized: "budget.deleteConfirmation.message", defaultValue: "This action cannot be undone."))
        }
    }
}

#Preview("Reports") {
    do {
        let container = try ModelContainerConfiguration.createPreviewContainer()
        return ReportsView()
            .modelContainer(container)
    } catch {
        return Text("Preview Error")
    }
}
