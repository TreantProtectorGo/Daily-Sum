import SwiftUI
import WidgetKit

@main
struct DailySumControlsBundle: WidgetBundle {
    var body: some Widget {
        OpenDailySumControl()
        AddExpenseControl()
        AddIncomeControl()
    }
}
