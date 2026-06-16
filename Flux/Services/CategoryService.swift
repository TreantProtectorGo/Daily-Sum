import Foundation
import SwiftData

/// Service for managing Category CRUD operations
@MainActor
@Observable
final class CategoryService {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Create
    
    /// Creates a new user-defined category
    @discardableResult
    func create(
        name: String,
        icon: String,
        colorHex: String,
        type: TransactionType,
        parentCategory: Category? = nil
    ) throws -> Category {
        // Validate parent category type matches
        if let parent = parentCategory, parent.type != type {
            throw CategoryError.typeMismatch
        }
        
        let category = Category(
            nameKey: name, // User categories store raw name
            icon: icon,
            colorHex: colorHex,
            type: type,
            isSystemDefault: false,
            sortOrder: nextSortOrder(type: type, parentCategory: parentCategory),
            parentCategory: parentCategory
        )
        context.insert(category)
        try context.save()
        return category
    }
    
    // MARK: - Read
    
    /// Fetches all categories of a specific type
    func fetch(type: TransactionType? = nil, includeSubcategories: Bool = true) throws -> [Category] {
        var descriptor = FetchDescriptor<Category>(
            sortBy: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.nameKey)
            ]
        )
        
        if !includeSubcategories {
            descriptor.predicate = #Predicate { $0.parentCategory == nil }
        }
        
        var results = try context.fetch(descriptor)
        
        if let type {
            results = results.filter { $0.type == type }
        }
        
        return results
    }
    
    /// Fetches top-level categories only (no subcategories)
    func fetchTopLevel(type: TransactionType? = nil) throws -> [Category] {
        try fetch(type: type, includeSubcategories: false)
    }
    
    /// Fetches a category by ID
    func fetch(byId id: UUID) throws -> Category? {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    /// Fetches subcategories of a parent
    func fetchSubcategories(of parent: Category) throws -> [Category] {
        (parent.subcategories ?? []).sorted(by: categoryDisplayOrder)
    }
    
    // MARK: - Update
    
    /// Updates a category
    func update(
        _ category: Category,
        name: String? = nil,
        icon: String? = nil,
        colorHex: String? = nil
    ) throws {
        // Prevent changing type if transactions exist
        if category.hasTransactions {
            // Type change not allowed
        }
        
        if let name {
            category.nameKey = name
            // Mark as non-system if edited
            if category.isSystemDefault {
                category.isSystemDefault = false
            }
        }
        if let icon { category.icon = icon }
        if let colorHex { category.colorHex = colorHex }
        
        try context.save()
    }
    
    /// Moves a category to become a subcategory of another
    func move(_ category: Category, toParent parent: Category?) throws {
        // Validate type match
        if let parent, parent.type != category.type {
            throw CategoryError.typeMismatch
        }
        
        // Prevent circular reference
        if let parent, parent.id == category.id {
            throw CategoryError.circularReference
        }
        
        category.parentCategory = parent
        category.sortOrder = nextSortOrder(type: category.type, parentCategory: parent)
        try context.save()
    }

    /// Persists a user-defined display order for categories of the given type.
    func reorder(_ categories: [Category], type: TransactionType) throws {
        for (index, category) in categories.filter({ $0.type == type }).enumerated() {
            category.sortOrder = index
        }

        try context.save()
    }
    
    // MARK: - Delete
    
    /// Deletes a category (transactions will have category set to nil)
    func delete(_ category: Category) throws {
        context.delete(category)
        try context.save()
    }
    
    // MARK: - Errors
    
    enum CategoryError: LocalizedError {
        case typeMismatch
        case circularReference
        case hasTransactions
        
        var errorDescription: String? {
            switch self {
            case .typeMismatch:
                AppLocalization.string(
                    "category.error.typeMismatch",
                    defaultValue: "Subcategory type must match parent type"
                )
            case .circularReference:
                AppLocalization.string(
                    "category.error.circularReference",
                    defaultValue: "Cannot make a category its own parent"
                )
            case .hasTransactions:
                AppLocalization.string(
                    "category.error.hasTransactions",
                    defaultValue: "Cannot change type of category with existing transactions"
                )
            }
        }
    }

    private func nextSortOrder(type: TransactionType, parentCategory: Category?) -> Int {
        let categories = (try? fetch(type: type, includeSubcategories: true)) ?? []
        let siblingOrders = categories
            .filter { category in
                category.parentCategory?.id == parentCategory?.id
            }
            .map(\.sortOrder)
        return (siblingOrders.max() ?? -1) + 1
    }

    private func categoryDisplayOrder(_ lhs: Category, _ rhs: Category) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }
}
