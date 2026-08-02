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
        .init(key: "category.expense.phone", icon: "phone.fill", color: "#3B82F6"),
        .init(key: "category.expense.home", icon: "sofa.fill", color: "#14B8A6"),
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
        .init(key: "category.expense.insurance", icon: "shield.fill", color: "#64748B"),
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
    static let appearanceMigrationKey = "flux.expenseCategories.v3Appearance.done"
    private static let appearanceCategoryMarkerPrefix =
        "flux.expenseCategories.v3Appearance.category."

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
            targetKey: "category.expense.personalCare",
            sourceKeysAndNames: normalizedSet([
                "Personal Care", "個人護理", "个人护理",
                "Beauty & Personal Care", "美容護理", "美容护理"
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

    /// Icons previously shipped by Flux for categories whose symbols later changed. A symbol is
    /// modernized only when it still matches one of these values; any other value is treated as a
    /// user customization, even when the category remains a system default.
    private static let previouslyShippedIconsByTargetKey: [String: Set<String>] = [
        "category.expense.home": ["house.fill"],
        "category.expense.personalCare": ["shower.fill"],
        "category.expense.phone": ["wifi"],
        "category.expense.entertainment": ["tv.fill"],
        "category.expense.learning": ["book.fill", "graduationcap.fill"],
        "category.expense.miscellaneous": ["doc.text.fill"]
    ]

    /// Previous Flux defaults for categories whose palette assignment changed. Matching an old
    /// default is the only safe signal available in the current model that the user did not pick
    /// a custom color. Values outside these sets are therefore always preserved.
    private static let previouslyShippedColorsByTargetKey: [String: Set<String>] = [
        "category.expense.phone": ["#06B6D4"],
        "category.expense.home": ["#06B6D4"],
        "category.expense.entertainment": ["#6366F1"],
        "category.expense.subscriptions": ["#A855F7"],
        "category.expense.learning": ["#14B8A6"],
        "category.expense.family": ["#EF4444"],
        "category.expense.insurance": ["#A855F7"]
    ]

    /// Runs once for an existing store. Completion is stored with the SwiftData store so it is
    /// not lost when device-local preferences are cleared or the app is installed elsewhere.
    /// Existing category ordering is retained; genuinely new v2 defaults are appended.
    static func runVersionedUpgradeIfNeeded(in context: ModelContext) throws {
        try normalizeLegacySystemCategories(in: context)

        if try !hasCompletedVersionedUpgrade(in: context) {
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
                    if categories.contains(where: {
                        $0.type == .expense && $0.isSystemDefault && $0.nameKey == definition.key
                    }) {
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
            }

            try markMigrationCompleted(versionedMigrationKey, in: context)
        }

        try runAppearanceUpgradeIfNeeded(in: context)
    }

    /// Marks a freshly seeded/reset store as current without running upgrade logic over records
    /// that were created with the latest definitions.
    static func markVersionedUpgradeCompleted(in context: ModelContext) throws {
        let categories = try context.fetch(FetchDescriptor<Category>())
        var markerKeys = try reconcileAppearanceMarkers(in: context).keys
        try markMigrationCompleted(versionedMigrationKey, in: context)
        for category in categories where isCurrentCanonicalSystemCategory(category) {
            markAppearanceCompleted(
                for: category,
                markerKeys: &markerKeys,
                in: context
            )
        }
        try markMigrationCompleted(appearanceMigrationKey, in: context)
    }

    private static func markMigrationCompleted(
        _ key: String,
        in context: ModelContext
    ) throws {
        let markers = try context.fetch(FetchDescriptor<AppMigrationState>())
            .filter { $0.key == key }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        if let canonical = markers.first {
            for duplicate in markers.dropFirst() {
                context.delete(duplicate)
            }
            canonical.completedAt = markers.map(\.completedAt).min() ?? canonical.completedAt
        } else {
            context.insert(AppMigrationState(key: key))
        }
    }

    static func hasCompletedVersionedUpgrade(in context: ModelContext) throws -> Bool {
        try context.fetch(FetchDescriptor<AppMigrationState>())
            .contains { $0.key == versionedMigrationKey }
    }

    static func hasCompletedAppearanceUpgrade(in context: ModelContext) throws -> Bool {
        try context.fetch(FetchDescriptor<AppMigrationState>())
            .contains { $0.key == appearanceMigrationKey }
    }

    static func hasCompletedAppearanceUpgrade(
        for category: Category,
        in context: ModelContext
    ) throws -> Bool {
        let key = appearanceMarkerKey(for: category.id)
        return try context.fetch(FetchDescriptor<AppMigrationState>())
            .contains { $0.key == key }
    }

    /// Removes all appearance-completion rows for one category identity. Category deletion and
    /// identity merging call this in the same save transaction as the category mutation so stale
    /// CloudKit-backed markers cannot accumulate or affect a later record that reuses the UUID.
    static func removeAppearanceMarkers(
        for categoryID: UUID,
        in context: ModelContext
    ) throws {
        let key = appearanceMarkerKey(for: categoryID)
        for marker in try context.fetch(FetchDescriptor<AppMigrationState>()) where marker.key == key {
            context.delete(marker)
        }
    }

    /// Invalidates per-category appearance history before a destructive catalogue replacement.
    /// Store-wide v2/v3 markers are intentionally retained as durable migration history.
    static func removeAllAppearanceCategoryMarkers(in context: ModelContext) throws {
        for marker in try context.fetch(FetchDescriptor<AppMigrationState>())
            where marker.key.hasPrefix(appearanceCategoryMarkerPrefix) {
            context.delete(marker)
        }
    }

    private static func runAppearanceUpgradeIfNeeded(in context: ModelContext) throws {
        let categories = try context.fetch(FetchDescriptor<Category>())
        _ = try modernizeUnmarkedCanonicalAppearances(categories, in: context)

        // Retain the store-wide version marker for migration history and compatibility. Per-record
        // markers are authoritative because CloudKit and backup imports can deliver a new category
        // identity after this store-wide marker already exists.
        try markMigrationCompleted(appearanceMigrationKey, in: context)
    }

    /// Normalizes only actual legacy system records. If the canonical target was deleted,
    /// an arriving legacy record is reused as the target rather than creating an unrelated
    /// default category.
    @discardableResult
    static func normalizeLegacySystemCategories(in context: ModelContext) throws -> Bool {
        var categories = try context.fetch(FetchDescriptor<Category>())
        let reconciledMarkers = try reconcileAppearanceMarkers(in: context)
        var appearanceMarkerKeys = reconciledMarkers.keys
        let markerLifecycleChanged = reconciledMarkers.changed

        // Renaming a single legacy object keeps all of its relationships intact. Fetching the
        // complete transaction and budget history is necessary only when identities must merge.
        let needsReferenceMerge = legacyGroups.contains { group in
            categories.filter { isCandidate($0, for: group) }.count > 1
        } || ExpenseCategoryCatalog.definitions.contains { definition in
            categories.filter { isCanonicalSystemCategory($0, key: definition.key) }.count > 1
        }

        guard needsReferenceMerge else {
            var changed = markerLifecycleChanged
            for group in legacyGroups {
                guard let target = categories.first(where: { isCandidate($0, for: group) }),
                      target.nameKey != group.targetKey else {
                    continue
                }
                target.nameKey = group.targetKey
                changed = true
            }

            changed = modernizeUnmarkedCanonicalAppearances(
                categories,
                markerKeys: &appearanceMarkerKeys,
                in: context
            ) || changed
            return changed
        }

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        var changed = markerLifecycleChanged
        var mergedCanonicalCategoryIDs = Set<UUID>()

        for group in legacyGroups {
            let candidates = categories.filter { isCandidate($0, for: group) }
            guard !candidates.isEmpty else { continue }

            let target = preferredMergeTarget(
                from: candidates,
                canonicalKey: group.targetKey,
                appearanceMarkerKeys: appearanceMarkerKeys
            )
            let targetWasLegacyAlias = target.nameKey != group.targetKey
            if target.nameKey != group.targetKey {
                changed = true
            }
            target.nameKey = group.targetKey
            let targetAppearanceWasCompleted = appearanceMarkerKeys.contains(
                appearanceMarkerKey(for: target.id)
            )

            let sources = candidates.sorted(by: categoryIDAscending).filter { $0 !== target }
            if !sources.isEmpty {
                mergedCanonicalCategoryIDs.insert(target.id)
            }
            for source in sources {
                if !targetAppearanceWasCompleted,
                   let definition = ExpenseCategoryCatalog.definitionByKey[group.targetKey] {
                    mergeCustomizedAppearance(from: source, to: target, using: definition)
                }
                reassignReferences(
                    from: source,
                    to: target,
                    categories: categories,
                    transactions: transactions,
                    budgets: budgets
                )
                context.delete(source)
                changed = try removeAppearanceMarkers(
                    for: source.id,
                    markerKeys: &appearanceMarkerKeys,
                    in: context
                ) || changed
                categories.removeAll { $0 === source }
                changed = true
            }

            if !targetAppearanceWasCompleted,
               (targetWasLegacyAlias || !sources.isEmpty),
               let definition = ExpenseCategoryCatalog.definitionByKey[group.targetKey] {
                changed = modernizeShippedAppearanceIfNeeded(on: target, using: definition) || changed
                markAppearanceCompleted(
                    for: target,
                    markerKeys: &appearanceMarkerKeys,
                    in: context
                )
                changed = true
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
            guard !duplicates.isEmpty else { continue }
            let target = preferredMergeTarget(
                from: duplicates,
                canonicalKey: definition.key,
                appearanceMarkerKeys: appearanceMarkerKeys
            )
            let targetAppearanceWasCompleted = appearanceMarkerKeys.contains(
                appearanceMarkerKey(for: target.id)
            )
            if duplicates.count > 1 {
                mergedCanonicalCategoryIDs.insert(target.id)
            }

            for source in duplicates where source !== target {
                if !targetAppearanceWasCompleted {
                    mergeCustomizedAppearance(from: source, to: target, using: definition)
                }
                reassignReferences(
                    from: source,
                    to: target,
                    categories: categories,
                    transactions: transactions,
                    budgets: budgets
                )
                context.delete(source)
                changed = try removeAppearanceMarkers(
                    for: source.id,
                    markerKeys: &appearanceMarkerKeys,
                    in: context
                ) || changed
                categories.removeAll { $0 === source }
                changed = true
            }
            if duplicates.count > 1 && !targetAppearanceWasCompleted {
                changed = modernizeShippedAppearanceIfNeeded(on: target, using: definition) || changed
                markAppearanceCompleted(
                    for: target,
                    markerKeys: &appearanceMarkerKeys,
                    in: context
                )
                changed = true
            }
        }

        changed = resolveActiveBudgetCollisions(
            budgets,
            forCategoryIDs: mergedCanonicalCategoryIDs
        ) || changed
        changed = modernizeUnmarkedCanonicalAppearances(
            categories,
            markerKeys: &appearanceMarkerKeys,
            in: context
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
    private static func modernizeShippedAppearanceIfNeeded(
        on category: Category,
        using definition: ExpenseCategoryDefinition
    ) -> Bool {
        var changed = false
        if previouslyShippedIconsByTargetKey[definition.key]?.contains(category.icon) == true,
           category.icon != definition.icon {
            category.icon = definition.icon
            changed = true
        }

        if previouslyShippedColorsByTargetKey[definition.key]?.contains(
            normalizedHex(category.colorHex)
        ) == true,
           category.colorHex != definition.color {
            category.colorHex = definition.color
            changed = true
        }
        return changed
    }

    private static func modernizeUnmarkedCanonicalAppearances(
        _ categories: [Category],
        in context: ModelContext
    ) throws -> Bool {
        var markerKeys = try migrationMarkerKeys(in: context)
        return modernizeUnmarkedCanonicalAppearances(
            categories,
            markerKeys: &markerKeys,
            in: context
        )
    }

    private static func modernizeUnmarkedCanonicalAppearances(
        _ categories: [Category],
        markerKeys: inout Set<String>,
        in context: ModelContext
    ) -> Bool {
        var changed = false
        for category in categories where isCurrentCanonicalSystemCategory(category) {
            let markerKey = appearanceMarkerKey(for: category.id)
            guard !markerKeys.contains(markerKey),
                  let definition = ExpenseCategoryCatalog.definitionByKey[category.nameKey] else {
                continue
            }

            changed = modernizeShippedAppearanceIfNeeded(on: category, using: definition) || changed
            markAppearanceCompleted(for: category, markerKeys: &markerKeys, in: context)
            changed = true
        }
        return changed
    }

    private static func preferredMergeTarget(
        from candidates: [Category],
        canonicalKey: String,
        appearanceMarkerKeys: Set<String>
    ) -> Category {
        candidates.sorted { lhs, rhs in
            let lhsCompleted = appearanceMarkerKeys.contains(appearanceMarkerKey(for: lhs.id))
            let rhsCompleted = appearanceMarkerKeys.contains(appearanceMarkerKey(for: rhs.id))
            if lhsCompleted != rhsCompleted {
                return lhsCompleted
            }
            let lhsCanonical = lhs.nameKey == canonicalKey
            let rhsCanonical = rhs.nameKey == canonicalKey
            if lhsCanonical != rhsCanonical {
                return lhsCanonical
            }
            return categoryIDAscending(lhs, rhs)
        }[0]
    }

    private static func isCurrentCanonicalSystemCategory(_ category: Category) -> Bool {
        category.type == .expense &&
            category.isSystemDefault &&
            ExpenseCategoryCatalog.definitionByKey[category.nameKey] != nil
    }

    private static func migrationMarkerKeys(in context: ModelContext) throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<AppMigrationState>()).map(\.key))
    }

    /// Deduplicates marker rows deterministically and prunes only malformed category keys. A
    /// valid marker can arrive from CloudKit before its category, so temporary absence from a
    /// local fetch is not evidence that the marker is stale. Known category deletion, identity
    /// merge, reset, and replace lifecycles remove their exact markers explicitly.
    /// The oldest completion timestamp wins, with UUID as a stable tie-breaker.
    private static func reconcileAppearanceMarkers(
        in context: ModelContext
    ) throws -> (keys: Set<String>, changed: Bool) {
        let markers = try context.fetch(FetchDescriptor<AppMigrationState>())
            .filter { $0.key.hasPrefix(appearanceCategoryMarkerPrefix) }
            .sorted {
                if $0.key != $1.key { return $0.key < $1.key }
                if $0.completedAt != $1.completedAt { return $0.completedAt < $1.completedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        var retainedKeys = Set<String>()
        var changed = false

        for marker in markers {
            let idText = String(marker.key.dropFirst(appearanceCategoryMarkerPrefix.count))
            guard UUID(uuidString: idText) != nil,
                  retainedKeys.insert(marker.key).inserted else {
                context.delete(marker)
                changed = true
                continue
            }
        }
        return (retainedKeys, changed)
    }

    private static func appearanceMarkerKey(for categoryID: UUID) -> String {
        appearanceCategoryMarkerPrefix + categoryID.uuidString.lowercased()
    }

    private static func markAppearanceCompleted(
        for category: Category,
        markerKeys: inout Set<String>,
        in context: ModelContext
    ) {
        let key = appearanceMarkerKey(for: category.id)
        guard markerKeys.insert(key).inserted else { return }
        context.insert(AppMigrationState(key: key))
    }

    @discardableResult
    private static func removeAppearanceMarkers(
        for categoryID: UUID,
        markerKeys: inout Set<String>,
        in context: ModelContext
    ) throws -> Bool {
        let key = appearanceMarkerKey(for: categoryID)
        markerKeys.remove(key)
        var changed = false
        for marker in try context.fetch(FetchDescriptor<AppMigrationState>()) where marker.key == key {
            context.delete(marker)
            changed = true
        }
        return changed
    }

    /// CloudKit can leave both an old alias and a canonical category in the store. When those
    /// identities merge, carry a customized appearance forward only while the chosen target is
    /// still using a known Flux default. Conflicting customizations resolve deterministically in
    /// favor of the target (or the first source by UUID once the target adopts it).
    private static func mergeCustomizedAppearance(
        from source: Category,
        to target: Category,
        using definition: ExpenseCategoryDefinition
    ) {
        if isKnownShippedIcon(target.icon, for: definition),
           !isKnownShippedIcon(source.icon, for: definition) {
            target.icon = source.icon
        }
        if isKnownShippedColor(target.colorHex, for: definition),
           !isKnownShippedColor(source.colorHex, for: definition) {
            target.colorHex = source.colorHex
        }
    }

    private static func isKnownShippedIcon(
        _ icon: String,
        for definition: ExpenseCategoryDefinition
    ) -> Bool {
        icon == definition.icon ||
            previouslyShippedIconsByTargetKey[definition.key]?.contains(icon) == true
    }

    private static func isKnownShippedColor(
        _ colorHex: String,
        for definition: ExpenseCategoryDefinition
    ) -> Bool {
        let normalizedColor = normalizedHex(colorHex)
        return normalizedColor == normalizedHex(definition.color) ||
            previouslyShippedColorsByTargetKey[definition.key]?.contains(normalizedColor) == true
    }

    private static func normalizedHex(_ colorHex: String) -> String {
        colorHex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
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
