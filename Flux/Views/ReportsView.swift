import SwiftUI
import SwiftData

// MARK: - Reports View

/// Financial reports with category breakdown and trends
struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ReportsViewModel?
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    reportsContent(viewModel: viewModel)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(String(localized: "reports.title", defaultValue: "Reports"))
            .task {
                if viewModel == nil {
                    viewModel = ReportsViewModel(modelContext: modelContext)
                }
                await viewModel?.loadReports()
            }
            .refreshable {
                await viewModel?.loadReports()
            }
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private func reportsContent(viewModel: ReportsViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period Selector
                periodSelector(viewModel: viewModel)
                
                // Summary Cards
                summarySection(viewModel: viewModel)
                
                // Expense Breakdown
                if !viewModel.expensesByCategory.isEmpty {
                    categoryBreakdownSection(
                        title: String(localized: "reports.expensesByCategory", defaultValue: "Expenses by Category"),
                        categories: viewModel.expensesByCategory,
                        total: viewModel.totalExpenses
                    )
                }
                
                // Income Breakdown
                if !viewModel.incomeByCategory.isEmpty {
                    categoryBreakdownSection(
                        title: String(localized: "reports.incomeByCategory", defaultValue: "Income by Category"),
                        categories: viewModel.incomeByCategory,
                        total: viewModel.totalIncome
                    )
                }
                
                // Monthly Trends
                if !viewModel.monthlyTrends.isEmpty {
                    monthlyTrendsSection(viewModel: viewModel)
                }
                
                // Empty state if no data
                if viewModel.expensesByCategory.isEmpty && viewModel.incomeByCategory.isEmpty {
                    EmptyStateView.noDataForPeriod()
                        .padding(.top, 40)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Period Selector
    
    @ViewBuilder
    private func periodSelector(viewModel: ReportsViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ReportsViewModel.ReportPeriod.allCases.filter { $0 != .custom }, id: \.id) { period in
                    Button {
                        viewModel.selectedPeriod = period
                        Task { await viewModel.loadReports() }
                    } label: {
                        Text(period.localizedName)
                            .font(.subheadline)
                            .fontWeight(viewModel.selectedPeriod == period ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .glassBackground(
                        cornerRadius: 20,
                        isInteractive: viewModel.selectedPeriod != period
                    )
                    .opacity(viewModel.selectedPeriod == period ? 1.0 : 0.7)
                }
            }
        }
    }
    
    // MARK: - Summary Section
    
    @ViewBuilder
    private func summarySection(viewModel: ReportsViewModel) -> some View {
        VStack(spacing: 12) {
            // Income vs Expenses
            HStack(spacing: 12) {
                // Income
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
                
                // Expenses
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
            
            // Net Income & Savings Rate
            HStack(spacing: 12) {
                // Net
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
                
                // Savings Rate
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
    
    // MARK: - Category Breakdown Section
    
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
    
    // MARK: - Monthly Trends Section
    
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
}

// MARK: - Category Breakdown Row

struct CategoryBreakdownRow: View {
    let category: ReportsViewModel.CategorySummary
    let currencyCode: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Category info
                Circle()
                    .fill(category.color)
                    .frame(width: 12, height: 12)
                
                Text(category.categoryName)
                    .font(.subheadline)
                
                Spacer()
                
                // Amount and percentage
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
            
            // Progress bar
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

// MARK: - Monthly Trend Row

struct MonthlyTrendRow: View {
    let trend: ReportsViewModel.MonthlyTrend
    let currencyCode: String
    
    @Environment(\.regionalSettings) private var regionalSettings
    
    var body: some View {
        HStack {
            // Month
            Text(trend.month.formatted(.dateTime.month(.abbreviated).year()))
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            // Income
            VStack(alignment: .trailing, spacing: 2) {
                Text(currency: trend.income, code: currencyCode)
                    .font(.caption)
                    .foregroundStyle(AppColors.income)
                Text(String(localized: "reports.income", defaultValue: "Income"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80)
            
            // Expenses
            VStack(alignment: .trailing, spacing: 2) {
                Text(currency: trend.expenses, code: currencyCode)
                    .font(.caption)
                    .foregroundStyle(AppColors.expense)
                Text(String(localized: "reports.expenses", defaultValue: "Expenses"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80)
            
            // Net
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

// MARK: - Preview

#Preview("Reports") {
    do {
        let container = try ModelContainerConfiguration.createPreviewContainer()
        return ReportsView()
            .modelContainer(container)
    } catch {
        return Text("Preview Error")
    }
}
