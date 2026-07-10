import Foundation

protocol RestoreSessionMarkerStoring {
    func save(_ marker: RestoreSessionMarker) throws
    func load() throws -> RestoreSessionMarker?
    func clear()
}

struct RestoreSessionMarker: Codable, Equatable {
    var restoreSessionId: UUID
    var startedAt: Date
    var archiveId: UUID
    var mode: BackupRestoreMode
    var scope: BackupRestoreScope
    var phase: RestorePhase
    var recoveryActionHint: String
}

final class RestoreSessionMarkerStore: RestoreSessionMarkerStoring {
    private static let storageKey = "flux.restoreSessionMarker"

    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        userDefaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
    }

    func save(_ marker: RestoreSessionMarker) throws {
        let data = try encoder.encode(marker)
        userDefaults.set(data, forKey: Self.storageKey)
    }

    func load() throws -> RestoreSessionMarker? {
        guard let data = userDefaults.data(forKey: Self.storageKey) else {
            return nil
        }
        return try decoder.decode(RestoreSessionMarker.self, from: data)
    }

    func clear() {
        userDefaults.removeObject(forKey: Self.storageKey)
    }
}

final class InMemoryRestoreSessionMarkerStore: RestoreSessionMarkerStoring {
    private var marker: RestoreSessionMarker?

    func save(_ marker: RestoreSessionMarker) throws {
        self.marker = marker
    }

    func load() throws -> RestoreSessionMarker? {
        marker
    }

    func clear() {
        marker = nil
    }
}

enum RestoreSessionStartupRecovery {
    /// Replace restores commit financial data once, so an interrupted marker only
    /// indicates an aborted attempt. Consume it at launch to avoid stale recovery state.
    static func consumeMarkerIfPresent(
        from store: any RestoreSessionMarkerStoring = RestoreSessionMarkerStore()
    ) -> RestoreSessionMarker? {
        let marker = try? store.load()
        store.clear()
        return marker
    }
}
