import Foundation
import Observation

struct PendingTransactionEntry: Identifiable, Equatable {
    let id = UUID()
    let type: TransactionType
}

enum ActionButtonShortcutRoute: Equatable {
    case openApp
    case transaction(TransactionType)

    static func resolve(_ url: URL) -> Self? {
        guard url.scheme == "dailysum" else { return nil }

        switch (url.host, url.path) {
        case ("open", ""):
            return .openApp
        case ("transaction", "/expense"):
            return .transaction(.expense)
        case ("transaction", "/income"):
            return .transaction(.income)
        default:
            return nil
        }
    }
}

@MainActor
@Observable
final class ActionButtonShortcutRouter {
    static let shared = ActionButtonShortcutRouter()

    var pendingTransactionEntry: PendingTransactionEntry?

    func requestTransactionEntry(type: TransactionType) {
        pendingTransactionEntry = PendingTransactionEntry(type: type)
    }

    func handle(_ url: URL) {
        guard let route = ActionButtonShortcutRoute.resolve(url) else { return }

        if case let .transaction(type) = route {
            requestTransactionEntry(type: type)
        }
    }
}
