import Foundation

enum BackupFileKind: String, Equatable {
    case manual
    case automatic
}

enum BackupStorageLocation: Equatable {
    case iCloudDrive
    case thisDevice

    var localizedTitle: String {
        switch self {
        case .iCloudDrive:
            AppLocalization.string(
                "settings.backup.location.iCloudDrive",
                defaultValue: "iCloud Drive"
            )
        case .thisDevice:
            AppLocalization.string(
                "settings.backup.location.thisDevice",
                defaultValue: "This Device"
            )
        }
    }
}

struct BackupFileSummary: Identifiable, Equatable {
    var id: URL { url }

    var url: URL
    var filename: String
    var exportedAt: Date
    var fileSize: Int64
    var exportSourceDevice: String
    var recordCounts: BackupRecordCounts
    var archiveId: UUID
    var backupKind: BackupFileKind = .manual
    var storageLocation: BackupStorageLocation = .thisDevice

    var isAutomatic: Bool {
        backupKind == .automatic
    }
}

struct BackupFileDisplayFormatter {
    var locale: Locale
    var timeZone: TimeZone

    init(
        locale: Locale = AppLocalization.locale,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.locale = locale
        self.timeZone = timeZone
    }

    func title(for backup: BackupFileSummary) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: backup.exportedAt)
    }

    func subtitle(for backup: BackupFileSummary) -> String {
        AppLocalization.formatted(
            "settings.backup.record.summary",
            defaultValue: "%1$@, %2$@, %3$@, %4$@",
            localizedCount(
                backup.recordCounts.accounts,
                singularKey: "settings.backup.record.accounts.one",
                singularDefault: "%lld account",
                pluralKey: "settings.backup.record.accounts.other",
                pluralDefault: "%lld accounts"
            ),
            localizedCount(
                backup.recordCounts.transactions,
                singularKey: "settings.backup.record.transactions.one",
                singularDefault: "%lld transaction",
                pluralKey: "settings.backup.record.transactions.other",
                pluralDefault: "%lld transactions"
            ),
            formattedSize(for: backup),
            backup.storageLocation.localizedTitle
        )
    }

    private func formattedSize(for backup: BackupFileSummary) -> String {
        ByteCountFormatter.string(fromByteCount: backup.fileSize, countStyle: .file)
    }

    private func localizedCount(
        _ count: Int,
        singularKey: String,
        singularDefault: String,
        pluralKey: String,
        pluralDefault: String
    ) -> String {
        AppLocalization.formatted(
            count == 1 ? singularKey : pluralKey,
            defaultValue: count == 1 ? singularDefault : pluralDefault,
            Int64(count)
        )
    }
}

@MainActor
protocol BackupFileStoring {
    func listBackups() throws -> [BackupFileSummary]
    func writeBackupArchive(_ archive: BackupArchive, kind: BackupFileKind) throws -> BackupFileSummary
    func readBackupData(for backup: BackupFileSummary) throws -> Data
    func deleteBackup(_ backup: BackupFileSummary) throws
}

extension BackupFileStoring {
    func writeBackupArchive(_ archive: BackupArchive) throws -> BackupFileSummary {
        try writeBackupArchive(archive, kind: .manual)
    }
}

@MainActor
final class BackupFileStore: BackupFileStoring {
    private struct ResolvedBackupDirectory {
        var url: URL
        var storageLocation: BackupStorageLocation
    }

