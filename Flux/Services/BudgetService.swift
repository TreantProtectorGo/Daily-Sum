import Foundation
import SwiftData

/// Service for managing Budget CRUD operations
@MainActor
@Observable
final class BudgetService {
    private let context: ModelContext
    private let conversionService: CurrencyConversionService
    
    init(
        context: ModelContext,
        conversionService: CurrencyConversionService? = nil
    ) {
        self.context = context
        self.conversionService = conversionService ?? CurrencyConversionService(context: context)
    }
    
    // MARK: - Create
    
    /// Creates a new budget
    @discardableResult
    func create(
        category: Category? = nil,
        limitAmount: Decimal,
        currencyCode: String,
        period: BudgetPeriod = .monthly,
        alertThreshold: Decimal = 0.8,
        alertsEnabled: Bool = true,
        isActive: Bool = true
    ) throws -> Budget {
        if let category {
            // Validate category is expense type
            guard category.type == .expense else {
                throw BudgetError.incomeCategory
            }

            if isActive {
                try ensureUniqueCategoryBudget(
                    category: category,
                    period: period
                )
            }
        } else if isActive {
            try ensureUniqueAllCategoriesBudget(period: period)
        }
        
        let budget = Budget(
            limitAmount: limitAmount,
            currencyCode: currencyCode,
            period: period,
            alertThreshold: alertThreshold,
            alertsEnabled: alertsEnabled,
            isActive: isActive,
            category: category
        )
        context.insert(budget)
        try context.save()
        return budget
    }
    
    // MARK: - Read
    
    /// Fetches all active budgets
    func fetch(activeOnly: Bool = true) throws -> [Budget] {
        var descriptor = FetchDescriptor<Budget>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        
        if activeOnly {
            descriptor.predicate = #Predicate { $0.isActive }
        }
        
        return try context.fetch(descriptor)
    }
    
