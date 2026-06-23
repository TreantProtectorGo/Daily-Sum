import AppIntents
import SwiftUI
import WidgetKit

struct OpenDailySumControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.dailysum.control.open") {
            ControlWidgetButton(action: OpenDailySumControlIntent(target: .open)) {
                Label("Open Daily Sum", systemImage: "wallet.bifold")
            }
        }
        .displayName("Open Daily Sum")
        .description("Open Daily Sum.")
    }
}

struct AddExpenseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.dailysum.control.expense") {
            ControlWidgetButton(action: OpenDailySumControlIntent(target: .expense)) {
                Label("Add Expense", systemImage: "minus.circle")
            }
        }
        .displayName("Add Expense")
        .description("Open Daily Sum and add an expense.")
    }
}

struct AddIncomeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.dailysum.control.income") {
            ControlWidgetButton(action: OpenDailySumControlIntent(target: .income)) {
                Label("Add Income", systemImage: "plus.circle")
            }
        }
        .displayName("Add Income")
        .description("Open Daily Sum and add income.")
    }
}
