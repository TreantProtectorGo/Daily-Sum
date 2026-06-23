import AppIntents

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

struct OpenDailySumControlIntent: OpenIntent, TargetContentProvidingIntent {
    static let title: LocalizedStringResource = "Open Daily Sum"
    static let description = IntentDescription("Open Daily Sum.")

    @Parameter(title: "Action")
    var target: DailySumControlDestination

    init() {
        self.target = .open
    }

    init(target: DailySumControlDestination) {
        self.target = target
    }
}
