import XCTest
import SwiftData
@testable import Flux

final class ExpenseCategoryMigrationTests: XCTestCase {
    @MainActor
    func testVersionedMigrationReassignsEveryCategoryReferenceAndPreservesUserCategories() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let defaults = makeDefaults()
        defer { clear(defaults) }

        // A currency makes this an existing store rather than a fresh installation.
        context.insert(Currency(code: "HKD", exchangeRateToBase: 1, isBaseCurrency: true))

        let learning = systemCategory("category.expense.learning", sortOrder: 8)
        let education = systemCategory("category.expense.education", sortOrder: 9)
        let upskilling = systemCategory("進修", sortOrder: 10)
        let bills = systemCategory("category.expense.bills", sortOrder: 11)
        let child = Category(
            nameKey: "Course materials",
            icon: "book",
            colorHex: "#111111",
            type: .expense,
            sortOrder: 0,
            parentCategory: education
        )
        let userBills = Category(
            nameKey: "帳單",
            icon: "star",
            colorHex: "#222222",
            type: .expense,
            isSystemDefault: false,
            sortOrder: 12
        )

        for category in [learning, education, upskilling, bills, child, userBills] {
            context.insert(category)
        }

        let ordinary = transaction(category: education)
        let recurringTemplate = Transaction(
            amount: 200,
            currencyCode: "HKD",
            type: .expense,
            isRecurringTemplate: true,
            recurrenceRule: .monthly,
            category: upskilling
        )
        let generated = Transaction(
            amount: 300,
            currencyCode: "HKD",
            type: .expense,
            recurringTemplateId: recurringTemplate.id,
            generatedDate: .now,
            category: bills
        )
        context.insert(ordinary)
        context.insert(recurringTemplate)
        context.insert(generated)

        let learningBudget = Budget(limitAmount: 100, currencyCode: "HKD", category: education)
        let upskillingBudget = Budget(limitAmount: 200, currencyCode: "HKD", category: upskilling)
        let billsBudget = Budget(limitAmount: 300, currencyCode: "HKD", category: bills)
        context.insert(learningBudget)
        context.insert(upskillingBudget)
        context.insert(billsBudget)
        try context.save()

        let seeder = DefaultDataSeeder(context: context, defaults: defaults)
        try await seeder.seedIfNeeded()

        let categories = try context.fetch(FetchDescriptor<Flux.Category>())
        let migratedLearning = try XCTUnwrap(categories.first {
            $0.isSystemDefault && $0.nameKey == "category.expense.learning"
        })
        let miscellaneous = try XCTUnwrap(categories.first {
            $0.isSystemDefault && $0.nameKey == "category.expense.miscellaneous"
        })