    private let fileManager: FileManager
    private let explicitDirectory: URL?
    private let iCloudContainerIdentifier: String?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.explicitDirectory = nil
        self.iCloudContainerIdentifier = "iCloud.com.aegis.flux"
    }

    init(
        fileManager: FileManager = .default,
        iCloudContainerIdentifier: String?
    ) {
        self.fileManager = fileManager
        self.explicitDirectory = nil
        self.iCloudContainerIdentifier = iCloudContainerIdentifier
    }

    init(directory: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.explicitDirectory = directory
        self.iCloudContainerIdentifier = nil
    }

    func listBackups() throws -> [BackupFileSummary] {
        let directory = try backupDirectory()
        try ensureDirectoryExists(directory.url)

        let fileURLs = try fileManager.contentsOfDirectory(
            at: directory.url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        return fileURLs
            .filter { $0.pathExtension == "json" }
            .compactMap {
                try? makeSummary(for: $0, storageLocation: directory.storageLocation)
            }
            .sorted { lhs, rhs in
                if lhs.exportedAt == rhs.exportedAt {
                    return lhs.filename > rhs.filename
                }
                return lhs.exportedAt > rhs.exportedAt
            }
    }

    func writeBackupArchive(
        _ archive: BackupArchive,
        kind: BackupFileKind
    ) throws -> BackupFileSummary {
        let directory = try backupDirectory()
        try ensureDirectoryExists(directory.url)

        let filename = makeFilename(exportedAt: archive.exportedAt, kind: kind)
        let fileURL = uniqueFileURL(in: directory.url, filename: filename)
        let data = try BackupArchiveCodec.encode(archive)
        try data.write(to: fileURL, options: [.atomic])
        return try makeSummary(for: fileURL, storageLocation: directory.storageLocation)
    }

    func readBackupData(for backup: BackupFileSummary) throws -> Data {
        try Data(contentsOf: backup.url)
    }

    func deleteBackup(_ backup: BackupFileSummary) throws {
        guard fileManager.fileExists(atPath: backup.url.path) else {
            return
        }

        try fileManager.removeItem(at: backup.url)
    }

    private func backupDirectory() throws -> ResolvedBackupDirectory {
        if let explicitDirectory {
            return ResolvedBackupDirectory(url: explicitDirectory, storageLocation: .thisDevice)
        }

        if let iCloudContainerIdentifier,
           let ubiquityURL = fileManager.url(forUbiquityContainerIdentifier: iCloudContainerIdentifier) {
            let url = ubiquityURL
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent("Backups", isDirectory: true)
            return ResolvedBackupDirectory(url: url, storageLocation: .iCloudDrive)
        }

        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return ResolvedBackupDirectory(
            url: documentsURL.appendingPathComponent("Backups", isDirectory: true),
            storageLocation: .thisDevice
        )
    }

    private func ensureDirectoryExists(_ directory: URL) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    private func makeSummary(
        for fileURL: URL,
        storageLocation: BackupStorageLocation
    ) throws -> BackupFileSummary {
        let data = try Data(contentsOf: fileURL)
        let archive = try BackupArchiveCodec.decode(data)
        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])

        return BackupFileSummary(
            url: fileURL,
            filename: fileURL.lastPathComponent,
            exportedAt: archive.exportedAt,
            fileSize: Int64(resourceValues.fileSize ?? data.count),
            exportSourceDevice: archive.exportSourceDevice,
            recordCounts: archive.integrityMetadata.recordCounts,
            archiveId: archive.integrityMetadata.archiveId,
            backupKind: backupKind(for: fileURL),
            storageLocation: storageLocation
        )
    }

    private func makeFilename(exportedAt: Date, kind: BackupFileKind) -> String {
        let prefix = kind == .automatic ? "DailySum_Auto" : "DailySum"
        return "\(prefix)_\(Self.filenameDateFormatter.string(from: exportedAt)).json"
    }

    private func backupKind(for fileURL: URL) -> BackupFileKind {
        let filename = fileURL.lastPathComponent
        return filename.hasPrefix("DailySum_Auto_") || filename.hasPrefix("Flux_Auto_")
            ? .automatic
            : .manual
    }

    private func uniqueFileURL(in directory: URL, filename: String) -> URL {
        let initialURL = directory.appendingPathComponent(filename, isDirectory: false)
        guard fileManager.fileExists(atPath: initialURL.path) else {
            return initialURL
        }

        let baseName = (filename as NSString).deletingPathExtension
        let pathExtension = (filename as NSString).pathExtension

        for index in 2... {
            let candidate = directory.appendingPathComponent(
                "\(baseName)-\(index).\(pathExtension)",
                isDirectory: false
            )
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return initialURL
    }

    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
