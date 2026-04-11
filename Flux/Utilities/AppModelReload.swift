import Foundation

enum AppModelReload {
    static let requestedNotification = Notification.Name("flux.appModelReloadRequested")

    static func request() {
        NotificationCenter.default.post(name: requestedNotification, object: nil)
    }
}
