import SwiftUI
import SwiftData
import Charts

enum ReportsTab: String, CaseIterable, Identifiable {
    case reports
    case budgets
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .reports:
            AppLocalization.string("reports.tab.reports", defaultValue: "Reports")
        case .budgets:
            AppLocalization.string("reports.tab.budgets", defaultValue: "Budgets")
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
    @AppStorage(UserCurrencyPreference.storageKey) private var preferredCurrencyCode = UserCurrencyPreference.resolvedCurrencyCode
    @AppStorage(ReportsCategoryRowLimitPreference.storageKey) private var categoryRowLimit = ReportsCategoryRowLimitPreference.defaultValue
    @State private var selectedTab: ReportsTab = .reports
    private let showsTabPicker: Bool
    @State private var reportsViewModel: ReportsViewModel?
    @State private var budgetViewModel: BudgetListViewModel?
    @State private var showAddBudget = false
    @State private var selectedBudget: Budget?
    @State private var selectedCategoryBreakdownType: ReportsViewModel.CategoryBreakdownType = .expense
    @State private var isCategoryRowsExpanded = false

    private var displayCurrencyCode: String {
        UserCurrencyPreference.resolvedDisplayCurrencyCode(
            preferredCurrencyCode: preferredCurrencyCode
        )
    }

