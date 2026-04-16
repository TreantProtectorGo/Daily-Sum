import Foundation
import SwiftData

/// Stores skipped scheduled occurrences so generator won't recreate them.
@Model
final class ScheduledOccurrenceException {
    var id: UUID = UUID()
    var templateId: UUID = UUID()
    /// Stored as start-of-day in current calendar.
    var occurrenceDate: Date = Date()
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        templateId: UUID,
        occurrenceDate: Date,
        createdAt: Date = .now
    ) {
        self.id = id
        self.templateId = templateId
        self.occurrenceDate = occurrenceDate
        self.createdAt = createdAt
    }
}
