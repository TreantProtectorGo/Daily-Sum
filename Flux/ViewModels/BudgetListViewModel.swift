import Foundation
import SwiftUI
import SwiftData

@Observable
@MainActor
final class BudgetListViewModel {
    private let modelContext: ModelContext
    private let budgetService: BudgetService
    private let conversionService: CurrencyConversionService
    private let conversionMode: ConversionMode
    
    var budgets: [Budget] = []
    var activeBudgets: [Budget] = []
    var inactiveBudgets: [Budget] = []
    var totalBudgeted: Decimal = 0
    var totalSpent: Decimal = 0
    
    var isLoading = false
    var errorMessage: String?
    
    var overallProgress: Double {
        guard totalBudgeted > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalSpent / totalBudgeted).doubleValue
    }
    
    var budgetsOverLimit: Int {
        activeBudgets.filter { $0.usagePercentage(in: modelContext) >= 1.0 }.count
    }
    
    var budgetsNearLimit: Int {
        activeBudgets.filter { 
            let usage = $0.usagePercentage(in: modelContext)
            return usage >= 0.8 && usage < 1.0
        }.count
    }
    
    init(
        modelContext: ModelContext,
        conversionService: CurrencyConversionService? = nil,
        conversionMode: ConversionMode = .defaultForReports
    ) {
        self.modelContext = modelContext
        self.budgetService = BudgetService(context: modelContext)
        self.conversionService = conversionService ?? CurrencyConversionService(context: modelContext)
        self.conversionMode = conversionMode
    }
    
    func loadBudgets() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let descriptor = FetchDescriptor<Budget>(
                sortBy: [SortDescriptor(\Budget.createdAt, order: .reverse)]
            )
            budgets = try modelContext.fetch(descriptor)
            
            // Active state is no longer user-facing; treat all budgets as visible.
            activeBudgets = budgets
            inactiveBudgets = []
            let totals = try await calculateConvertedTotals(for: activeBudgets)
            totalBudgeted = totals.budgeted
            totalSpent = totals.spent
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func deleteBudget(_ budget: Budget) async throws {
        try budgetService.delete(budget)
        await loadBudgets()
    }

    private func calculateConvertedTotals(
        for budgets: [Budget]
    ) async throws -> (budgeted: Decimal, spent: Decimal) {
        var totalBudgeted: Decimal = 0
        var totalSpent: Decimal = 0
        let displayCurrencyCode = UserCurrencyPreference.resolvedCurrencyCode

        for budget in budgets {
            let convertedLimit = try await conversionService.convert(
                budget.limitAmount,
                from: budget.currencyCode,
                to: displayCurrencyCode,
                on: .now,
                mode: conversionMode
            )
            totalBudgeted += convertedLimit

            let convertedSpent = try await conversionService.convert(
                budget.spentAmount(in: modelContext),
                from: budget.currencyCode,
                to: displayCurrencyCode,
                on: .now,
                mode: conversionMode
            )
            totalSpent += convertedSpent
        }

        return (totalBudgeted, totalSpent)
    }
}
