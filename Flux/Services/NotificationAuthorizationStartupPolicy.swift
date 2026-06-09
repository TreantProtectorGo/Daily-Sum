import UserNotifications

enum NotificationAuthorizationStartupPolicy {
    private static let skipOnLaunchFlag = "-FluxSkipNotificationAuthorizationOnLaunch"

    static func shouldRequestOnAppLaunch(for status: UNAuthorizationStatus) -> Bool {
        if ProcessInfo.processInfo.arguments.contains(skipOnLaunchFlag) {
            return false
        }
        return status == .notDetermined
    }
}
