import Foundation

/// Defines how a recurring transaction repeats
enum RecurrenceRule: Codable, Equatable {
    case daily
    case weekly
    case monthly
    case yearly
    case custom(interval: Int, unit: RecurrenceUnit)
    
    enum RecurrenceUnit: String, Codable {
        case days
        case weeks
        case months
    }
    
    var localizedDescription: String {
        switch self {
        case .daily:
            AppLocalization.string("recurrence.daily", defaultValue: "Daily")
        case .weekly:
            AppLocalization.string("recurrence.weekly", defaultValue: "Weekly")
        case .monthly:
            AppLocalization.string("recurrence.monthly", defaultValue: "Monthly")
        case .yearly:
            AppLocalization.string("recurrence.yearly", defaultValue: "Yearly")
        case .custom(let interval, let unit):
            "Every \(interval) \(unit.rawValue)"
        }
    }
    
    func nextDate(from date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)!
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)!
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)!
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)!
        case .custom(let interval, let unit):
            let component: Calendar.Component = switch unit {
            case .days: .day
            case .weeks: .weekOfYear
            case .months: .month
            }
            return calendar.date(byAdding: component, value: interval, to: date)!
        }
    }
}
