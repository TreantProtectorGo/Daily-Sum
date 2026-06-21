import Foundation

struct AppActivationMaintenancePolicy {
    static let defaultMinimumInterval: TimeInterval = 15 * 60

    private let defaults: UserDefaults
    private let minimumInterval: TimeInterval
    private let lastRunKey: String

    init(
        defaults: UserDefaults = .standard,
        minimumInterval: TimeInterval = defaultMinimumInterval,
        lastRunKey: String = "flux.appActivationMaintenance.lastRunAt"
    ) {
        self.defaults = defaults
        self.minimumInterval = minimumInterval
        self.lastRunKey = lastRunKey
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
}
