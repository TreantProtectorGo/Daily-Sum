import Foundation
import Observation

struct PendingTransactionEntry: Identifiable, Equatable {
    let id = UUID()
    let type: TransactionType
}

@MainActor
@Observable
final class ActionButtonShortcutRouter {
    static let shared = ActionButtonShortcutRouter()

    var pendingTransactionEntry: PendingTransactionEntry?

    func requestTransactionEntry(type: TransactionType) {
        pendingTransactionEntry = PendingTransactionEntry(type: type)
    }
}