    init(initialTab: ReportsTab = .reports, showsTabPicker: Bool = true) {
        _selectedTab = State(initialValue: initialTab)
        self.showsTabPicker = showsTabPicker
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showsTabPicker {
                    tabPicker
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
                tabContent
            }
            .navigationTitle(
                selectedTab == .budgets
                    ? AppLocalization.string("reports.tab.budgets", defaultValue: "Budgets")
                    : AppLocalization.string("reports.title", defaultValue: "Reports")
            )
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
            .onChange(of: preferredCurrencyCode) { _, _ in
                Task {
                    await reportsViewModel?.loadReports()
                    await budgetViewModel?.loadBudgets()
                }
            }
            .onChange(of: selectedCategoryBreakdownType) { _, _ in
                isCategoryRowsExpanded = false
            }
            .onChange(of: categoryRowLimit) { _, newValue in
                let normalized = ReportsCategoryRowLimitPreference.normalized(newValue)
                if normalized != newValue {
                    categoryRowLimit = normalized
                }
                isCategoryRowsExpanded = false
            }
            .onChange(of: reportsViewModel?.selectedPeriod) { _, _ in
                isCategoryRowsExpanded = false
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
                    .padding(.trailing, 25)
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

                let availableBreakdowns = ReportsViewModel.availableCategoryBreakdownTypes(
                    expenseCategories: viewModel.expensesByCategory,
                    incomeCategories: viewModel.incomeByCategory
                )

                if !availableBreakdowns.isEmpty {
                    categoryBreakdownSection(viewModel: viewModel)
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
                        title: AppLocalization.string("budgets.list", defaultValue: "Budgets"),
                        budgets: viewModel.activeBudgets,
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
                            Text(AppLocalization.string("reports.totalIncome", defaultValue: "Total Income"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(currency: viewModel.totalIncome, code: displayCurrencyCode)
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
                            Text(AppLocalization.string("reports.totalExpenses", defaultValue: "Total Expenses"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(currency: viewModel.totalExpenses, code: displayCurrencyCode)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            HStack(spacing: 12) {
                GlassCard(cornerRadius: 16, padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppLocalization.string("reports.netIncome", defaultValue: "Net Income"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        AmountText(
                            viewModel.netIncome,
                            currencyCode: displayCurrencyCode,
                            showSign: true,
                            font: .title3,
                            fontWeight: .bold
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GlassCard(cornerRadius: 16, padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppLocalization.string("reports.savingsRate", defaultValue: "Savings Rate"))
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
        viewModel: ReportsViewModel
    ) -> some View {
        let availableBreakdowns = ReportsViewModel.availableCategoryBreakdownTypes(
            expenseCategories: viewModel.expensesByCategory,
            incomeCategories: viewModel.incomeByCategory
        )
        let resolvedBreakdown = availableBreakdowns.contains(selectedCategoryBreakdownType)
            ? selectedCategoryBreakdownType
            : (availableBreakdowns.first ?? .expense)
        let categories = ReportsViewModel.categoriesForBreakdown(
            resolvedBreakdown,
            expenseCategories: viewModel.expensesByCategory,
            incomeCategories: viewModel.incomeByCategory
        )
        let normalizedLimit = ReportsCategoryRowLimitPreference.normalized(categoryRowLimit)
        let rowsDisplayState = ReportsViewModel.categoryRowsDisplayState(
            from: categories,
            rowLimit: normalizedLimit,
            isExpanded: isCategoryRowsExpanded
        )
        let chartSlices = ReportsViewModel.categoryChartSlices(
            from: categories,
            maxVisibleCategories: 5,
            otherCategoryName: AppLocalization.string(
                "reports.category.other",
                defaultValue: "Other"
            )
        )
        let leadingCategoryName = categories.first?.categoryName
            ?? AppLocalization.string(
                "category.uncategorized",
                defaultValue: "Uncategorized"
            )

        GlassCard(cornerRadius: 16, padding: 16) {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(availableBreakdowns) { breakdownType in
                        Button {
                            selectedCategoryBreakdownType = breakdownType
                        } label: {
                            Label(breakdownType.localizedName, systemImage: breakdownType.iconName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    resolvedBreakdown == breakdownType
                                        ? Color.primary
                                        : Color.secondary
                                )
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    resolvedBreakdown == breakdownType
                                        ? Color.primary.opacity(0.12)
                                        : Color.secondary.opacity(0.12)
                                )
                                .clipShape(.capsule)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                CategoryDonutChart(
                    slices: chartSlices,
                    centerTitle: AppLocalization.string(
                        "reports.category.top",
                        defaultValue: "Top Category"
                    ),
                    centerValue: leadingCategoryName
                )

                ForEach(rowsDisplayState.visible) { category in
                    NavigationLink {
                        ReportCategoryDetailView(
                            title: category.categoryName,
                            breakdownType: resolvedBreakdown,
                            categoryID: category.category?.id,
                            dateRange: viewModel.dateRange
                        )
                    } label: {
                        CategoryBreakdownRow(
                            category: category,
                            currencyCode: displayCurrencyCode
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                }

                if rowsDisplayState.hiddenCount > 0 && !isCategoryRowsExpanded {
                    HStack {
                        Button {
                            isCategoryRowsExpanded = true
                        } label: {
                            Text(
                                AppLocalization.formatted(
                                    "reports.category.expand",
                                    defaultValue: "Show %lld more",
                                    Int64(rowsDisplayState.hiddenCount)
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                } else if isCategoryRowsExpanded && categories.count > normalizedLimit {
                    HStack {
                        Button {
                            isCategoryRowsExpanded = false
                        } label: {
                            Text(
                                AppLocalization.string(
                                    "reports.category.collapse",
                                    defaultValue: "Show less"
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func monthlyTrendsSection(viewModel: ReportsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalization.string("reports.monthlyTrends", defaultValue: "Monthly Trends"))
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            GlassCard(cornerRadius: 16, padding: 16) {
                VStack(spacing: 12) {
                    ForEach(viewModel.monthlyTrends.suffix(6)) { trend in
                        MonthlyTrendRow(
                            trend: trend,
                            currencyCode: displayCurrencyCode
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
                        Text(AppLocalization.string("budgets.totalSpent", defaultValue: "Total Spent"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(CurrencyFormatter.shared.format(viewModel.totalSpent, currencyCode: displayCurrencyCode))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(AppLocalization.string("budgets.totalBudget", defaultValue: "Total Budget"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(CurrencyFormatter.shared.format(viewModel.totalBudgeted, currencyCode: displayCurrencyCode))
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
                        label: AppLocalization.string("budgets.overLimit", defaultValue: "Over Limit"),
                        color: AppColors.budgetDanger
                    )
                    
                    Spacer()
                    
                    budgetStatBadge(
                        value: viewModel.budgetsNearLimit,
                        label: AppLocalization.string("budgets.nearLimit", defaultValue: "Near Limit"),
                        color: AppColors.budgetWarning
                    )
                    
                    Spacer()
                    
                    budgetStatBadge(
                        value: viewModel.activeBudgets.count - viewModel.budgetsOverLimit - viewModel.budgetsNearLimit,
                        label: AppLocalization.string("budgets.onTrack", defaultValue: "On Track"),
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
                            AppLocalization.string("action.delete", defaultValue: "Delete"),
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
                AppLocalization.string("empty.budgets.title", defaultValue: "No Budgets"),
                systemImage: "chart.pie"
            )
        } description: {
            Text(AppLocalization.string("empty.budgets.message", defaultValue: "Create budgets to track your spending goals."))
        } actions: {
            Button(AppLocalization.string("empty.budgets.action", defaultValue: "Create Budget")) {
                showAddBudget = true
            }
            .buttonStyle(.fluxGlassProminent)
        }
    }
}

struct ReportCategoryDetailView: View {
    let title: String
    let breakdownType: ReportsViewModel.CategoryBreakdownType
    let categoryID: UUID?
    let dateRange: (start: Date, end: Date)

    @Environment(\.modelContext) private var modelContext

    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private struct DailyTransactionGroup: Identifiable {
        let date: Date
        let transactions: [Transaction]

        var id: Date { date }
    }

    private var groupedTransactions: [DailyTransactionGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped.keys.sorted(by: >).map { date in
            DailyTransactionGroup(
                date: date,
                transactions: grouped[date, default: []].sorted { $0.date > $1.date }
            )
        }
    }

    private var taskID: String {
        [
            breakdownType.rawValue,
            categoryID?.uuidString ?? "uncategorized",
            String(dateRange.start.timeIntervalSince1970),
            String(dateRange.end.timeIntervalSince1970)
        ].joined(separator: "|")
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label(
                        AppLocalization.string("error.title", defaultValue: "Error"),
                        systemImage: "exclamationmark.triangle"
                    )
                } description: {
                    Text(errorMessage)
                }
            } else if transactions.isEmpty {
                ContentUnavailableView {
                    Label(title, systemImage: "tray")
                } description: {
                    Text(
                        AppLocalization.string(
                            "reports.category.detail.empty",
                            defaultValue: "No transactions in this category for the selected period."
                        )
                    )
                }
            } else {
                List {
                    ForEach(groupedTransactions) { group in
                        Section {
                            ForEach(group.transactions) { transaction in
                                TransactionRowView(transaction: transaction)
                            }
                        } header: {
                            Text(sectionTitle(for: group.date))
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: taskID) {
            await loadTransactions()
        }
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return AppLocalization.string("date.today", defaultValue: "Today")
        }
        if calendar.isDateInYesterday(date) {
            return AppLocalization.string("date.yesterday", defaultValue: "Yesterday")
        }
        return date.formatted(.dateTime.month().day().year())
    }

    private func loadTransactions() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let startDate = dateRange.start
            let endDate = dateRange.end
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> {
                    !$0.isRecurringTemplate
                    && $0.date >= startDate
                    && $0.date <= endDate
                },
                sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
            )

            let fetched = try modelContext.fetch(descriptor)
            let transactionType: TransactionType = breakdownType == .expense ? .expense : .income
            transactions = fetched.filter { transaction in
                guard transaction.type == transactionType else {
                    return false
                }
                if let categoryID {
                    return transaction.category?.id == categoryID
                }
                return transaction.category == nil
            }
        } catch {
            errorMessage = error.localizedDescription
            transactions = []
        }
    }
}

struct CategoryBreakdownRow: View {
    let category: ReportsViewModel.CategorySummary
    let currencyCode: String
    
    var body: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct CategoryDonutChart: View {
    let slices: [ReportsViewModel.CategoryChartSlice]
    let centerTitle: String
    let centerValue: String

    private var hasData: Bool {
        slices.contains { $0.amount > .zero }
    }

    var body: some View {
        VStack(spacing: 12) {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("Amount", max(doubleAmount(slice.amount), 0)),
                    innerRadius: .ratio(0.62),
                    angularInset: 2
                )
                .foregroundStyle(slice.color)
            }
            .frame(height: 240)
            .chartLegend(.hidden)
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    if let plotFrame = chartProxy.plotFrame {
                        let frame = geometry[plotFrame]
                        VStack(spacing: 2) {
                            Text(centerTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(centerValue)
                                .font(.headline)
                                .bold()
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
            }

            if hasData {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(slices) { slice in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(slice.color)
                                    .frame(width: 8, height: 8)
                                Text(slice.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private func doubleAmount(_ amount: Decimal) -> Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}

struct MonthlyTrendRow: View {
    let trend: ReportsViewModel.MonthlyTrend
    let currencyCode: String
    
    @Environment(\.regionalSettings) private var regionalSettings
    
    var body: some View {
        HStack {
            Text(DateFormatterUtility.shared.formatReportMonth(trend.month))
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(currency: trend.income, code: currencyCode)
                    .font(.caption)
                    .foregroundStyle(AppColors.income)
                Text(AppLocalization.string("reports.income", defaultValue: "Income"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(currency: trend.expenses, code: currencyCode)
                    .font(.caption)
                    .foregroundStyle(AppColors.expense)
                Text(AppLocalization.string("reports.expenses", defaultValue: "Expenses"))
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
                Text(AppLocalization.string("reports.net", defaultValue: "Net"))
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
                        Text(AppLocalization.string("budget.allCategories", defaultValue: "All Categories"))
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
                    AppLocalization.string("action.edit", defaultValue: "Edit"),
                    systemImage: "pencil"
                )
            }
            
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(
                    AppLocalization.string("action.delete", defaultValue: "Delete"),
                    systemImage: "trash"
                )
            }
        }
        .confirmationDialog(
            AppLocalization.string("budget.deleteConfirmation.title", defaultValue: "Delete Budget?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppLocalization.string("action.delete", defaultValue: "Delete"), role: .destructive) {
                onDelete()
            }
        } message: {
            Text(AppLocalization.string("budget.deleteConfirmation.message", defaultValue: "This action cannot be undone."))
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
