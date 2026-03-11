import Foundation

/// Defines how FX conversion rates are selected for aggregate calculations.
enum ConversionMode: String, Codable, CaseIterable, Identifiable {
    /// Uses the most recent available rate.
    case latest
    /// Uses the rate effective on (or before) the requested date.
    case historical

    var id: String { rawValue }

    /// Best for net-worth style valuation cards.
    nonisolated static let defaultForDashboard: ConversionMode = .latest
    /// Best for period-based reports and trends.
    nonisolated static let defaultForReports: ConversionMode = .historical
}
