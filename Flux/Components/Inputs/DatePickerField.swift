import SwiftUI

// MARK: - Date Picker Field

/// A styled date picker field with glass background
struct DatePickerField: View {
    @Binding var date: Date
    let label: String
    let displayedComponents: DatePicker.Components
    
    init(
        _ label: String,
        date: Binding<Date>,
        displayedComponents: DatePicker.Components = [.date, .hourAndMinute]
    ) {
        self.label = label
        self._date = date
        self.displayedComponents = displayedComponents
    }
    
    var body: some View {
        HStack {
            Label(label, systemImage: "calendar")
                .foregroundStyle(.secondary)
            
            Spacer()
            
            DatePicker(
                "",
                selection: $date,
                displayedComponents: displayedComponents
            )
            .labelsHidden()
        }
        .padding()
        .glassBackground(cornerRadius: 12, isInteractive: true)
    }
}

// MARK: - Date Range Picker

/// A picker for selecting a date range
struct DateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    var body: some View {
        VStack(spacing: 12) {
            // Start date
            HStack {
                Text(String(localized: "date.from", defaultValue: "From"))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                DatePicker(
                    "",
                    selection: $startDate,
                    in: ...endDate,
                    displayedComponents: .date
                )
                .labelsHidden()
            }
            
            GlassDivider()
            
            // End date
            HStack {
                Text(String(localized: "date.to", defaultValue: "To"))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                DatePicker(
                    "",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: .date
                )
                .labelsHidden()
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }
}

// MARK: - Quick Date Selection

/// Predefined date ranges for quick selection
struct QuickDateSelection: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    enum QuickRange: String, CaseIterable, Identifiable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case thisYear = "This Year"
        case custom = "Custom"
        
        var id: String { rawValue }
        
        var localizedName: String {
            switch self {
            case .today:
                String(localized: "date.quick.today", defaultValue: "Today")
            case .thisWeek:
                String(localized: "date.quick.thisWeek", defaultValue: "This Week")
            case .thisMonth:
                String(localized: "date.quick.thisMonth", defaultValue: "This Month")
            case .lastMonth:
                String(localized: "date.quick.lastMonth", defaultValue: "Last Month")
            case .thisYear:
                String(localized: "date.quick.thisYear", defaultValue: "This Year")
            case .custom:
                String(localized: "date.quick.custom", defaultValue: "Custom")
            }
        }
        
        func dateRange() -> (start: Date, end: Date)? {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .today:
                let start = calendar.startOfDay(for: now)
                let end = calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
                return (start, end)
                
            case .thisWeek:
                let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!.addingTimeInterval(-1)
                return (start, end)
                
            case .thisMonth:
                let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let end = calendar.date(byAdding: .month, value: 1, to: start)!.addingTimeInterval(-1)
                return (start, end)
                
            case .lastMonth:
                let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let start = calendar.date(byAdding: .month, value: -1, to: thisMonth)!
                let end = thisMonth.addingTimeInterval(-1)
                return (start, end)
                
            case .thisYear:
                let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
                let end = calendar.date(byAdding: .year, value: 1, to: start)!.addingTimeInterval(-1)
                return (start, end)
                
            case .custom:
                return nil
            }
        }
    }
    
    @State private var selectedRange: QuickRange = .thisMonth
    @State private var showCustomPicker = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Quick selection chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(QuickRange.allCases) { range in
                        QuickRangeChip(
                            range: range,
                            isSelected: selectedRange == range
                        ) {
                            selectedRange = range
                            if let dates = range.dateRange() {
                                startDate = dates.start
                                endDate = dates.end
                            } else {
                                showCustomPicker = true
                            }
                        }
                    }
                }
            }
            
            // Custom date picker
            if selectedRange == .custom || showCustomPicker {
                DateRangePicker(startDate: $startDate, endDate: $endDate)
            }
        }
    }
}

// MARK: - Quick Range Chip

private struct QuickRangeChip: View {
    let range: QuickDateSelection.QuickRange
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            Text(range.localizedName)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        .foregroundStyle(isSelected ? .blue : .secondary)
        .glassBackground(cornerRadius: 20, isInteractive: true)
    }
}

// MARK: - Preview

#Preview("Date Pickers") {
    struct PreviewWrapper: View {
        @State private var date = Date()
        @State private var startDate = Date()
        @State private var endDate = Date()
        
        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    // Single date picker
                    ZStack {
                        Color.blue.opacity(0.2)
                        DatePickerField("Transaction Date", date: $date)
                            .padding()
                    }
                    .frame(height: 100)
                    
                    Divider()
                    
                    // Date range picker
                    ZStack {
                        Color.purple.opacity(0.2)
                        DateRangePicker(startDate: $startDate, endDate: $endDate)
                            .padding()
                    }
                    .frame(height: 180)
                    
                    Divider()
                    
                    // Quick selection
                    ZStack {
                        Color.green.opacity(0.2)
                        QuickDateSelection(startDate: $startDate, endDate: $endDate)
                            .padding()
                    }
                    .frame(height: 150)
                }
            }
        }
    }
    
    return PreviewWrapper()
}
