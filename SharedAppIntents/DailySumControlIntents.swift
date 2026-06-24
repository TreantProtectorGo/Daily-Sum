import AppIntents
import Observation

struct PendingDailySumControlDestination: Identifiable, Equatable {
    let id = UUID()
    let destination: DailySumControlDestination
}

@MainActor
@Observable
final class DailySumControlIntentRouter {
    static let shared = DailySumControlIntentRouter()

    var pendingDestination: PendingDailySumControlDestination?

    func request(_ destination: DailySumControlDestination) {
        pendingDestination = PendingDailySumControlDestination(destination: destination)
    }

    func clearPendingDestination() {
        pendingDestination = nil
    }
}

enum DailySumControlDestination: String, AppEnum {
    case open
    case expense
    case income

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Daily Sum Action")

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .open: "Open Daily Sum",
        .expense: "Add Expense",
        .income: "Add Income"
    ]
}

struct OpenDailySumControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Daily Sum"
    static let description = IntentDescription("Open Daily Sum.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(title: "Action")
    var target: DailySumControlDestination

    init() {
        self.target = .open
    }

    init(target: DailySumControlDestination) {
        self.target = target
    }

    func perform() async throws -> some IntentResult {
        await DailySumControlIntentRouter.shared.request(target)
        return .result()
    }
}
