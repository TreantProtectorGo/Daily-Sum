import Foundation
import SwiftData
import UserNotifications

protocol UserNotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationStatusValue() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeAllPendingNotificationRequests()
}

extension UNUserNotificationCenter: UserNotificationCenterProtocol {
    func authorizationStatusValue() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}

@MainActor
struct TransactionReminderScheduler {
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

    static let reminderLeadOptions = [0, 1, 3, 7]
    static let defaultReminderLeadDays = 1

    @discardableResult
    func requestAuthorizationIfNeeded() async throws -> Bool {
        let status = await notificationCenter.authorizationStatusValue()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        @unknown default:
            return false
        }
    }

    func syncReminders(for transactions: [Transaction], now: Date = .now) async throws {
        let status = await notificationCenter.authorizationStatusValue()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            return
        }

        for transaction in transactions where shouldScheduleReminder(for: transaction, now: now) {
            guard let templateId = transaction.recurringTemplateId else { continue }
            let identifier = Self.identifier(templateId: templateId, dueDate: transaction.date)
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])

            let content = UNMutableNotificationContent()
            content.title = AppLocalization.string(
                "schedule.reminder.title",
                defaultValue: "Scheduled transaction coming up"
            )
            content.body = transaction.notes
                ?? AppLocalization.string(
                    "schedule.reminder.body",
                    defaultValue: "A scheduled transaction is coming up soon."
                )
            content.sound = .default

            let leadDays = max(0, transaction.reminderLeadDays ?? Self.defaultReminderLeadDays)
            guard let reminderDate = calendar.date(byAdding: .day, value: -leadDays, to: transaction.date),
                  reminderDate > now else {
                continue
            }

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try await notificationCenter.add(request)
        }
    }

    func removeReminders(forTemplateId templateId: UUID) async {
        let prefix = "\(templateId.uuidString)_"
        let requests = await notificationCenter.pendingNotificationRequests()
        let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }

        guard !identifiers.isEmpty else { return }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeReminder(forTemplateId templateId: UUID, dueDate: Date) async {
        let identifier = Self.identifier(templateId: templateId, dueDate: dueDate)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func resyncAllPendingReminders(now: Date = .now) async throws {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> {
                !$0.isRecurringTemplate && $0.recurringTemplateId != nil
            }
        )
        let scheduledTransactions = try context.fetch(descriptor)
            .filter(\.isPendingScheduledOccurrence)
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let managedIdentifiers = pendingRequests
            .map(\.identifier)
            .filter(Self.isManagedReminderIdentifier)
        if !managedIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: managedIdentifiers)
        }
        try await syncReminders(for: scheduledTransactions, now: now)
    }

    static func identifier(templateId: UUID, dueDate: Date) -> String {
        "\(templateId.uuidString)_\(Self.dueDateToken(from: dueDate))"
    }

    private static func dueDateToken(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func isManagedReminderIdentifier(_ identifier: String) -> Bool {
        let parts = identifier.split(separator: "_", maxSplits: 1)
        guard parts.count == 2 else {
            return false
        }
        return UUID(uuidString: String(parts[0])) != nil
    }

    private func shouldScheduleReminder(for transaction: Transaction, now: Date) -> Bool {
        guard transaction.isPendingScheduledOccurrence else {
            return false
        }
        return transaction.date > now
    }
}
