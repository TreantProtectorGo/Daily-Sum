import Foundation

struct BackupFileSummary: Identifiable, Equatable {
    var id: URL { url }

    var url: URL
    var filename: String
    var exportedAt: Date
    var fileSize: Int64
    var exportSourceDevice: String
    var recordCounts: BackupRecordCounts
    var archiveId: UUID
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
            defaultValue: "%1$@, %2$@, %3$@",
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
            formattedSize(for: backup)
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
    func writeBackupArchive(_ archive: BackupArchive) throws -> BackupFileSummary
    func readBackupData(for backup: BackupFileSummary) throws -> Data
    func deleteBackup(_ backup: BackupFileSummary) throws
}

@MainActor
final class BackupFileStore: BackupFileStoring {
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
        try ensureDirectoryExists(directory)

        let fileURLs = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        return fileURLs
            .filter { $0.pathExtension == "json" }
            .compactMap { try? makeSummary(for: $0) }
            .sorted { lhs, rhs in
                if lhs.exportedAt == rhs.exportedAt {
                    return lhs.filename > rhs.filename
                }
                return lhs.exportedAt > rhs.exportedAt
            }
    }

    func writeBackupArchive(_ archive: BackupArchive) throws -> BackupFileSummary {
        let directory = try backupDirectory()
        try ensureDirectoryExists(directory)

        let filename = makeFilename(exportedAt: archive.exportedAt)
        let fileURL = uniqueFileURL(in: directory, filename: filename)
        let data = try BackupArchiveCodec.encode(archive)
        try data.write(to: fileURL, options: [.atomic])
        return try makeSummary(for: fileURL)
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

    private func backupDirectory() throws -> URL {
        if let explicitDirectory {
            return explicitDirectory
        }

        if let iCloudContainerIdentifier,
           let ubiquityURL = fileManager.url(forUbiquityContainerIdentifier: iCloudContainerIdentifier) {
            return ubiquityURL
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent("Backups", isDirectory: true)
        }

        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documentsURL.appendingPathComponent("Backups", isDirectory: true)
    }

    private func ensureDirectoryExists(_ directory: URL) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    private func makeSummary(for fileURL: URL) throws -> BackupFileSummary {
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
            archiveId: archive.integrityMetadata.archiveId
        )
    }

    private func makeFilename(exportedAt: Date) -> String {
        "Flux_\(Self.filenameDateFormatter.string(from: exportedAt)).json"
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
