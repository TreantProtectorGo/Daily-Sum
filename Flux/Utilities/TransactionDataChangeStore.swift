import Observation

@Observable
@MainActor
final class TransactionDataChangeStore {
    static let shared = TransactionDataChangeStore()

    private(set) var revision = 0

    func markChanged() {
        revision += 1
    }
}
