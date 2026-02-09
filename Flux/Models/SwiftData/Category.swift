import Foundation
import SwiftData
import SwiftUI

/// A transaction category (e.g., "Food", "Transport", "Salary")
@Model
final class Category {
    #Unique<Category>([\.id])
    
    var id: UUID
    
    /// Localization key for the category name (e.g., "category.food")
    /// For user-created categories, this stores the raw name
    var nameKey: String
    
    /// SF Symbol name for the category icon
    var icon: String
    
    /// Hex color string (e.g., "#FF5733")
    var colorHex: String
    
    /// Whether this is an income or expense category
    var type: TransactionType
    
    /// Whether this is a system-provided default category
    var isSystemDefault: Bool
    
    /// Parent category for subcategories (nil for top-level categories)
    @Relationship(deleteRule: .nullify)
    var parentCategory: Category?
    
    /// Child subcategories
    @Relationship(deleteRule: .cascade, inverse: \Category.parentCategory)
    var subcategories: [Category]
    
    /// Transactions in this category
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]
    
    /// Budgets associated with this category
    @Relationship(deleteRule: .nullify, inverse: \Budget.category)
    var budgets: [Budget]
    
    init(
        id: UUID = UUID(),
        nameKey: String,
        icon: String,
        colorHex: String,
        type: TransactionType,
        isSystemDefault: Bool = false,
        parentCategory: Category? = nil
    ) {
        self.id = id
        self.nameKey = nameKey
        self.icon = icon
        self.colorHex = colorHex
        self.type = type
        self.isSystemDefault = isSystemDefault
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
            String(localized: String.LocalizationValue(nameKey), table: "CategoryLocalizations")
        } else {
            // User-created categories store raw names
            nameKey
        }
    }
    
    /// Parses the hex color into a SwiftUI Color
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
    
    /// Whether this category has any transactions
    var hasTransactions: Bool {
        !transactions.isEmpty || subcategories.contains { $0.hasTransactions }
    }
    
    /// Total transaction count including subcategories
    var totalTransactionCount: Int {
        transactions.count + subcategories.reduce(0) { $0 + $1.totalTransactionCount }
    }
    
    /// Whether this is a subcategory
    var isSubcategory: Bool {
        parentCategory != nil
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
