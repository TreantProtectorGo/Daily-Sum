import Foundation
import UserNotifications

final class ForegroundNotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationPresentationDelegate()
    nonisolated static let presentationOptions: UNNotificationPresentationOptions = [.banner, .list, .sound]

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Self.presentationOptions
    }
}
