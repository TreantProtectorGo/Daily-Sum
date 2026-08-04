import Foundation
import SwiftData

/// A spending budget for a specific category
@Model
final class Budget {
    var id: UUID = UUID()
    
    /// Budget limit amount
    var limitAmount: Decimal = 0
    
    /// Currency code for this budget
    var currencyCode: String = SupportedCurrency.USD.rawValue
    
    /// Budget period (weekly or monthly)
    var period: BudgetPeriod = BudgetPeriod.monthly
    
    /// Alert threshold as percentage (0.0 to 1.0)
    /// e.g., 0.8 = alert at 80% spent
    var alertThreshold: Decimal = 0.8
    
    /// Whether alerts are enabled for this budget
    var alertsEnabled: Bool = true

    /// Start date of the budget period whose progressive alerts are currently tracked.
    var alertTrackingPeriodStart: Date?

    /// Whether the 80% warning has been sent in the tracked period.
    var hasSentWarningAlertInTrackedPeriod: Bool = false

    /// Whether the 100% exceeded alert has been sent in the tracked period.
    var hasSentExceededAlertInTrackedPeriod: Bool = false
    
    /// Date the budget was created
    var createdAt: Date = Date()
    
    /// Whether this budget is active
    var isActive: Bool = true
    
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
        alertTrackingPeriodStart: Date? = nil,
        hasSentWarningAlertInTrackedPeriod: Bool = false,
        hasSentExceededAlertInTrackedPeriod: Bool = false,
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
        self.alertTrackingPeriodStart = alertTrackingPeriodStart
        self.hasSentWarningAlertInTrackedPeriod = hasSentWarningAlertInTrackedPeriod
        self.hasSentExceededAlertInTrackedPeriod = hasSentExceededAlertInTrackedPeriod
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
            let transactions = try context.fetch(descriptor).filter(\.isPosted)
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
        return usagePercentage(in: context, for: date) >= alertThreshold
    }
    
    /// Whether the budget has been exceeded
    func isExceeded(in context: ModelContext, for date: Date = .now) -> Bool {
        usagePercentage(in: context, for: date) >= 1.0
    }

    /// Resets per-period progressive alert state when entering a new budget period.
    @discardableResult
    func resetTrackedAlertStateIfNeeded(for date: Date, calendar: Calendar = .current) -> Bool {
        let periodStart = period.dateRange(containing: date, calendar: calendar).start
        guard alertTrackingPeriodStart != periodStart else {
            return false
        }

        alertTrackingPeriodStart = periodStart
        hasSentWarningAlertInTrackedPeriod = false
        hasSentExceededAlertInTrackedPeriod = false
        return true
    }
}
