import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct OpenDailySumControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Daily Sum"
    static let supportedModes: IntentModes = .foreground(.immediate)

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "dailysum://open")!))
    }
}

struct AddExpenseControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Expense"
    static let supportedModes: IntentModes = .foreground(.immediate)

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "dailysum://transaction/expense")!))
    }
}

struct AddIncomeControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Income"
    static let supportedModes: IntentModes = .foreground(.immediate)

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "dailysum://transaction/income")!))
    }
}

struct OpenDailySumControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.dailysum.control.open") {
            ControlWidgetButton(action: OpenDailySumControlIntent()) {
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
            ControlWidgetButton(action: AddExpenseControlIntent()) {
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
            ControlWidgetButton(action: AddIncomeControlIntent()) {
                Label("Add Income", systemImage: "plus.circle")
            }
        }
        .displayName("Add Income")
        .description("Open Daily Sum and add income.")
    }
}
