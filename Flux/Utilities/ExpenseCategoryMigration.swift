import Foundation
import SwiftData

struct ExpenseCategoryDefinition {
    let key: String
    let icon: String
    let color: String
}

enum ExpenseCategoryCatalog {
    static let definitions: [ExpenseCategoryDefinition] = [
        .init(key: "category.expense.dining", icon: "fork.knife", color: "#F59E0B"),
        .init(key: "category.expense.coffee", icon: "cup.and.saucer.fill", color: "#A16207"),
        .init(key: "category.expense.groceries", icon: "cart.fill", color: "#22C55E"),
        .init(key: "category.expense.transport", icon: "tram.fill", color: "#14B8A6"),
        .init(key: "category.expense.housing", icon: "building.2.fill", color: "#3B82F6"),
        .init(key: "category.expense.utilities", icon: "bolt.fill", color: "#F59E0B"),
        .init(key: "category.expense.phone", icon: "wifi", color: "#06B6D4"),
        .init(key: "category.expense.home", icon: "sofa.fill", color: "#06B6D4"),
        .init(key: "category.expense.shopping", icon: "bag.fill", color: "#06B6D4"),
        .init(key: "category.expense.electronics", icon: "desktopcomputer", color: "#6366F1"),
        .init(key: "category.expense.personalCare", icon: "comb", color: "#F43F5E"),
        .init(key: "category.expense.sports", icon: "dumbbell.fill", color: "#14B8A6"),
        .init(key: "category.expense.medical", icon: "cross.case.fill", color: "#EC4899"),
        .init(key: "category.expense.entertainment", icon: "ticket.fill", color: "#6366F1"),
        .init(key: "category.expense.subscriptions", icon: "repeat", color: "#A855F7"),
        .init(key: "category.expense.learning", icon: "books.vertical.fill", color: "#3B82F6"),
        .init(key: "category.expense.family", icon: "person.3.fill", color: "#EF4444"),
        .init(key: "category.expense.travel", icon: "airplane", color: "#F59E0B"),
        .init(key: "category.expense.gifts", icon: "gift.fill", color: "#EF4444"),
        .init(key: "category.expense.pet", icon: "pawprint.fill", color: "#A16207"),
        .init(key: "category.expense.insurance", icon: "shield.fill", color: "#A855F7"),
        .init(key: "category.expense.tax", icon: "building.columns.fill", color: "#F59E0B"),
        .init(key: "category.expense.miscellaneous", icon: "ellipsis.circle.fill", color: "#64748B")
    ]

    static let definitionByKey = Dictionary(
        uniqueKeysWithValues: definitions.map { ($0.key, $0) }
    )
}

/// Upgrades the built-in expense catalogue without touching user-created categories.
///
/// The versioned upgrade creates newly introduced defaults once. The legacy normalizer is
/// deliberately separate and idempotent so old CloudKit or backup records can be normalized
/// later without recreating categories that the user deleted.
@MainActor
enum ExpenseCategoryMigration {
    static let versionedMigrationKey = "flux.expenseCategories.v2.done"

    /// Categories introduced by the v2 catalogue. Retained v1 defaults are deliberately absent:
    /// an upgrade must never recreate one that the user previously deleted.
    private static let v2IntroducedKeys: Set<String> = [
        "category.expense.coffee",
        "category.expense.utilities",
        "category.expense.phone",
        "category.expense.electronics",
        "category.expense.sports",
        "category.expense.family",
        "category.expense.miscellaneous"
    ]

    /// Stable v1 fingerprints used to distinguish an old Flux store from an unrelated/custom-only
    /// store. The completion decision itself is persisted in SwiftData below.
    private static let legacyStoreFingerprintKeys: Set<String> = [
        "category.expense.dining", "category.expense.groceries",
        "category.expense.transport", "category.expense.housing",
        "category.expense.home", "category.expense.shopping",
        "category.expense.personalCare", "category.expense.entertainment",
        "category.expense.subscriptions", "category.expense.travel",
        "category.expense.gifts", "category.expense.pet",
        "category.expense.insurance", "category.expense.tax",
        "category.expense.medical", "category.expense.health",
        "category.expense.education", "category.expense.upskilling",
        "category.expense.learning", "category.expense.bills",
        "category.expense.miscellaneous"
    ]

    private struct LegacyGroup {
        let targetKey: String
        let sourceKeysAndNames: Set<String>
    }

    private static let legacyGroups: [LegacyGroup] = [
        LegacyGroup(
            targetKey: "category.expense.medical",
            sourceKeysAndNames: normalizedSet([
                "category.expense.health", "Health", "健康"
            ])
        ),
        LegacyGroup(
            targetKey: "category.expense.learning",
            sourceKeysAndNames: normalizedSet([
                "category.expense.education", "category.expense.upskilling",
                "Education", "Upskilling", "教育", "学习", "學習", "进修", "進修"
            ])
        ),
        LegacyGroup(
            targetKey: "category.expense.miscellaneous",
            sourceKeysAndNames: normalizedSet([
                "category.expense.bills", "Bills", "账单", "帳單"
            ])
        )
    ]

