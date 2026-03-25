import UserNotifications

enum NotificationAuthorizationStartupPolicy {
    static func shouldRequestOnAppLaunch(for status: UNAuthorizationStatus) -> Bool {
        status == .notDetermined
    }
}
