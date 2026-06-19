import AppIntents

struct OpenFluxIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Daily Sum"
    static let description = IntentDescription("Open Daily Sum to the main screen.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Expense"
    static let description = IntentDescription("Open Daily Sum and start adding an expense.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    func perform() async throws -> some IntentResult {
        await ActionButtonShortcutRouter.shared.requestTransactionEntry(type: .expense)
        return .result()
    }
}

struct AddIncomeIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Income"
    static let description = IntentDescription("Open Daily Sum and start adding income.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    func perform() async throws -> some IntentResult {
        await ActionButtonShortcutRouter.shared.requestTransactionEntry(type: .income)
        return .result()
    }
}

struct FluxAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenFluxIntent(),
            phrases: [
                "Open \(.applicationName)"
            ],
            shortTitle: "Open Daily Sum",
            systemImageName: "arrow.up.forward.app"
        )

        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add an expense in \(.applicationName)"
            ],
            shortTitle: "Add Expense",
            systemImageName: "minus.circle"
        )

        AppShortcut(
            intent: AddIncomeIntent(),
            phrases: [
                "Add income in \(.applicationName)"
            ],
            shortTitle: "Add Income",
            systemImageName: "plus.circle"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .navy
}
