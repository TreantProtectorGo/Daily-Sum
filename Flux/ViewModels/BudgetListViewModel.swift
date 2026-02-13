import Foundation
import SwiftUI
import SwiftData

@Observable
@MainActor
final class BudgetListViewModel {
    private let modelContext: ModelContext
    private let budgetService: BudgetService
    
    var budgets: [Budget] = []
    var activeBudgets: [Budget] = []
    var inactiveBudgets: [Budget] = []
    
    var isLoading = false
    var errorMessage: String?
    
    var totalBudgeted: Decimal {
        activeBudgets.reduce(Decimal.zero) { $0 + $1.limitAmount }
    }
    
    var totalSpent: Decimal {
        activeBudgets.reduce(Decimal.zero) { sum, budget in
            sum + budget.spentAmount(in: modelContext)
        }
    }
    
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
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.budgetService = BudgetService(context: modelContext)
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
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func deleteBudget(_ budget: Budget) async throws {
        try budgetService.delete(budget)
        await loadBudgets()
    }
    
}
