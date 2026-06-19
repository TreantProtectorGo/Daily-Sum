import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct OpenDailySumControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.dailysum.control.open") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "dailysum://open")!)) {
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
            ControlWidgetButton(action: OpenURLIntent(URL(string: "dailysum://transaction/expense")!)) {
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
            ControlWidgetButton(action: OpenURLIntent(URL(string: "dailysum://transaction/income")!)) {
                Label("Add Income", systemImage: "plus.circle")
            }
        }
        .displayName("Add Income")
        .description("Open Daily Sum and add income.")
    }
}
