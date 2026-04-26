import Foundation
import SwiftData

enum AutomaticBackupFrequency: String, CaseIterable, Identifiable {
    case never
    case daily
    case weekly
    case monthly

    var id: Self { self }

    var localizedTitle: String {
        switch self {
        case .never:
            AppLocalization.string("settings.backup.automatic.never", defaultValue: "Never")
        case .daily:
            AppLocalization.string("settings.backup.automatic.daily", defaultValue: "Daily")
        case .weekly:
            AppLocalization.string("settings.backup.automatic.weekly", defaultValue: "Weekly")
        case .monthly:
            AppLocalization.string("settings.backup.automatic.monthly", defaultValue: "Monthly")
        }
    }

    func isDue(lastBackupAt: Date?, now: Date) -> Bool {
        guard self != .never else { return false }
        guard let lastBackupAt else { return true }
        return now.timeIntervalSince(lastBackupAt) >= interval
    }

    private var interval: TimeInterval {
        switch self {
        case .never:
            .infinity
        case .daily:
            24 * 60 * 60
        case .weekly:
            7 * 24 * 60 * 60
        case .monthly:
            30 * 24 * 60 * 60
        }
    }
}

enum BackupRetentionLimit: String, CaseIterable, Identifiable {
    case count30
    case count50
    case count100
    case count200
    case count300
    case count500
    case noLimit

    var id: Self { self }

    var count: Int? {
        switch self {
        case .count30:
            30
        case .count50:
            50
        case .count100:
            100
        case .count200:
            200
        case .count300:
            300
        case .count500:
            500
        case .noLimit:
            nil
        }
    }

    var localizedTitle: String {
        switch self {
        case .count30:
            "30"
        case .count50:
            "50"
        case .count100:
            "100"
        case .count200:
            "200"
        case .count300:
            "300"
        case .count500:
            "500"
        case .noLimit:
            AppLocalization.string("settings.backup.retention.noLimit", defaultValue: "No Limit")
        }
    }
}

enum AutomaticBackupPreference {
    private static let frequencyKey = "flux.backup.automatic.frequency"
    private static let retentionLimitKey = "flux.backup.retention.limit"
    private static let lastAutomaticBackupAtKey = "flux.backup.automatic.lastBackupAt"

    static var frequency: AutomaticBackupFrequency {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: frequencyKey) else {
                return .weekly
            }
            return AutomaticBackupFrequency(rawValue: rawValue) ?? .weekly
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: frequencyKey)
        }
    }

    static var retentionLimit: BackupRetentionLimit {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: retentionLimitKey) else {
                return .count50
            }
            return BackupRetentionLimit(rawValue: rawValue) ?? .count50
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: retentionLimitKey)
        }
    }

    static var lastAutomaticBackupAt: Date? {
        get {
            UserDefaults.standard.object(forKey: lastAutomaticBackupAtKey) as? Date
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: lastAutomaticBackupAtKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastAutomaticBackupAtKey)
            }
        }
    }
}

@MainActor
final class AutomaticBackupScheduler {
    private let backupExportService: any BackupExportServicing
    private let backupFileStore: any BackupFileStoring
    private let now: () -> Date

    init(
        backupExportService: any BackupExportServicing,
        backupFileStore: any BackupFileStoring,
        now: @escaping () -> Date = Date.init
    ) {
        self.backupExportService = backupExportService
        self.backupFileStore = backupFileStore
        self.now = now
    }

    convenience init(context: ModelContext) {
        self.init(
            backupExportService: BackupExportService(context: context),
            backupFileStore: BackupFileStore()
        )
    }

    func runIfNeeded() {
        let currentDate = now()
        let frequency = AutomaticBackupPreference.frequency
        guard frequency.isDue(
            lastBackupAt: AutomaticBackupPreference.lastAutomaticBackupAt,
            now: currentDate
        ) else {
            return
        }

        do {
            let archive = try backupExportService.makeBackupArchive()
            _ = try backupFileStore.writeBackupArchive(archive, kind: .automatic)
            AutomaticBackupPreference.lastAutomaticBackupAt = currentDate
            try pruneAutomaticBackups(limit: AutomaticBackupPreference.retentionLimit)
        } catch {
            print("Automatic backup failed: \(error.localizedDescription)")
        }
    }

    func pruneAutomaticBackups(limit: BackupRetentionLimit) throws {
        guard let maxCount = limit.count else { return }
        let automaticBackups = try backupFileStore.listBackups()
            .filter(\.isAutomatic)
            .sorted { lhs, rhs in
                lhs.exportedAt > rhs.exportedAt
            }

        for backup in automaticBackups.dropFirst(maxCount) {
            try backupFileStore.deleteBackup(backup)
        }
    }
}
