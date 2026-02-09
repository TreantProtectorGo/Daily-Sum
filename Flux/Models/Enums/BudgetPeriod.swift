import Foundation

/// The time period a budget covers
enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly
    case monthly
    
    var localizedName: String {
        switch self {
        case .weekly:
            String(localized: "budget.period.weekly", defaultValue: "Weekly")
        case .monthly:
            String(localized: "budget.period.monthly", defaultValue: "Monthly")
        }
    }
    
    /// Returns the date range for this period containing the given date
    func dateRange(containing date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        switch self {
        case .weekly:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
            return (start, end)
        case .monthly:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        }
    }
}