    /// Fetches a budget by ID
    func fetch(byId id: UUID) throws -> Budget? {
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    /// Fetches the budget for a specific category
    func fetch(forCategory category: Category) throws -> Budget? {
        let categoryId = category.id
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.category?.id == categoryId && $0.isActive }
        )
        return try context.fetch(descriptor).first
    }
    
    // MARK: - Update
    
    /// Updates a budget
    func update(
        _ budget: Budget,
        limitAmount: Decimal? = nil,
        period: BudgetPeriod? = nil,
        category: Category? = nil,
        shouldUpdateCategory: Bool = false,
        currencyCode: String? = nil,
        isActive: Bool? = nil,
        alertThreshold: Decimal? = nil,
        alertsEnabled: Bool? = nil
    ) throws {
        if shouldUpdateCategory, let category {
            guard category.type == .expense else {
                throw BudgetError.incomeCategory
            }
        }

        let finalCategory = shouldUpdateCategory ? category : budget.category
        let finalPeriod = period ?? budget.period
        let finalIsActive = isActive ?? budget.isActive
        if finalIsActive, let finalCategory {
            try ensureUniqueCategoryBudget(
                category: finalCategory,
                period: finalPeriod,
                excluding: budget
            )
        } else if finalIsActive {
            try ensureUniqueAllCategoriesBudget(
                period: finalPeriod,
                excluding: budget
            )
        }

        if let limitAmount { budget.limitAmount = limitAmount }
        if let period { budget.period = period }
        if shouldUpdateCategory { budget.category = category }
        if let currencyCode { budget.currencyCode = currencyCode }
        if let isActive { budget.isActive = isActive }
        if let alertThreshold { budget.alertThreshold = alertThreshold }
        if let alertsEnabled { budget.alertsEnabled = alertsEnabled }
        
        try context.save()
    }
    
    /// Deactivates a budget
    func deactivate(_ budget: Budget) throws {
        budget.isActive = false
        try context.save()
    }
    
    /// Reactivates a budget
    func reactivate(_ budget: Budget) throws {
        if let category = budget.category {
            guard category.type == .expense else {
                throw BudgetError.incomeCategory
            }
            try ensureUniqueCategoryBudget(
                category: category,
                period: budget.period,
                excluding: budget
            )
        } else {
            try ensureUniqueAllCategoriesBudget(
                period: budget.period,
                excluding: budget
            )
        }
        budget.isActive = true
        try context.save()
    }
    
    // MARK: - Delete
    
    /// Deletes a budget
    func delete(_ budget: Budget) throws {
        context.delete(budget)
        try context.save()
    }
    
    // MARK: - Status
    
    /// Gets the status of all active budgets
    func allBudgetStatuses(for date: Date = .now) async throws -> [BudgetStatus] {
        let budgets = try fetch(activeOnly: true)
        let statusesByID = try await statuses(for: budgets, date: date)
        return budgets.compactMap { statusesByID[$0.id] }
    }

    func status(for budget: Budget, date: Date = .now) async throws -> BudgetStatus {
        let statusesByID = try await statuses(for: [budget], date: date)
        return statusesByID[budget.id] ?? BudgetStatus(budget: budget, spent: 0)
    }

    /// Calculates multiple budgets from one transaction fetch. Transaction amounts
    /// are converted on their transaction date before comparison with the budget.
    func statuses(
        for budgets: [Budget],
        date: Date = .now
    ) async throws -> [UUID: BudgetStatus] {
        guard !budgets.isEmpty else { return [:] }

        let transactions = try context.fetch(
            FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> {
                    !$0.isRecurringTemplate
                }
            )
        ).filter(\.isPosted)
        var result: [UUID: BudgetStatus] = [:]

        for budget in budgets {
            let range = budget.period.dateRange(containing: date)
            let categoryID = budget.category?.id
            let matchingTransactions = transactions.filter { transaction in
                guard transaction.type == .expense else { return false }
                guard transaction.date >= range.start, transaction.date < range.end else {
                    return false
                }
                return categoryID == nil || transaction.category?.id == categoryID
            }

            var spent: Decimal = 0
            for transaction in matchingTransactions {
                spent += try await conversionService.convert(
                    transaction.amount,
                    from: transaction.currencyCode,
                    to: budget.currencyCode,
                    on: transaction.date,
                    mode: .historical
                )
            }
            result[budget.id] = BudgetStatus(budget: budget, spent: spent)
        }

        return result
    }
    
    /// Gets budgets that have triggered alerts
    func triggeredAlerts(for date: Date = .now) async throws -> [BudgetAlert] {
        let budgets = try fetch(activeOnly: true)
        let statusesByID = try await statuses(for: budgets, date: date)
        var alerts: [BudgetAlert] = []
        var requiresSave = false

        for budget in budgets {
            if budget.resetTrackedAlertStateIfNeeded(for: date) {
                requiresSave = true
            }

            let usage = statusesByID[budget.id]?.percentage ?? 0
            if usage >= 1.0 {
                if !budget.hasSentWarningAlertInTrackedPeriod {
                    budget.hasSentWarningAlertInTrackedPeriod = true
                    requiresSave = true
                }

                if !budget.hasSentExceededAlertInTrackedPeriod {
                    budget.hasSentExceededAlertInTrackedPeriod = true
                    alerts.append(BudgetAlert(budget: budget, stage: .exceeded))
                    requiresSave = true
                }
                continue
            }

            if usage >= budget.alertThreshold, !budget.hasSentWarningAlertInTrackedPeriod {
                budget.hasSentWarningAlertInTrackedPeriod = true
                alerts.append(BudgetAlert(budget: budget, stage: .warning))
                requiresSave = true
            }
        }

        if requiresSave {
            try context.save()
        }

        return alerts
    }
    
    // MARK: - Types
    
    struct BudgetStatus {
        let budget: Budget
        let spent: Decimal
        let limit: Decimal
        let isAlertTriggered: Bool
        let isExceeded: Bool

        init(budget: Budget, spent: Decimal) {
            self.budget = budget
            self.spent = spent
            self.limit = budget.limitAmount
            let percentage = budget.limitAmount > 0 ? spent / budget.limitAmount : 0
            self.isAlertTriggered = percentage >= budget.alertThreshold
            self.isExceeded = percentage >= 1
        }
        
        var remaining: Decimal { limit - spent }
        var percentage: Decimal { limit > 0 ? spent / limit : 0 }
    }

    struct BudgetAlert {
        let budget: Budget
        let stage: BudgetAlertStage
    }

    enum BudgetAlertStage {
        case warning
        case exceeded
    }
    
    // MARK: - Errors
    
    enum BudgetError: LocalizedError {
        case incomeCategory
        case duplicateBudget
        
        var errorDescription: String? {
            switch self {
            case .incomeCategory:
                AppLocalization.string(
                    "budget.error.incomeCategory",
                    defaultValue: "Budgets can only be created for expense categories"
                )
            case .duplicateBudget:
                AppLocalization.string(
                    "budget.error.duplicateBudget",
                    defaultValue: "A budget already exists for this category or scope in the selected period"
                )
            }
        }
    }

    // MARK: - Validation

    private func ensureUniqueCategoryBudget(
        category: Category,
        period: BudgetPeriod,
        excluding currentBudget: Budget? = nil
    ) throws {
        let categoryId = category.id
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.category?.id == categoryId }
        )

        let existingBudgets = try context.fetch(descriptor).filter {
            $0.isActive && $0.period == period
        }
        let hasDuplicate = existingBudgets.contains { existingBudget in
            guard let currentBudget else { return true }
            return existingBudget.id != currentBudget.id
        }

        if hasDuplicate {
            throw BudgetError.duplicateBudget
        }
    }

    private func ensureUniqueAllCategoriesBudget(
        period: BudgetPeriod,
        excluding currentBudget: Budget? = nil
    ) throws {
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.category == nil }
        )

        let existingBudgets = try context.fetch(descriptor).filter {
            $0.isActive && $0.period == period
        }
        let hasDuplicate = existingBudgets.contains { existingBudget in
            guard let currentBudget else { return true }
            return existingBudget.id != currentBudget.id
        }

        if hasDuplicate {
            throw BudgetError.duplicateBudget
        }
    }
}
