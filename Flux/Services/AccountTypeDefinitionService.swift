import Foundation
import SwiftData

@MainActor
@Observable
final class AccountTypeDefinitionService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func create(
        name: String,
        icon: String,
        colorHex: String,
        isSystemDefault: Bool = false,
        legacyType: AccountType? = nil
    ) throws -> AccountTypeDefinition {
        let definition = AccountTypeDefinition(
            name: normalizedName(name),
            icon: icon,
            colorHex: colorHex,
            isSystemDefault: isSystemDefault,
            sortOrder: nextSortOrder(),
            legacyType: legacyType
        )
        context.insert(definition)
        try context.save()
        return definition
    }

    func fetch() throws -> [AccountTypeDefinition] {
        let descriptor = FetchDescriptor<AccountTypeDefinition>(
            sortBy: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.name)
            ]
        )
        return try context.fetch(descriptor)
    }

    func fetch(legacyType: AccountType) throws -> AccountTypeDefinition? {
        let rawValue = legacyType.rawValue
        let descriptor = FetchDescriptor<AccountTypeDefinition>(
            predicate: #Predicate { $0.legacyTypeRawValue == rawValue },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try context.fetch(descriptor).first
    }

    func update(
        _ definition: AccountTypeDefinition,
        name: String? = nil,
        icon: String? = nil,
        colorHex: String? = nil
    ) throws {
        if let name {
            definition.name = normalizedName(name)
        }
        if let icon {
            definition.icon = icon
        }
        if let colorHex {
            definition.colorHex = colorHex
        }
        try context.save()
    }

    func delete(_ definition: AccountTypeDefinition) throws {
        guard accounts(using: definition).isEmpty else {
            throw AccountTypeDefinitionError.typeInUse
        }

        context.delete(definition)
        try context.save()
    }

    func reassignAndDelete(
        _ definition: AccountTypeDefinition,
        replacement: AccountTypeDefinition
    ) throws {
        guard definition.id != replacement.id else {
            throw AccountTypeDefinitionError.replacementMatchesDeletedType
        }

        for account in accounts(using: definition) {
            account.typeDefinition = replacement
            if let legacyType = replacement.legacyType {
                account.type = legacyType
            }
            account.icon = replacement.icon
            account.colorHex = replacement.colorHex
        }

        context.delete(definition)
        try context.save()
    }

    enum AccountTypeDefinitionError: LocalizedError, Equatable {
        case typeInUse
        case replacementMatchesDeletedType

        var errorDescription: String? {
            switch self {
            case .typeInUse:
                return "This account type is used by one or more accounts."
            case .replacementMatchesDeletedType:
                return "Choose a different replacement account type."
            }
        }
    }

    private func accounts(using definition: AccountTypeDefinition) -> [Account] {
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        return accounts.filter { $0.typeDefinition?.id == definition.id }
    }

    private func nextSortOrder() -> Int {
        let definitions = (try? fetch()) ?? []
        return (definitions.map(\.sortOrder).max() ?? -1) + 1
    }

    private func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
