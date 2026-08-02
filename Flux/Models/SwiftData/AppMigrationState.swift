import Foundation
import SwiftData

/// A store-scoped marker for data migrations that must follow the SwiftData store across devices.
///
/// This intentionally lives in SwiftData instead of `UserDefaults`: CloudKit-backed stores can
/// therefore carry the completion marker to another device, and clearing device preferences does
/// not cause an already-completed data migration to seed deleted defaults again.
@Model
final class AppMigrationState {
    var id: UUID = UUID()
    var key: String = ""
    var completedAt: Date = Date()

    init(id: UUID = UUID(), key: String, completedAt: Date = .now) {
        self.id = id
        self.key = key
        self.completedAt = completedAt
    }
}
