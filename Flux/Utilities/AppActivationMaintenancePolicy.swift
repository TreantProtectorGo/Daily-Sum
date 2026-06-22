import Foundation

struct AppActivationMaintenancePolicy {
    static let defaultMinimumInterval: TimeInterval = 15 * 60

    private let defaults: UserDefaults
    private let minimumInterval: TimeInterval
    private let lastRunKey: String
    let interactionGracePeriod: Duration

    init(
        defaults: UserDefaults = .standard,
        minimumInterval: TimeInterval = defaultMinimumInterval,
        lastRunKey: String = "flux.appActivationMaintenance.lastRunAt",
        interactionGracePeriod: Duration = .milliseconds(1_200)
    ) {
        self.defaults = defaults
        self.minimumInterval = minimumInterval
        self.lastRunKey = lastRunKey
        self.interactionGracePeriod = interactionGracePeriod
    }

    @discardableResult
    func claimRun(at now: Date = .now) -> Bool {
        if let lastRunAt = defaults.object(forKey: lastRunKey) as? Date,
           now.timeIntervalSince(lastRunAt) < minimumInterval {
            return false
        }

        recordRun(at: now)
        return true
    }

    func recordRun(at date: Date = .now) {
        defaults.set(date, forKey: lastRunKey)
    }

    func waitForInteractionGracePeriod() async throws {
        try await Task.sleep(for: interactionGracePeriod)
    }
}
