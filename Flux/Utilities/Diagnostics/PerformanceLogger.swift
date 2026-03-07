import Foundation
import os

enum PerformanceLogger {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Flux",
        category: "Performance"
    )

    @discardableResult
    static func start(_ name: String, metadata: String? = nil) -> Date {
        let startTime = Date()
        if let metadata {
            logger.debug("[PERF][START] \(name, privacy: .public) | \(metadata, privacy: .public)")
        } else {
            logger.debug("[PERF][START] \(name, privacy: .public)")
        }
        return startTime
    }

    static func end(_ name: String, from startTime: Date, metadata: String? = nil) {
        let elapsedMs = Date().timeIntervalSince(startTime) * 1000
        let elapsedText = String(format: "%.2fms", elapsedMs)
        if let metadata {
            logger.debug(
                "[PERF][END] \(name, privacy: .public) | elapsed=\(elapsedText, privacy: .public) | \(metadata, privacy: .public)"
            )
        } else {
            logger.debug(
                "[PERF][END] \(name, privacy: .public) | elapsed=\(elapsedText, privacy: .public)"
            )
        }
    }

    static func mark(_ name: String, metadata: String? = nil) {
        if let metadata {
            logger.debug("[PERF][MARK] \(name, privacy: .public) | \(metadata, privacy: .public)")
        } else {
            logger.debug("[PERF][MARK] \(name, privacy: .public)")
        }
    }
}
