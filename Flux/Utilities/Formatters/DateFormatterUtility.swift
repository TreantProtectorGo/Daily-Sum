import Foundation

/// Utility for formatting dates according to locale settings
/// All dates are stored in UTC and converted to local time for display
struct DateFormatterUtility {
    /// Shared instance
    static let shared = DateFormatterUtility()
    
    /// Calendar for date calculations (uses current locale)
    var calendar: Calendar {
        Calendar.current
    }
    
    // MARK: - Display Formatting
    
    /// Formats a date for display in transaction lists
    func formatTransactionDate(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        let now = Date.now
        
        if calendar.isDateInToday(date) {
            return AppLocalization.string("date.today", defaultValue: "Today")
        } else if calendar.isDateInYesterday(date) {
            return AppLocalization.string("date.yesterday", defaultValue: "Yesterday")
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            // Same week - show day name
            return date.formatted(.dateTime.weekday(.wide).locale(locale))
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            // Same year - show month and day
            return date.formatted(.dateTime.month(.abbreviated).day().locale(locale))
        } else {
            // Different year - show full date
            return date.formatted(.dateTime.year().month(.abbreviated).day().locale(locale))
        }
    }
    
    /// Formats a date with time for detailed view
    func formatDateWithTime(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        date.formatted(
            .dateTime
            .year()
            .month(.abbreviated)
            .day()
            .hour()
            .minute()
            .locale(locale)
        )
    }
    
    /// Formats just the time portion
    func formatTime(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }
    
    /// Formats a month/year for budget and report headers
    func formatMonthYear(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        date.formatted(.dateTime.year().month(.wide).locale(locale))
    }

    /// Formats month/year labels used in reports trend rows.
    func formatReportMonth(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        if locale.identifier.hasPrefix("zh") {
            let components = calendar.dateComponents([.year, .month], from: date)
            if let year = components.year, let month = components.month {
                return "\(year % 100)年\(month)月"
            }
        }

        return date.formatted(.dateTime.month(.abbreviated).year().locale(locale))
    }

    /// Formats compact month labels used on report charts.
    func formatReportChartMonth(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        if locale.identifier.hasPrefix("zh") {
            let month = calendar.component(.month, from: date)
            return "\(month)月"
        }

        return date.formatted(.dateTime.month(.abbreviated).locale(locale))
    }
    
    /// Formats a week range for weekly views
    func formatWeekRange(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        guard let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        ),
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return formatTransactionDate(date, locale: locale)
        }
        
        let startStr = weekStart.formatted(.dateTime.month(.abbreviated).day().locale(locale))
        let endStr = weekEnd.formatted(.dateTime.month(.abbreviated).day().locale(locale))
        
        return "\(startStr) - \(endStr)"
    }
    
    // MARK: - Relative Formatting
    
    /// Formats a relative date (e.g., "2 days ago", "in 3 weeks")
    func formatRelative(_ date: Date, locale: Locale = AppLocalization.locale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
    
    // MARK: - Date Range Utilities
    
    /// Returns the start of day in UTC
    func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
    
    /// Returns the end of day (23:59:59.999)
    func endOfDay(_ date: Date) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfDay(date))!
    }
    
    /// Returns the date range for a month
    func monthRange(for date: Date) -> (start: Date, end: Date) {
        let startComponents = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: startComponents)!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        return (start, end)
    }
    
    /// Returns the date range for a week
    func weekRange(for date: Date) -> (start: Date, end: Date) {
        let startComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = calendar.date(from: startComponents)!
        let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
        return (start, end)
    }
}
