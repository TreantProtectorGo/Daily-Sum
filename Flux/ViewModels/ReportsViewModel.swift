import Foundation
import SwiftUI
import SwiftData

// MARK: - Reports View Model

/// ViewModel for the Reports screen - generates financial analytics
@Observable
@MainActor
final class ReportsViewModel {
    // MARK: - Types
    
    struct CategorySummary: Identifiable {
        let id = UUID()
        let category: Category?
        let categoryName: String
        let amount: Decimal
        let percentage: Double
        let color: Color
    }
    
    struct MonthlyTrend: Identifiable {
        let id = UUID()
        let month: Date
        let income: Decimal
        let expenses: Decimal
        
        var net: Decimal { income - expenses }
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
                String(localized: "reports.period.thisMonth", defaultValue: "Month")
            case .lastMonth:
                String(localized: "reports.period.lastMonth", defaultValue: "Last")
            case .quarter:
                String(localized: "reports.period.last3Months", defaultValue: "Quarter")
            case .year:
                String(localized: "reports.period.thisYear", defaultValue: "Year")
            case .all:
                String(localized: "reports.period.all", defaultValue: "All")
            case .custom:
                String(localized: "reports.period.custom", defaultValue: "Custom")
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
                let currentMonth = calendar.component(.month, from: now)
                let quarterStartMonth = ((currentMonth - 1) / 3) * 3 + 1
                let year = calendar.component(.year, from: now)
                let start = calendar.date(from: DateComponents(year: year, month: quarterStartMonth, day: 1))!
                return (start, now)
                
            case .year:
                let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
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
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
        isLoading = true
        errorMessage = nil
        
        do {
            let (startDate, endDate) = dateRange
            
            // Fetch transactions in period
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> {
                    !$0.isRecurringTemplate && $0.date >= startDate && $0.date <= endDate
                }
            )
            let transactions = try modelContext.fetch(descriptor)
            
            // Calculate totals
            totalIncome = transactions
                .filter { $0.type == .income }
                .reduce(Decimal.zero) { $0 + $1.amount }
            
            totalExpenses = transactions
                .filter { $0.type == .expense }
                .reduce(Decimal.zero) { $0 + $1.amount }
            
            // Group expenses by category
            let expenseTransactions = transactions.filter { $0.type == .expense }
            expensesByCategory = groupByCategory(expenseTransactions, total: totalExpenses)
            
            // Group income by category
            let incomeTransactions = transactions.filter { $0.type == .income }
            incomeByCategory = groupByCategory(incomeTransactions, total: totalIncome)
            
            // Calculate monthly trends
            monthlyTrends = calculateMonthlyTrends(transactions)
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func groupByCategory(_ transactions: [Transaction], total: Decimal) -> [CategorySummary] {
        let grouped = Dictionary(grouping: transactions) { $0.category?.id ?? UUID() }
        
        return grouped.map { (_, categoryTransactions) in
            let category = categoryTransactions.first?.category
            let amount = categoryTransactions.reduce(Decimal.zero) { $0 + $1.amount }
            let percentage = total > 0 ? NSDecimalNumber(decimal: amount / total).doubleValue * 100 : 0
            
            return CategorySummary(
                category: category,
                categoryName: category?.displayName ?? String(localized: "category.uncategorized", defaultValue: "Uncategorized"),
                amount: amount,
                percentage: percentage,
                color: category?.color ?? .gray
            )
        }
        .sorted { $0.amount > $1.amount }
    }
    
    private func calculateMonthlyTrends(_ transactions: [Transaction]) -> [MonthlyTrend] {
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.date(from: calendar.dateComponents([.year, .month], from: transaction.date))!
        }
        
        return grouped.map { (month, monthTransactions) in
            let income = monthTransactions
                .filter { $0.type == .income }
                .reduce(Decimal.zero) { $0 + $1.amount }
            
            let expenses = monthTransactions
                .filter { $0.type == .expense }
                .reduce(Decimal.zero) { $0 + $1.amount }
            
            return MonthlyTrend(month: month, income: income, expenses: expenses)
        }
        .sorted { $0.month < $1.month }
    }
}
