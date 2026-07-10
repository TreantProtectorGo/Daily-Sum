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
    var budgetStatusesByID: [UUID: BudgetService.BudgetStatus] = [:]
    var totalBudgeted: Decimal = 0
    var totalSpent: Decimal = 0
    
    var isLoading = false
    var errorMessage: String?
    
    var overallProgress: Double {
        guard totalBudgeted > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalSpent / totalBudgeted).doubleValue
    }
    
    var budgetsOverLimit: Int {
        activeBudgetStatuses.filter(\.isExceeded).count
    }
    
    var budgetsNearLimit: Int {
        activeBudgetStatuses.filter { $0.isAlertTriggered && !$0.isExceeded }.count
    }
    
    init(
        modelContext: ModelContext,
        conversionService: CurrencyConversionService? = nil,
        conversionMode: ConversionMode = .defaultForReports
    ) {
        self.modelContext = modelContext
        let resolvedConversionService = conversionService ?? CurrencyConversionService(context: modelContext)
        self.budgetService = BudgetService(
            context: modelContext,
            conversionService: resolvedConversionService
        )
        self.conversionService = resolvedConversionService
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
            budgetStatusesByID = try await budgetService.statuses(for: budgets)
            
            // Active state is no longer user-facing; treat all budgets as visible.
            activeBudgets = budgets
            inactiveBudgets = []
            let totals = try await calculateConvertedTotals(for: activeBudgetStatuses)
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

    func status(for budget: Budget) -> BudgetService.BudgetStatus? {
        budgetStatusesByID[budget.id]
    }

    private var activeBudgetStatuses: [BudgetService.BudgetStatus] {
        activeBudgets.compactMap { budgetStatusesByID[$0.id] }
    }

    private func calculateConvertedTotals(
        for statuses: [BudgetService.BudgetStatus]
    ) async throws -> (budgeted: Decimal, spent: Decimal) {
        var totalBudgeted: Decimal = 0
        var totalSpent: Decimal = 0
        let displayCurrencyCode = UserCurrencyPreference.resolvedCurrencyCode

        for status in statuses {
            let convertedLimit = try await conversionService.convert(
                status.limit,
                from: status.budget.currencyCode,
                to: displayCurrencyCode,
                on: .now,
                mode: conversionMode
            )
            totalBudgeted += convertedLimit

            let convertedSpent = try await conversionService.convert(
                status.spent,
                from: status.budget.currencyCode,
                to: displayCurrencyCode,
                on: .now,
                mode: conversionMode
            )
            totalSpent += convertedSpent
        }

        return (totalBudgeted, totalSpent)
    }
}
