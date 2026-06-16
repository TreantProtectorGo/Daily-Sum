import Foundation
import SwiftData
import SwiftUI

/// A transaction category (e.g., "Food", "Transport", "Salary")
@Model
final class Category {
    var id: UUID = UUID()
    
    /// Localization key for the category name (e.g., "category.food")
    /// For user-created categories, this stores the raw name
    var nameKey: String = ""
    
    /// SF Symbol name for the category icon
    var icon: String = "tag"
    
    /// Hex color string (e.g., "#FF5733")
    var colorHex: String = "#808080"
    
    /// Whether this is an income or expense category
    var type: TransactionType = TransactionType.expense
    
    /// Whether this is a system-provided default category
    var isSystemDefault: Bool = false

    /// User-defined display order within the same category type.
    var sortOrder: Int = 0
    
    /// Parent category for subcategories (nil for top-level categories)
    @Relationship(deleteRule: .nullify)
    var parentCategory: Category?
    
    /// Child subcategories
    @Relationship(deleteRule: .cascade, inverse: \Category.parentCategory)
    var subcategories: [Category]? = []
    
    /// Transactions in this category
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]? = []
    
    /// Budgets associated with this category
    @Relationship(deleteRule: .nullify, inverse: \Budget.category)
    var budgets: [Budget]? = []
    
    init(
        id: UUID = UUID(),
        nameKey: String,
        icon: String,
        colorHex: String,
        type: TransactionType,
        isSystemDefault: Bool = false,
        sortOrder: Int = 0,
        parentCategory: Category? = nil
    ) {
        self.id = id
        self.nameKey = nameKey
        self.icon = icon
        self.colorHex = colorHex
        self.type = type
        self.isSystemDefault = isSystemDefault
        self.sortOrder = sortOrder
        self.parentCategory = parentCategory
        self.subcategories = []
        self.transactions = []
        self.budgets = []
    }
    
    // MARK: - Computed Properties
    
    /// Returns the localized display name
    var displayName: String {
        if isSystemDefault {
            // System categories use localization keys from CategoryLocalizations table
            let resolvedKey = Self.resolveSystemCategoryKey(nameKey)
            return AppLocalization.string(
                key: resolvedKey,
                table: "CategoryLocalizations"
            )
        } else {
            // User-created categories store raw names
            return nameKey
        }
    }
    
    /// Parses the hex color into a SwiftUI Color
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
    
    /// Whether this category has any transactions
    var hasTransactions: Bool {
        !(transactions ?? []).isEmpty || (subcategories ?? []).contains { $0.hasTransactions }
    }
    
    /// Total transaction count including subcategories
    var totalTransactionCount: Int {
        (transactions?.count ?? 0) + (subcategories ?? []).reduce(0) { $0 + $1.totalTransactionCount }
    }
    
    /// Whether this is a subcategory
    var isSubcategory: Bool {
        parentCategory != nil
    }

    // MARK: - Legacy System Category Resolution

    /// Canonical category localization keys used by system-provided categories.
    private static let systemCategoryKeys: [String] = [
        // Expense
        "category.expense.food",
        "category.expense.home",
        "category.expense.transport",
        "category.expense.shopping",
        "category.expense.entertainment",
        "category.expense.bills",
        "category.expense.insurance",
        "category.expense.tax",
        "category.expense.health",
        "category.expense.education",
        "category.expense.upskilling",
        "category.expense.pet",
        "category.expense.travel",
        "category.expense.groceries",
        "category.expense.dining",
        "category.expense.coffee",
        "category.expense.subscriptions",
        "category.expense.housing",
        "category.expense.personalCare",
        "category.expense.gifts",
        // Income
        "category.income.salary",
        "category.income.bonus",
        "category.income.freelance",
        "category.income.interest",
        "category.income.governmentSubsidy",
        "category.income.secondHandSale",
        "category.income.investment",
        "category.income.gift",
        "category.income.refund"
    ]

    /// Lookup for matching legacy localized names back to canonical keys.
    private static let legacyNameToKey: [String: String] = {
        var map: [String: String] = [:]
        let locales = ["en", "zh-Hans", "zh-Hant"]

        for key in systemCategoryKeys {
            map[normalizedLookupKey(for: key)] = key

            for locale in locales {
                guard let path = Bundle.main.path(forResource: locale, ofType: "lproj"),
                      let bundle = Bundle(path: path) else {
                    continue
                }

                let localized = bundle.localizedString(
                    forKey: key,
                    value: nil,
                    table: "CategoryLocalizations"
                )
                if localized != key {
                    map[normalizedLookupKey(for: localized)] = key
                }
            }
        }

        return map
    }()

    private static func resolveSystemCategoryKey(_ value: String) -> String {
        let normalizedValue = normalizedLookupKey(for: value)
        if let canonical = legacyNameToKey[normalizedValue] {
            return canonical
        }
        return value
    }

    private static func normalizedLookupKey(for value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

// MARK: - Color Extension for Hex Parsing

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        guard hexSanitized.count == 6,
              let rgb = UInt64(hexSanitized, radix: 16) else {
            return nil
        }
        
        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
    
    var hexString: String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#808080"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