    /// Icons previously shipped by Flux for categories whose symbols changed in v2. A symbol is
    /// modernized only when it still matches one of these values; any other value is treated as a
    /// user customization, even when the category remains a system default.
    private static let previouslyShippedIconsByTargetKey: [String: Set<String>] = [
        "category.expense.home": ["house.fill"],
        "category.expense.personalCare": ["shower.fill"],
        "category.expense.entertainment": ["tv.fill"],
        "category.expense.learning": ["book.fill", "graduationcap.fill"],
        "category.expense.miscellaneous": ["doc.text.fill"]
    ]

    /// Runs once for an existing store. Completion is stored with the SwiftData store so it is
    /// not lost when device-local preferences are cleared or the app is installed elsewhere.
    /// Existing category ordering is retained; genuinely new v2 defaults are appended.
    static func runVersionedUpgradeIfNeeded(in context: ModelContext) throws {
        guard try !hasCompletedVersionedUpgrade(in: context) else {
            try normalizeLegacySystemCategories(in: context)
            return
        }

        try normalizeLegacySystemCategories(in: context)

        var categories = try context.fetch(FetchDescriptor<Category>())
        let isLegacyStore = categories.contains {
            $0.type == .expense &&
                $0.isSystemDefault &&
                legacyStoreFingerprintKeys.contains($0.nameKey)
        }

        if isLegacyStore {
            var nextSortOrder = (categories
                .filter { $0.type == .expense }
                .map(\.sortOrder)
                .max() ?? -1) + 1

            for definition in ExpenseCategoryCatalog.definitions
                where v2IntroducedKeys.contains(definition.key) {
                if let existing = categories.first(where: {
                    $0.type == .expense && $0.isSystemDefault && $0.nameKey == definition.key
                }) {
                    modernizeShippedIconIfNeeded(on: existing, using: definition)
                    continue
                }

                let category = Category(
                    nameKey: definition.key,
                    icon: definition.icon,
                    colorHex: definition.color,
                    type: .expense,
                    isSystemDefault: true,
                    sortOrder: nextSortOrder
                )
                context.insert(category)
                categories.append(category)
                nextSortOrder += 1
            }

            // Retained v1 defaults are not recreated, but their shipped symbols can be upgraded
            // once. User-selected symbols and colors are deliberately preserved.
            for category in categories where category.type == .expense && category.isSystemDefault {
                guard let definition = ExpenseCategoryCatalog.definitionByKey[category.nameKey] else {
                    continue
                }
                modernizeShippedIconIfNeeded(on: category, using: definition)
            }
        }

        try markVersionedUpgradeCompleted(in: context)
    }

    static func markVersionedUpgradeCompleted(in context: ModelContext) throws {
        let markers = try context.fetch(FetchDescriptor<AppMigrationState>())
            .filter { $0.key == versionedMigrationKey }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        if let canonical = markers.first {
            for duplicate in markers.dropFirst() {
                context.delete(duplicate)
            }
            canonical.completedAt = markers.map(\.completedAt).min() ?? canonical.completedAt
        } else {
            context.insert(AppMigrationState(key: versionedMigrationKey))
        }
    }

    static func hasCompletedVersionedUpgrade(in context: ModelContext) throws -> Bool {
        try context.fetch(FetchDescriptor<AppMigrationState>())
            .contains { $0.key == versionedMigrationKey }
    }

