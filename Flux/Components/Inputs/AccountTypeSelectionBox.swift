import SwiftUI
import SwiftData

struct AccountTypeSelectionBox: View {
    @Environment(\.modelContext) private var modelContext

    @Binding private var selection: AccountTypeDefinition?
    private let title: String

    @Query(sort: \AccountTypeDefinition.sortOrder) private var definitions: [AccountTypeDefinition]
    @State private var showSelectionSheet = false
    @State private var showManagement = false
    @State private var showManagementAfterSelectionDismisses = false

    init(title: String, selection: Binding<AccountTypeDefinition?>) {
        self.title = title
        self._selection = selection
    }

    var body: some View {
        Button {
            showSelectionSheet = true
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                IconColorCircle(
                    icon: selection?.icon ?? "wallet.bifold",
                    color: selection?.color ?? .secondary,
                    size: .small
                )

                Text(selection?.displayName ?? AppLocalization.string("account.type", defaultValue: "Account Type"))
                    .font(.body)
                    .foregroundStyle(selection == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selection?.displayName ?? AppLocalization.string("account.type", defaultValue: "Account Type"))
        .onAppear(perform: selectDefaultIfNeeded)
        .onChange(of: definitions.count) { _, _ in
            selectDefaultIfNeeded()
        }
        .sheet(
            isPresented: $showSelectionSheet,
            onDismiss: openManagementIfRequested
        ) {
            AccountTypeSelectionSheet(
                selection: $selection,
                definitions: definitions,
                showManagementAfterDismiss: $showManagementAfterSelectionDismisses
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showManagement) {
            AccountTypeDefinitionManagementSheet(selection: $selection)
        }
    }

    private func selectDefaultIfNeeded() {
        guard selection == nil else { return }
        selection = definitions.first
    }

    private func openManagementIfRequested() {
        guard showManagementAfterSelectionDismisses else { return }
        showManagementAfterSelectionDismisses = false
        showManagement = true
    }
}

private struct AccountTypeSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selection: AccountTypeDefinition?
    let definitions: [AccountTypeDefinition]
    @Binding var showManagementAfterDismiss: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 94))], spacing: 16) {
                    ForEach(definitions) { definition in
                        IconTitleGridItem(
                            title: definition.displayName,
                            tintColor: definition.color,
                            isSelected: selection?.id == definition.id
                        ) {
                            IconColorCircle(
                                icon: definition.icon,
                                color: definition.color,
                                size: .medium
                            )
                        } onSelect: {
                            selection = definition
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .navigationTitle(AppLocalization.string("account.type", defaultValue: "Account Type"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    IconToolbarButton(
                        systemName: "pencil",
                        accessibilityLabel: AppLocalization.string(
                            "accountType.editList",
                            defaultValue: "Edit account types"
                        )
                    ) {
                        showManagementAfterDismiss = true
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AccountTypeDefinitionManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding var selection: AccountTypeDefinition?

    @Query(sort: \AccountTypeDefinition.sortOrder) private var definitions: [AccountTypeDefinition]
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var editorMode: EditorMode?
    @State private var deleteCandidate: AccountTypeDefinition?
    @State private var reassignCandidate: AccountTypeDefinition?
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(definitions) { definition in
                        IconManagementListRow(
                            title: definition.displayName,
                            countText: "\(usageCount(for: definition))",
                            countAccessibilityLabel: accountCountText(for: definition),
                            tintColor: definition.color,
                            isSelected: selection?.id == definition.id
                        ) {
                            IconColorCircle(icon: definition.icon, color: definition.color, size: .small)
                        } onEdit: {
                            editorMode = .edit(definition)
                        } onDelete: {
                            deleteCandidate = definition
                        }
                        .draggable(definition.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            guard let draggedID = items.first else { return false }
                            return moveDefinition(draggedID, to: definition)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(AppLocalization.string("accountType.title", defaultValue: "Account Types"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    IconToolbarButton(
                        systemName: "checkmark",
                        accessibilityLabel: AppLocalization.string("action.finish", defaultValue: "Finish")
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    IconToolbarButton(
                        systemName: "plus",
                        accessibilityLabel: AppLocalization.string("action.add", defaultValue: "Add")
                    ) {
                        editorMode = .create
                    }
                }
            }
            .sheet(item: $editorMode) { mode in
                IconColorItemEditorSheet(
                    title: mode.title,
                    initialDraft: mode.initialDraft
                ) { draft in
                    try save(draft, mode: mode)
                }
            }
            .confirmationDialog(
                AppLocalization.string(
                    "accountType.delete.confirm.title",
                    defaultValue: "Delete Account Type?"
                ),
                isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let deleteCandidate {
                    let replacements = definitions.filter { $0.id != deleteCandidate.id }
                    if usageCount(for: deleteCandidate) == 0 {
                        Button(AppLocalization.string("action.delete", defaultValue: "Delete"), role: .destructive) {
                            deleteUnused(deleteCandidate)
                        }
                    } else {
                        ForEach(replacements) { replacement in
                            Button(
                                AppLocalization.formatted(
                                    "accountType.delete.moveAccounts",
                                    defaultValue: "Move accounts to %@",
                                    replacement.displayName
                                )
                            ) {
                                reassignAndDelete(deleteCandidate, replacement: replacement)
                            }
                        }
                    }

                    Button(
                        AppLocalization.string(
                            "accountType.delete.keep",
                            defaultValue: "Keep Account Type"
                        ),
                        role: .cancel
                    ) {
                        self.deleteCandidate = nil
                    }
                }
            } message: {
                if let deleteCandidate, usageCount(for: deleteCandidate) > 0 {
                    Text(
                        AppLocalization.string(
                            "accountType.delete.reassign.message",
                            defaultValue: "Choose another type for existing accounts before deleting."
                        )
                    )
                }
            }
            .alert(AppLocalization.string("error.title", defaultValue: "Error"), isPresented: $showError) {
                Button(AppLocalization.string("action.ok", defaultValue: "OK")) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func moveDefinition(_ draggedID: String, to target: AccountTypeDefinition) -> Bool {
        guard let draggedUUID = UUID(uuidString: draggedID),
              draggedUUID != target.id,
              let sourceIndex = definitions.firstIndex(where: { $0.id == draggedUUID }),
              let targetIndex = definitions.firstIndex(where: { $0.id == target.id }) else {
            return false
        }

        var reorderedDefinitions = definitions
        reorderedDefinitions.move(
            fromOffsets: IndexSet(integer: sourceIndex),
            toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
        )

        do {
            try AccountTypeDefinitionService(context: modelContext).reorder(reorderedDefinitions)
            return true
        } catch {
            show(error)
            return false
        }
    }

    private func save(_ draft: IconColorItemDraft, mode: EditorMode) throws {
        let service = AccountTypeDefinitionService(context: modelContext)
        switch mode {
        case .create:
            let created = try service.create(
                name: draft.name,
                icon: draft.icon,
                colorHex: draft.colorHex
            )
            selection = created
        case .edit(let definition):
            try service.update(
                definition,
                name: draft.name,
                icon: draft.icon,
                colorHex: draft.colorHex
            )
        }
    }

    private func deleteUnused(_ definition: AccountTypeDefinition) {
        do {
            try AccountTypeDefinitionService(context: modelContext).delete(definition)
            if selection?.id == definition.id {
                selection = definitions.first { $0.id != definition.id }
            }
            deleteCandidate = nil
        } catch {
            show(error)
        }
    }

    private func reassignAndDelete(
        _ definition: AccountTypeDefinition,
        replacement: AccountTypeDefinition
    ) {
        do {
            try AccountTypeDefinitionService(context: modelContext).reassignAndDelete(
                definition,
                replacement: replacement
            )
            if selection?.id == definition.id {
                selection = replacement
            }
            deleteCandidate = nil
        } catch {
            show(error)
        }
    }

    private func usageCount(for definition: AccountTypeDefinition) -> Int {
        accounts.filter { $0.typeDefinition?.id == definition.id }.count
    }

    private func accountCountText(for definition: AccountTypeDefinition) -> String {
        let count = usageCount(for: definition)
        let key = count == 1 ? "account.count.one" : "account.count.other"
        return AppLocalization.formatted(key, defaultValue: count == 1 ? "%lld account" : "%lld accounts", Int64(count))
    }

    private func show(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }

    private enum EditorMode: Identifiable {
        case create
        case edit(AccountTypeDefinition)

        var id: String {
            switch self {
            case .create:
                return "create"
            case .edit(let definition):
                return definition.id.uuidString
            }
        }

        var title: String {
            switch self {
            case .create:
                return AppLocalization.string("accountType.new", defaultValue: "New Account Type")
            case .edit:
                return AppLocalization.string("accountType.edit", defaultValue: "Edit Account Type")
            }
        }

        var initialDraft: IconColorItemDraft {
            switch self {
            case .create:
                return .empty
            case .edit(let definition):
                return IconColorItemDraft(
                    name: definition.name,
                    icon: definition.icon,
                    colorHex: definition.colorHex
                )
            }
        }
    }
}
