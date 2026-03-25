import Foundation
import SwiftData
import UserNotifications

@MainActor
struct BudgetAlertScheduler {
    private static let deliveryDelay: TimeInterval = 1

    private let context: ModelContext
    private let notificationCenter: UserNotificationCenterProtocol
    private let calendar: Calendar

    init(
        context: ModelContext,
        notificationCenter: UserNotificationCenterProtocol = UNUserNotificationCenter.current(),
        calendar: Calendar = .current
    ) {
        self.context = context
        self.notificationCenter = notificationCenter
        self.calendar = calendar
    }

    func syncAlerts(for date: Date = .now) async throws {
        let status = await notificationCenter.authorizationStatusValue()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            return
        }

        let alerts = try BudgetService(context: context).triggeredAlerts(for: date)
        for alert in alerts {
            let periodStart = alert.budget.period.dateRange(containing: date, calendar: calendar).start
            let identifier = Self.identifier(
                budgetId: alert.budget.id,
                periodStart: periodStart,
                stage: alert.stage
            )
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])

            let content = UNMutableNotificationContent()
            content.title = title(for: alert.stage)
            content.body = body(for: alert)
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: Self.deliveryDelay,
                    repeats: false
                )
            )
            try await notificationCenter.add(request)
        }
    }

    static func identifier(
        budgetId: UUID,
        periodStart: Date,
        stage: BudgetService.BudgetAlertStage
    ) -> String {
        "budget_\(budgetId.uuidString)_\(periodToken(from: periodStart))_\(stageToken(for: stage))"
    }

    private func title(for stage: BudgetService.BudgetAlertStage) -> String {
        switch stage {
        case .warning:
            AppLocalization.string(
                "budget.alert.notification.warning.title",
                defaultValue: "Budget nearing limit"
            )
        case .exceeded:
            AppLocalization.string(
                "budget.alert.notification.exceeded.title",
                defaultValue: "Budget exceeded"
            )
        }
    }

    private func body(for alert: BudgetService.BudgetAlert) -> String {
        let budgetName = alert.budget.category?.displayName
            ?? AppLocalization.string("budget.allCategories", defaultValue: "All Categories")

        switch alert.stage {
        case .warning:
            return String.localizedStringWithFormat(
                AppLocalization.string(
                    "budget.alert.notification.warning.body",
                    defaultValue: "%@ has reached 80% of its budget."
                ),
                budgetName
            )
        case .exceeded:
            return String.localizedStringWithFormat(
                AppLocalization.string(
                    "budget.alert.notification.exceeded.body",
                    defaultValue: "%@ has exceeded its budget."
                ),
                budgetName
            )
        }
    }

    private static func periodToken(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func stageToken(for stage: BudgetService.BudgetAlertStage) -> String {
        switch stage {
        case .warning:
            return "warning"
        case .exceeded:
            return "exceeded"
        }
    }
}
