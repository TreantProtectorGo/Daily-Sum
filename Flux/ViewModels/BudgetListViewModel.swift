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
    private var loadGeneration = LatestLoadGeneration()
    
    var budgets: [Budget] = []
    var activeBudgets: [Budget] = []
    var inactiveBudgets: [Budget] = []
    var budgetStatusesByID: [UUID: BudgetService.BudgetStatus] = [:]
    var totalBudgeted: Decimal = 0
    var totalSpent: Decimal = 0
    
    var isLoading = false
    var errorMessage: String?
    var hasLoadedSuccessfully = false
    
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
        let generation = loadGeneration.begin()
        let displayCurrencyCode = UserCurrencyPreference.resolvedCurrencyCode
        isLoading = true
        errorMessage = nil
        
        do {
            let descriptor = FetchDescriptor<Budget>(
                sortBy: [SortDescriptor(\Budget.createdAt, order: .reverse)]
            )
            let loadedBudgets = try modelContext.fetch(descriptor)
            let loadedStatuses = try await budgetService.statuses(for: loadedBudgets)
            
            // Active state is no longer user-facing; treat all budgets as visible.
            let loadedActiveBudgets = loadedBudgets
            let activeStatuses = loadedActiveBudgets.compactMap { loadedStatuses[$0.id] }
            let totals = try await calculateConvertedTotals(
                for: activeStatuses,
                displayCurrencyCode: displayCurrencyCode
            )

            guard loadGeneration.isCurrent(generation) else { return }
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            budgets = loadedBudgets
            budgetStatusesByID = loadedStatuses
            activeBudgets = loadedActiveBudgets
            inactiveBudgets = []
            totalBudgeted = totals.budgeted
            totalSpent = totals.spent
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
        for statuses: [BudgetService.BudgetStatus],
        displayCurrencyCode: String
    ) async throws -> (budgeted: Decimal, spent: Decimal) {
        var totalBudgeted: Decimal = 0
        var totalSpent: Decimal = 0
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
