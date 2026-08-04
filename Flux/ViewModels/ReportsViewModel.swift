import Foundation
import SwiftUI
import SwiftData

// MARK: - Reports View Model

/// ViewModel for the Reports screen - generates financial analytics
@Observable
@MainActor
final class ReportsViewModel {
    // MARK: - Types

    private struct ConvertedTransaction {
        let transaction: Transaction
        let convertedAmount: Decimal
    }

    private enum CategoryGroupKey: Hashable {
        case category(UUID)
        case uncategorized
    }
    
    struct CategorySummary: Identifiable {
        let id = UUID()
        let category: Category?
        let categoryName: String
        let amount: Decimal
        let percentage: Double
        let color: Color
    }

    enum CategoryBreakdownType: String, CaseIterable, Identifiable {
        case expense
        case income

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .expense:
                AppLocalization.string("reports.expenses", defaultValue: "Expenses")
            case .income:
                AppLocalization.string("reports.income", defaultValue: "Income")
            }
        }

        var iconName: String {
            switch self {
            case .expense:
                "arrow.up.circle.fill"
            case .income:
                "arrow.down.circle.fill"
            }
        }
    }
    
    struct CategoryChartSlice: Identifiable {
        let id = UUID()
        let name: String
        let amount: Decimal
        let color: Color
    }

    struct CategoryRowsDisplayState {
        let visible: [CategorySummary]
        let hiddenCount: Int
    }

    struct MonthlyTrend: Identifiable {
        let id = UUID()
        let month: Date
        let income: Decimal
        let expenses: Decimal
        
        var net: Decimal { income - expenses }
    }

    enum MonthlyTrendMetric: String, CaseIterable, Identifiable {
        case income
        case expenses
        case net

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .income:
                AppLocalization.string("reports.income", defaultValue: "Income")
            case .expenses:
                AppLocalization.string("reports.expenses", defaultValue: "Expenses")
            case .net:
                AppLocalization.string("reports.net", defaultValue: "Net")
            }
        }

        var color: Color {
            switch self {
            case .income:
                AppColors.Finance.income
            case .expenses:
                AppColors.Finance.expense
            case .net:
                AppColors.Finance.transfer
            }
        }

        func amount(in trend: MonthlyTrend) -> Decimal {
            switch self {
            case .income:
                trend.income
            case .expenses:
                trend.expenses
            case .net:
                trend.net
            }
        }

        func doubleAmount(in trend: MonthlyTrend) -> Double {
            NSDecimalNumber(decimal: amount(in: trend)).doubleValue
        }
    }

    static func recentMonthlyTrendRows(
        from trends: [MonthlyTrend],
        limit: Int = 6
    ) -> [MonthlyTrend] {
        Array(trends.suffix(limit).reversed())
    }
    
    enum ReportPeriod: String, CaseIterable, Identifiable {
        case month = "Month"
        case lastMonth = "Last Month"
        case quarter = "Quarter"
        case year = "Year"
        case all = "All"
        case custom = "Custom"
        
        var id: String { rawValue }
        
        var localizedName: String {
            switch self {
            case .month:
                AppLocalization.string("reports.period.thisMonth", defaultValue: "Month")
            case .lastMonth:
                AppLocalization.string("reports.period.lastMonth", defaultValue: "Last")
            case .quarter:
                AppLocalization.string("reports.period.last3Months", defaultValue: "Quarter")
            case .year:
                AppLocalization.string("reports.period.thisYear", defaultValue: "Year")
            case .all:
                AppLocalization.string("reports.period.all", defaultValue: "All")
            case .custom:
                AppLocalization.string("reports.period.custom", defaultValue: "Custom")
            }
        }
        
        func dateRange(
            referenceDate: Date = Date(),
            calendar: Calendar = .current
        ) -> (start: Date, end: Date) {
            let now = referenceDate
            
            switch self {
            case .month:
                let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                return (start, now)
                
            case .lastMonth:
                let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let start = calendar.date(byAdding: .month, value: -1, to: thisMonth)!
                let end = thisMonth.addingTimeInterval(-1)
                return (start, end)
                
            case .quarter:
               let currentMonthStart = calendar.date(
                    from: calendar.dateComponents([.year, .month], from: now)
                )!
                let start = calendar.date(byAdding: .month, value: -2, to: currentMonthStart)!
                return (start, now)
                
            case .year:
                let currentMonthStart = calendar.date(
                    from: calendar.dateComponents([.year, .month], from: now)
                )!
                let start = calendar.date(byAdding: .month, value: -11, to: currentMonthStart)!
                return (start, now)
                
            case .all:
                return (Date(timeIntervalSince1970: 0), now)
                
            case .custom:
                return (now, now) // Will be overridden by custom dates
            }
        }
    }
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let conversionService: CurrencyConversionService
    private let conversionMode: ConversionMode
    private var loadGeneration = LatestLoadGeneration()
    
    var selectedPeriod: ReportPeriod = .month
    var customStartDate: Date = Date()
    var customEndDate: Date = Date()
    
    var totalIncome: Decimal = 0
    var totalExpenses: Decimal = 0
    var expensesByCategory: [CategorySummary] = []
    var incomeByCategory: [CategorySummary] = []
    var monthlyTrends: [MonthlyTrend] = []
    
    var isLoading = false
    var errorMessage: String?
    var hasLoadedSuccessfully = false
    
    // MARK: - Computed Properties
    
    var netIncome: Decimal {
        totalIncome - totalExpenses
    }
    
    var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return NSDecimalNumber(decimal: netIncome / totalIncome).doubleValue * 100
    }
    
    var dateRange: (start: Date, end: Date) {
        if selectedPeriod == .custom {
            return (customStartDate, customEndDate)
        }
        return selectedPeriod.dateRange()
    }
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        conversionService: CurrencyConversionService? = nil,
        conversionMode: ConversionMode = .defaultForReports
    ) {
        self.modelContext = modelContext
        self.conversionService = conversionService ?? CurrencyConversionService(context: modelContext)
        self.conversionMode = conversionMode
    }
    
    // MARK: - Period Selection
    
    static func normalizedDateRange(start: Date, end: Date) -> (start: Date, end: Date) {
        if start <= end {
            return (start, end)
        }
        return (end, start)
    }
    
    func setCustomRange(start: Date, end: Date) {
        let normalizedRange = Self.normalizedDateRange(start: start, end: end)
        customStartDate = normalizedRange.start
        customEndDate = normalizedRange.end
    }
    
    // MARK: - Data Loading
    
    func loadReports() async {
        let generation = loadGeneration.begin()
        let selectedDateRange = dateRange
        let displayCurrencyCode = UserCurrencyPreference.resolvedCurrencyCode
        isLoading = true
        errorMessage = nil
        
        do {
            let (startDate, endDate) = selectedDateRange
            
            // Fetch transactions in period
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> {
                    !$0.isRecurringTemplate && $0.date >= startDate && $0.date <= endDate
                }
            )
            let transactions = try modelContext.fetch(descriptor).filter(\.isPosted)
            let convertedTransactions = try await convertTransactions(
                transactions,
                displayCurrencyCode: displayCurrencyCode
            )
            let trendDateRange = monthlyTrendDateRange(endingAt: endDate)
            let trendStartDate = trendDateRange.start
            let trendEndDate = trendDateRange.end
            let trendDescriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> {
                    !$0.isRecurringTemplate
                        && $0.date >= trendStartDate
                        && $0.date <= trendEndDate
                }
            )
            let trendTransactions = try modelContext.fetch(trendDescriptor).filter(\.isPosted)
            let convertedTrendTransactions = try await convertTransactions(
                trendTransactions,
                displayCurrencyCode: displayCurrencyCode
            )
            
            // Calculate totals
            let loadedTotalIncome = convertedTransactions
                .filter { $0.transaction.type == .income }
                .reduce(Decimal.zero) { $0 + $1.convertedAmount }
            
            let loadedTotalExpenses = convertedTransactions
                .filter { $0.transaction.type == .expense }
                .reduce(Decimal.zero) { $0 + $1.convertedAmount }
            
            // Group expenses by category
            let expenseTransactions = convertedTransactions.filter {
                $0.transaction.type == .expense
            }
            let loadedExpensesByCategory = groupByCategory(
                expenseTransactions,
                total: loadedTotalExpenses
            )
            
            // Group income by category
            let incomeTransactions = convertedTransactions.filter {
                $0.transaction.type == .income
            }
            let loadedIncomeByCategory = groupByCategory(
                incomeTransactions,
                total: loadedTotalIncome
            )
            
            // Calculate monthly trends
            let loadedMonthlyTrends = calculateMonthlyTrends(convertedTrendTransactions)

            guard loadGeneration.isCurrent(generation) else { return }
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            totalIncome = loadedTotalIncome
            totalExpenses = loadedTotalExpenses
            expensesByCategory = loadedExpensesByCategory
            incomeByCategory = loadedIncomeByCategory
            monthlyTrends = loadedMonthlyTrends
            hasLoadedSuccessfully = true
        } catch {
            guard loadGeneration.isCurrent(generation) else { return }
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }

        if loadGeneration.isCurrent(generation) {
            isLoading = false
        }
    }
    
    // MARK: - Private Methods
    
    private func groupByCategory(
        _ transactions: [ConvertedTransaction],
        total: Decimal
    ) -> [CategorySummary] {
        let grouped = Dictionary(grouping: transactions) { transaction in
            transaction.transaction.category.map {
                CategoryGroupKey.category($0.id)
            } ?? CategoryGroupKey.uncategorized
        }
        
        return grouped.map { (_, categoryTransactions) in
            let category = categoryTransactions.first?.transaction.category
            let amount = categoryTransactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
            let percentage = total > 0 ? NSDecimalNumber(decimal: amount / total).doubleValue * 100 : 0
            
            return CategorySummary(
                category: category,
                categoryName: category?.displayName
                    ?? AppLocalization.string(
                        "category.uncategorized",
                        defaultValue: "Uncategorized"
                    ),
                amount: amount,
                percentage: percentage,
                color: category?.color ?? .gray
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    static func availableCategoryBreakdownTypes(
        expenseCategories: [CategorySummary],
        incomeCategories: [CategorySummary]
    ) -> [CategoryBreakdownType] {
        var types: [CategoryBreakdownType] = []
        if !expenseCategories.isEmpty {
            types.append(.expense)
        }
        if !incomeCategories.isEmpty {
            types.append(.income)
        }
        return types
    }

    static func categoriesForBreakdown(
        _ type: CategoryBreakdownType,
        expenseCategories: [CategorySummary],
        incomeCategories: [CategorySummary]
    ) -> [CategorySummary] {
        switch type {
        case .expense:
            expenseCategories
        case .income:
            incomeCategories
        }
    }

    static func categoryRowsDisplayState(
        from categories: [CategorySummary],
        rowLimit: Int,
        isExpanded: Bool
    ) -> CategoryRowsDisplayState {
        guard !isExpanded else {
            return CategoryRowsDisplayState(visible: categories, hiddenCount: 0)
        }

        let normalizedLimit = max(1, rowLimit)
        let visible = Array(categories.prefix(normalizedLimit))
        let hiddenCount = max(0, categories.count - visible.count)
        return CategoryRowsDisplayState(visible: visible, hiddenCount: hiddenCount)
    }
    
     static func categoryChartSlices(
        from categories: [CategorySummary],
        maxVisibleCategories: Int = 5,
        otherCategoryName: String,
        otherColor: Color = .gray
    ) -> [CategoryChartSlice] {
        guard categories.count > maxVisibleCategories else {
            return categories.map {
                CategoryChartSlice(
                    name: $0.categoryName,
                    amount: $0.amount,
                    color: $0.color
                )
            }
        }

        let head = categories.prefix(maxVisibleCategories).map {
            CategoryChartSlice(
                name: $0.categoryName,
                amount: $0.amount,
                color: $0.color
            )
        }

        let otherAmount = categories
            .dropFirst(maxVisibleCategories)
            .reduce(Decimal.zero) { $0 + $1.amount }

        guard otherAmount > .zero else { return head }

        return head + [
            CategoryChartSlice(
                name: otherCategoryName,
                amount: otherAmount,
                color: otherColor
            )
        ]
    }

    private func calculateMonthlyTrends(_ transactions: [ConvertedTransaction]) -> [MonthlyTrend] {
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.date(
                from: calendar.dateComponents([.year, .month], from: transaction.transaction.date)
            )!
        }
        
        return grouped.map { (month, monthTransactions) in
            let income = monthTransactions
                .filter { $0.transaction.type == .income }
                .reduce(Decimal.zero) { $0 + $1.convertedAmount }
            
            let expenses = monthTransactions
                .filter { $0.transaction.type == .expense }
                .reduce(Decimal.zero) { $0 + $1.convertedAmount }
            
            return MonthlyTrend(month: month, income: income, expenses: expenses)
        }
        .sorted { $0.month < $1.month }
    }

    private func monthlyTrendDateRange(endingAt endDate: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let endMonthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: endDate)
        ) ?? endDate
        let start = calendar.date(byAdding: .month, value: -5, to: endMonthStart) ?? endMonthStart
        return (start, endDate)
    }

    private func convertTransactions(
        _ transactions: [Transaction],
        displayCurrencyCode: String
    ) async throws -> [ConvertedTransaction] {
        var converted: [ConvertedTransaction] = []
        converted.reserveCapacity(transactions.count)

        for transaction in transactions {
            let convertedAmount = try await conversionService.convert(
                transaction.amount,
                from: transaction.currencyCode,
                to: displayCurrencyCode,
                on: transaction.date,
                mode: conversionMode
            )
            converted.append(
                ConvertedTransaction(
                    transaction: transaction,
                    convertedAmount: convertedAmount
                )
            )
        }

        return converted
    }
}
