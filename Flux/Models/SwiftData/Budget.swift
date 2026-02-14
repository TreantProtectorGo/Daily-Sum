import Foundation
import SwiftData

/// A spending budget for a specific category
@Model
final class Budget {
    #Unique<Budget>([\.id])
    
    var id: UUID
    
    /// Budget limit amount
    var limitAmount: Decimal
    
    /// Currency code for this budget
    var currencyCode: String
    
    /// Budget period (weekly or monthly)
    var period: BudgetPeriod
    
    /// Alert threshold as percentage (0.0 to 1.0)
    /// e.g., 0.8 = alert at 80% spent
    var alertThreshold: Decimal
    
    /// Whether alerts are enabled for this budget
    var alertsEnabled: Bool
    
    /// Date the budget was created
    var createdAt: Date
    
    /// Whether this budget is active
    var isActive: Bool
    
    /// The category this budget applies to
    @Relationship(deleteRule: .nullify)
    var category: Category?
    
    init(
        id: UUID = UUID(),
        limitAmount: Decimal,
        currencyCode: String,
        period: BudgetPeriod = .monthly,
        alertThreshold: Decimal = 0.8,
        alertsEnabled: Bool = true,
        createdAt: Date = .now,
        isActive: Bool = true,
        category: Category? = nil
    ) {
        self.id = id
        self.limitAmount = limitAmount
        self.currencyCode = currencyCode
        self.period = period
        self.alertThreshold = alertThreshold
        self.alertsEnabled = alertsEnabled
        self.createdAt = createdAt
        self.isActive = isActive
        self.category = category
    }
    
    // MARK: - Computed Properties
    
    /// Currency symbol for display
    var currencySymbol: String {
        SupportedCurrency(rawValue: currencyCode)?.symbol ?? currencyCode
    }
    
    /// Calculates spent amount for the current period
    func spentAmount(in context: ModelContext, for date: Date = .now) -> Decimal {
        let (start, end) = period.dateRange(containing: date)
        let categoryId = category?.id
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { !$0.isRecurringTemplate }
        )
        
        do {
            let transactions = try context.fetch(descriptor)
            return transactions
                .filter { transaction in
                    guard transaction.type == .expense else { return false }
                    guard transaction.date >= start, transaction.date < end else { return false }

                    if let categoryId {
                        return transaction.category?.id == categoryId
                    }
                    return true
                }
                .reduce(Decimal.zero) { $0 + $1.amount }
        } catch {
            return 0
        }
    }
    
    /// Remaining budget amount for current period
    func remainingAmount(in context: ModelContext, for date: Date = .now) -> Decimal {
        limitAmount - spentAmount(in: context, for: date)
    }
    
    /// Percentage of budget used (0.0 to 1.0+)
    func usagePercentage(in context: ModelContext, for date: Date = .now) -> Decimal {
        guard limitAmount > 0 else { return 0 }
        return spentAmount(in: context, for: date) / limitAmount
    }
    
    /// Whether the budget alert threshold has been reached
    func isAlertTriggered(in context: ModelContext, for date: Date = .now) -> Bool {
        guard alertsEnabled else { return false }
        return usagePercentage(in: context, for: date) >= alertThreshold
    }
    
    /// Whether the budget has been exceeded
    func isExceeded(in context: ModelContext, for date: Date = .now) -> Bool {
        usagePercentage(in: context, for: date) >= 1.0
    }
}