        XCTAssertFalse(categories.contains { $0.isSystemDefault && [
            "category.expense.education", "category.expense.upskilling", "進修",
            "category.expense.bills"
        ].contains($0.nameKey) })
        XCTAssertTrue(ordinary.category === migratedLearning)
        XCTAssertTrue(recurringTemplate.category === migratedLearning)
        XCTAssertTrue(generated.category === miscellaneous)
        XCTAssertTrue(learningBudget.category === migratedLearning)
        XCTAssertTrue(upskillingBudget.category === migratedLearning)
        XCTAssertTrue(billsBudget.category === miscellaneous)
        XCTAssertTrue(child.parentCategory === migratedLearning)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Budget>()), 3)
        XCTAssertEqual(userBills.nameKey, "帳單")
        XCTAssertFalse(userBills.isSystemDefault)
        XCTAssertTrue(try ExpenseCategoryMigration.hasCompletedVersionedUpgrade(in: context))

        let firstSystemIDs = Set(categories.filter(\.isSystemDefault).map(\.id))
        try await seeder.seedIfNeeded()
        let secondCategories = try context.fetch(FetchDescriptor<Flux.Category>())
        XCTAssertEqual(firstSystemIDs, Set(secondCategories.filter(\.isSystemDefault).map(\.id)))
    }

    @MainActor
    func testCompletedMigrationDoesNotRecreateADeletedDefaultCategory() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let defaults = makeDefaults()
        defer { clear(defaults) }

        let seeder = DefaultDataSeeder(context: context, defaults: defaults)
        try await seeder.seedIfNeeded()

        let categories = try context.fetch(FetchDescriptor<Flux.Category>())
        let phone = try XCTUnwrap(categories.first {
            $0.nameKey == "category.expense.phone" && $0.isSystemDefault
        })
        context.delete(phone)
        try context.save()

        try await seeder.seedIfNeeded()
        let afterRelaunch = try context.fetch(FetchDescriptor<Flux.Category>())
        XCTAssertFalse(afterRelaunch.contains {
            $0.nameKey == "category.expense.phone" && $0.isSystemDefault
        })
    }

    @MainActor
    func testExistingStoreUpgradeCreatesOnlyNewV2Categories() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let legacyDining = systemCategory("category.expense.dining", sortOrder: 0)
        context.insert(legacyDining)
        context.insert(Currency(code: "HKD", exchangeRateToBase: 1, isBaseCurrency: true))
        try context.save()

        try await DefaultDataSeeder(context: context).seedIfNeeded()

        let systemKeys = Set(try context.fetch(FetchDescriptor<Flux.Category>())
            .filter(\.isSystemDefault)
            .map(\.nameKey))
        let newV2Keys: Set<String> = [
            "category.expense.coffee", "category.expense.utilities",
            "category.expense.phone", "category.expense.electronics",
            "category.expense.sports", "category.expense.family",
            "category.expense.miscellaneous"
        ]
        XCTAssertTrue(newV2Keys.isSubset(of: systemKeys))
        XCTAssertTrue(systemKeys.contains("category.expense.dining"))
        XCTAssertFalse(systemKeys.contains("category.expense.shopping"))
        XCTAssertEqual(systemKeys.count, 8)
    }

    @MainActor
    func testRepeatedNormalizationPreservesCustomizedSystemCategoryAppearance() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        try await DefaultDataSeeder(context: context).seedIfNeeded()

        let personalCare = try XCTUnwrap(
            context.fetch(FetchDescriptor<Flux.Category>()).first {
                $0.isSystemDefault && $0.nameKey == "category.expense.personalCare"
            }
        )
        personalCare.icon = "heart.fill"
        personalCare.colorHex = "#123456"
        try context.save()

        XCTAssertFalse(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        XCTAssertFalse(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        XCTAssertEqual(personalCare.icon, "heart.fill")
        XCTAssertEqual(personalCare.colorHex, "#123456")
    }

    @MainActor
    func testOneTimeUpgradeModernizesOnlyPreviouslyShippedIcons() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        context.insert(Currency(code: "HKD", exchangeRateToBase: 1, isBaseCurrency: true))
        let personalCare = Category(
            nameKey: "category.expense.personalCare",
            icon: "shower.fill",
            colorHex: "#F43F5E",
            type: .expense,
            isSystemDefault: true
        )
        let entertainment = Category(
            nameKey: "category.expense.entertainment",
            icon: "gamecontroller.fill",
            colorHex: "#112233",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(personalCare)
        context.insert(entertainment)
        try context.save()

        try await DefaultDataSeeder(context: context).seedIfNeeded()

        XCTAssertEqual(personalCare.icon, "comb")
        XCTAssertEqual(personalCare.colorHex, "#F43F5E")
        XCTAssertEqual(entertainment.icon, "gamecontroller.fill")
        XCTAssertEqual(entertainment.colorHex, "#112233")
    }

    @MainActor
    func testExplicitResetSeedsBothCategoryTypesWhenAccountTypesRemain() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        context.insert(AccountTypeDefinition(
            name: "Cash",
            icon: "banknote",
            colorHex: "#22C55E",
            isSystemDefault: true,
            legacyType: .cash
        ))

        try DefaultDataSeeder(context: context).seedCategoriesForExplicitReset()
        try context.save()

        let categories = try context.fetch(FetchDescriptor<Flux.Category>())
        XCTAssertEqual(categories.filter { $0.type == .expense }.count, 23)
        XCTAssertEqual(categories.filter { $0.type == .income }.count, 9)
        XCTAssertTrue(try ExpenseCategoryMigration.hasCompletedVersionedUpgrade(in: context))
    }

    @MainActor
    func testExplicitResetRebuildsCompleteBaselineInSingleSeedingOperation() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let seeder = DefaultDataSeeder(context: context)

        try seeder.seedDataForExplicitReset()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Currency>()), SupportedCurrency.allCases.count)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Flux.Category>()).filter { $0.type == .expense }.count, 23)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Flux.Category>()).filter { $0.type == .income }.count, 9)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Account>()), 1)
        XCTAssertFalse(try context.fetch(FetchDescriptor<Account>()).contains { $0.typeDefinition == nil })
        XCTAssertTrue(try ExpenseCategoryMigration.hasCompletedVersionedUpgrade(in: context))
    }

    @MainActor
    func testNormalizerScopesBudgetCollisionCleanupToMergedCategories() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let canonicalWinner = systemCategory(
            "category.expense.learning",
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000000")!,
            sortOrder: 1
        )
        let canonicalDuplicate = systemCategory(
            "category.expense.learning",
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000000")!,
            sortOrder: 2
        )
        let legacyAlias = systemCategory(
            "category.expense.education",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            sortOrder: 3
        )
        let customSameName = Category(
            id: UUID(uuidString: "05000000-0000-0000-0000-000000000000")!,
            nameKey: "category.expense.learning",
            icon: "star",
            colorHex: "#111111",
            type: .expense,
            isSystemDefault: false
        )
        let unrelatedCategory = systemCategory(
            "category.expense.dining",
            id: UUID(uuidString: "60000000-0000-0000-0000-000000000000")!,
            sortOrder: 4
        )
        [
            canonicalWinner, canonicalDuplicate, legacyAlias, customSameName,
            unrelatedCategory
        ].forEach(context.insert)

        let keepActive = Budget(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000000")!,
            limitAmount: 100,
            currencyCode: "HKD",
            category: canonicalDuplicate
        )
        let deactivate = Budget(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000000")!,
            limitAmount: 200,
            currencyCode: "HKD",
            category: legacyAlias
        )
        let preservedInactive = Budget(
            id: UUID(uuidString: "50000000-0000-0000-0000-000000000000")!,
            limitAmount: 300,
            currencyCode: "HKD",
            isActive: false,
            category: canonicalWinner
        )
        let unrelatedFirst = Budget(
            id: UUID(uuidString: "60000000-0000-0000-0000-000000000000")!,
            limitAmount: 400,
            currencyCode: "HKD",
            category: unrelatedCategory
        )
        let unrelatedSecond = Budget(
            id: UUID(uuidString: "70000000-0000-0000-0000-000000000000")!,
            limitAmount: 500,
            currencyCode: "HKD",
            category: unrelatedCategory
        )
        [
            keepActive, deactivate, preservedInactive, unrelatedFirst, unrelatedSecond
        ].forEach(context.insert)
        try context.save()

        try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context)
        try context.save()

        let categories = try context.fetch(FetchDescriptor<Flux.Category>())
        let systemLearning = categories.filter {
            $0.isSystemDefault && $0.nameKey == "category.expense.learning"
        }
        XCTAssertEqual(systemLearning.map(\.id), [canonicalWinner.id])
        XCTAssertTrue(categories.contains { $0 === customSameName })
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Budget>()), 5)
        XCTAssertTrue(keepActive.isActive)
        XCTAssertFalse(deactivate.isActive)
        XCTAssertFalse(preservedInactive.isActive)
        XCTAssertTrue(unrelatedFirst.isActive)
        XCTAssertTrue(unrelatedSecond.isActive)
        XCTAssertTrue([keepActive, deactivate, preservedInactive].allSatisfy {
            $0.category === canonicalWinner
        })
    }

    @MainActor
    func testLegacyNormalizerReusesLateLegacyRecordWithoutReseedingMissingDefaults() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let bills = systemCategory("帳單", sortOrder: 3)
        let transaction = transaction(category: bills)
        context.insert(bills)
        context.insert(transaction)
        try context.save()

        try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context)
        try context.save()

        let categories = try context.fetch(FetchDescriptor<Flux.Category>())
        XCTAssertEqual(categories.count, 1)
        XCTAssertTrue(categories[0] === bills)
        XCTAssertEqual(bills.nameKey, "category.expense.miscellaneous")
        XCTAssertEqual(bills.icon, "tag")
        XCTAssertTrue(transaction.category === bills)
        XCTAssertFalse(categories.contains { $0.nameKey == "category.expense.phone" })
    }

    @MainActor
    private func systemCategory(
        _ nameKey: String,
        id: UUID = UUID(),
        sortOrder: Int
    ) -> Category {
        Category(
            id: id,
            nameKey: nameKey,
            icon: "tag",
            colorHex: "#64748B",
            type: .expense,
            isSystemDefault: true,
            sortOrder: sortOrder
        )
    }

    @MainActor
    private func transaction(category: Category) -> Transaction {
        Transaction(
            amount: 100,
            currencyCode: "HKD",
            type: .expense,
            category: category
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ExpenseCategoryMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func clear(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: ExpenseCategoryMigration.versionedMigrationKey)
    }
}
