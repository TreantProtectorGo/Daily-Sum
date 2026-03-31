import Foundation

struct ImportReport: Codable, Equatable {
    var archiveId: UUID
    var schemaVersion: Int
    var summary: ImportReportSummary
    var entries: [ImportReportEntry]
    var conflictReasons: [String]
    var createdAt: Date
}

struct ImportReportSummary: Codable, Equatable {
    var importedCount: Int
    var updatedCount: Int
    var skippedCount: Int
    var failedCount: Int
    var warningCount: Int
}

struct ImportReportEntry: Codable, Equatable {
    var entityType: String
    var entityId: UUID?
    var action: ImportReportAction
    var severity: ImportReportSeverity
    var message: String
    var conflictReason: String?
    var details: [String: String]
}

enum ImportReportAction: String, Codable, Equatable {
    case imported
    case updated
    case skipped
    case failed
}

enum ImportReportSeverity: String, Codable, Equatable {
    case info
    case warning
    case error
    case fatal
}