    /// Normalizes only actual legacy system records. If the canonical target was deleted,
    /// an arriving legacy record is reused as the target rather than creating an unrelated
    /// default category.
    @discardableResult
    static func normalizeLegacySystemCategories(in context: ModelContext) throws -> Bool {
        var categories = try context.fetch(FetchDescriptor<Category>())

        // Renaming a single legacy object keeps all of its relationships intact. Fetching the
        // complete transaction and budget history is necessary only when identities must merge.
        let needsReferenceMerge = legacyGroups.contains { group in
            categories.filter { isCandidate($0, for: group) }.count > 1
        } || ExpenseCategoryCatalog.definitions.contains { definition in
            categories.filter { isCanonicalSystemCategory($0, key: definition.key) }.count > 1
        }

        guard needsReferenceMerge else {
            var changed = false
            for group in legacyGroups {
                guard let target = categories.first(where: { isCandidate($0, for: group) }),
                      target.nameKey != group.targetKey else {
                    continue
                }
                let oldKey = target.nameKey
                target.nameKey = group.targetKey
                changed = true
                if let definition = ExpenseCategoryCatalog.definitionByKey[group.targetKey] {
                    changed = modernizeLegacyIconIfNeeded(
                        on: target,
                        oldKey: oldKey,
                        using: definition
                    ) || changed
                }
            }
            return changed
        }

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        var changed = false
        var mergedCanonicalCategoryIDs = Set<UUID>()

        for group in legacyGroups {
            let candidates = categories.filter { isCandidate($0, for: group) }
            guard !candidates.isEmpty else { continue }

            let canonicalCandidates = candidates.filter { $0.nameKey == group.targetKey }
            let target = (canonicalCandidates.isEmpty ? candidates : canonicalCandidates)
                .sorted(by: categoryIDAscending)[0]
            if target.nameKey != group.targetKey {
                changed = true
            }
            target.nameKey = group.targetKey

            let sources = candidates.sorted(by: categoryIDAscending).filter { $0 !== target }
            if !sources.isEmpty {
                mergedCanonicalCategoryIDs.insert(target.id)
            }
            for source in sources {
                reassignReferences(
                    from: source,
                    to: target,
                    categories: categories,
                    transactions: transactions,
                    budgets: budgets
                )
                context.delete(source)
                categories.removeAll { $0 === source }
                changed = true
            }

            if let definition = ExpenseCategoryCatalog.definitionByKey[group.targetKey] {
                changed = modernizeShippedIconIfNeeded(on: target, using: definition) || changed
            }
        }

        // CloudKit may deliver duplicate canonical records even after legacy aliases have gone.
        // Merge those deterministically as well; custom categories are never candidates.
        for definition in ExpenseCategoryCatalog.definitions {
            let duplicates = categories.filter {
                $0.type == .expense &&
                    $0.isSystemDefault &&
                    $0.nameKey == definition.key
            }.sorted(by: categoryIDAscending)
            guard let target = duplicates.first else { continue }
            if duplicates.count > 1 {
                mergedCanonicalCategoryIDs.insert(target.id)
                changed = modernizeShippedIconIfNeeded(on: target, using: definition) || changed
            }

            for source in duplicates.dropFirst() {
                reassignReferences(
                    from: source,
                    to: target,
                    categories: categories,
                    transactions: transactions,
                    budgets: budgets
                )
                context.delete(source)
                categories.removeAll { $0 === source }
                changed = true
            }
        }

        changed = resolveActiveBudgetCollisions(
            budgets,
            forCategoryIDs: mergedCanonicalCategoryIDs
        ) || changed
        return changed
    }

    private static func isCandidate(_ category: Category, for group: LegacyGroup) -> Bool {
        category.type == .expense &&
            category.isSystemDefault &&
            (category.nameKey == group.targetKey ||
                group.sourceKeysAndNames.contains(normalized(category.nameKey)))
    }

    private static func isCanonicalSystemCategory(_ category: Category, key: String) -> Bool {
        category.type == .expense && category.isSystemDefault && category.nameKey == key
    }

    @discardableResult
    private static func modernizeShippedIconIfNeeded(
        on category: Category,
        using definition: ExpenseCategoryDefinition
    ) -> Bool {
        guard previouslyShippedIconsByTargetKey[definition.key]?.contains(category.icon) == true,
              category.icon != definition.icon else {
            return false
        }
        category.icon = definition.icon
        return true
    }

    @discardableResult
    private static func modernizeLegacyIconIfNeeded(
        on category: Category,
        oldKey: String,
        using definition: ExpenseCategoryDefinition
    ) -> Bool {
        guard oldKey != definition.key else { return false }
        return modernizeShippedIconIfNeeded(on: category, using: definition)
    }

    private static func reassignReferences(
        from source: Category,
        to target: Category,
        categories: [Category],
        transactions: [Transaction],
        budgets: [Budget]
    ) {
        for transaction in transactions where transaction.category === source {
            transaction.category = target
        }
        for budget in budgets where budget.category === source {
            budget.category = target
        }
        for category in categories where category.parentCategory === source {
            category.parentCategory = category === target ? source.parentCategory : target
        }

        if target.parentCategory == nil,
           let sourceParent = source.parentCategory,
           sourceParent !== target {
            target.parentCategory = sourceParent
        }
    }

    /// Merging category identities can put multiple active budgets in the same category/period.
    /// Keep every row, but retain only the lexicographically smallest UUID as active.
    private static func resolveActiveBudgetCollisions(
        _ budgets: [Budget],
        forCategoryIDs categoryIDs: Set<UUID>
    ) -> Bool {
        var changed = false
        let activeBudgets = budgets.filter {
            $0.isActive &&
                $0.category.map { categoryIDs.contains($0.id) } == true
        }
        let grouped = Dictionary(grouping: activeBudgets) { budget in
            "\(budget.category!.id.uuidString)|\(budget.period.rawValue)"
        }

        for group in grouped.values where group.count > 1 {
            let ordered = group.sorted { $0.id.uuidString < $1.id.uuidString }
            for duplicate in ordered.dropFirst() {
                duplicate.isActive = false
                changed = true
            }
        }
        return changed
    }

    private static func categoryIDAscending(_ lhs: Category, _ rhs: Category) -> Bool {
        lhs.id.uuidString < rhs.id.uuidString
    }

    private static func normalizedSet(_ values: [String]) -> Set<String> {
        Set(values.map(normalized))
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
