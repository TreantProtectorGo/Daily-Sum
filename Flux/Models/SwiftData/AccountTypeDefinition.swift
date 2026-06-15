import Foundation
import SwiftData
import SwiftUI

/// User-manageable account type metadata.
@Model
final class AccountTypeDefinition {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "wallet.pass"
    var colorHex: String = "#007AFF"
    var isSystemDefault: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var legacyTypeRawValue: String?

    @Relationship(deleteRule: .nullify, inverse: \Account.typeDefinition)
    var accounts: [Account]? = []

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorHex: String,
        isSystemDefault: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        legacyType: AccountType? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isSystemDefault = isSystemDefault
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.legacyTypeRawValue = legacyType?.rawValue
        self.accounts = []
    }

    var legacyType: AccountType? {
        get {
            guard let legacyTypeRawValue else { return nil }
            return AccountType(rawValue: legacyTypeRawValue)
        }
        set {
            legacyTypeRawValue = newValue?.rawValue
        }
    }

    var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    var displayName: String {
        guard isSystemDefault, let legacyType else { return name }
        return legacyType.localizedName
    }
}
