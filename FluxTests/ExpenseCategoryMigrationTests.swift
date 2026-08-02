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
    func testLateCanonicalCategoryModernizesAfterStoreAppearanceMarker() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        context.insert(AppMigrationState(key: ExpenseCategoryMigration.versionedMigrationKey))
        context.insert(AppMigrationState(key: ExpenseCategoryMigration.appearanceMigrationKey))
        let phone = Category(
            nameKey: "category.expense.phone",
            icon: "wifi",
            colorHex: "#06B6D4",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(phone)
        try context.save()

        XCTAssertTrue(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        try context.save()

        XCTAssertEqual(phone.icon, "phone.fill")
        XCTAssertEqual(phone.colorHex, "#3B82F6")
        XCTAssertTrue(try ExpenseCategoryMigration.hasCompletedAppearanceUpgrade(
            for: phone,
            in: context
        ))
    }

    @MainActor
    func testPerCategoryMarkerPreservesLaterUserChoiceMatchingPriorDefaults() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let phone = Category(
            nameKey: "category.expense.phone",
            icon: "wifi",
            colorHex: "#06B6D4",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(phone)
        try context.save()

        XCTAssertTrue(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        try context.save()
        XCTAssertEqual(phone.icon, "phone.fill")
        XCTAssertEqual(phone.colorHex, "#3B82F6")

        phone.icon = "wifi"
        phone.colorHex = "#06B6D4"
        try context.save()

        XCTAssertFalse(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        XCTAssertEqual(phone.icon, "wifi")
        XCTAssertEqual(phone.colorHex, "#06B6D4")
    }

    @MainActor
    func testMarkedCanonicalTargetPreservesAppearanceWhenDuplicateArrives() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let canonical = Category(
            id: UUID(uuidString: "F0000000-0000-0000-0000-000000000000")!,
            nameKey: "category.expense.phone",
            icon: "wifi",
            colorHex: "#06B6D4",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(canonical)
        try context.save()
        XCTAssertTrue(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        try context.save()

        canonical.icon = "wifi"
        canonical.colorHex = "#06B6D4"
        let lateDuplicate = Category(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000000")!,
            nameKey: "category.expense.phone",
            icon: "star.fill",
            colorHex: "#123456",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(lateDuplicate)
        try context.save()

        XCTAssertTrue(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        try context.save()

        let phones = try context.fetch(FetchDescriptor<Flux.Category>()).filter {
            $0.isSystemDefault && $0.nameKey == "category.expense.phone"
        }
        XCTAssertEqual(phones.count, 1)
        XCTAssertTrue(phones[0] === canonical)
        XCTAssertEqual(canonical.icon, "wifi")
        XCTAssertEqual(canonical.colorHex, "#06B6D4")
    }

    @MainActor
    func testMarkedLegacyAliasWinsOverUnmarkedCanonicalAndKeepsPostMigrationAppearance() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let markedAlias = Category(
            id: UUID(uuidString: "F0000000-0000-0000-0000-000000000000")!,
            nameKey: "category.expense.education",
            icon: "graduationcap.fill",
            colorHex: "#3B82F6",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(markedAlias)
        try context.save()

        XCTAssertTrue(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        try context.save()
        XCTAssertTrue(try ExpenseCategoryMigration.hasCompletedAppearanceUpgrade(
            for: markedAlias,
            in: context
        ))

        // These deliberately look like historical defaults, but are a post-migration user choice.
        markedAlias.nameKey = "category.expense.education"
        markedAlias.icon = "book.fill"
        markedAlias.colorHex = "#14B8A6"
        let unmarkedCanonical = Category(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000000")!,
            nameKey: "category.expense.learning",
            icon: "star.fill",
            colorHex: "#123456",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(unmarkedCanonical)
        try context.save()

        XCTAssertTrue(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        try context.save()

        let learning = try XCTUnwrap(context.fetch(FetchDescriptor<Flux.Category>()).first {
            $0.isSystemDefault && $0.nameKey == "category.expense.learning"
        })
        XCTAssertEqual(learning.id, markedAlias.id)
        XCTAssertEqual(learning.icon, "book.fill")
        XCTAssertEqual(learning.colorHex, "#14B8A6")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Flux.Category>()), 1)
        XCTAssertTrue(try ExpenseCategoryMigration.hasCompletedAppearanceUpgrade(
            for: learning,
            in: context
        ))
        XCTAssertFalse(try ExpenseCategoryMigration.hasCompletedAppearanceUpgrade(
            for: unmarkedCanonical,
            in: context
        ))
    }

    @MainActor
    func testAppearanceMarkerReconciliationDeduplicatesAndPrunesMalformedKeys() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let phone = Category(
            nameKey: "category.expense.phone",
            icon: "phone.fill",
            colorHex: "#3B82F6",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(phone)
        try ExpenseCategoryMigration.markVersionedUpgradeCompleted(in: context)
        try context.save()

        let original = try XCTUnwrap(appearanceMarkers(in: context).first)
        let olderDuplicate = AppMigrationState(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000000")!,
            key: original.key,
            completedAt: Date(timeIntervalSince1970: 1)
        )
        let prefix = String(original.key.dropLast(phone.id.uuidString.count))
        let malformed = AppMigrationState(
            key: prefix + "not-a-uuid"
        )
        context.insert(olderDuplicate)
        context.insert(malformed)
        try context.save()

        XCTAssertTrue(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        try context.save()

        let markers = appearanceMarkers(in: context)
        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers[0].id, olderDuplicate.id)
        XCTAssertEqual(markers[0].key, original.key)
    }

    @MainActor
    func testAppearanceMarkerSurvivesCategoryArrivingLaterAndProtectsItsAppearance() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let phoneID = UUID(uuidString: "82000000-0000-0000-0000-000000000000")!
        let markerKey = "flux.expenseCategories.v3Appearance.category.\(phoneID.uuidString.lowercased())"
        context.insert(AppMigrationState(key: markerKey))
        try context.save()

        XCTAssertFalse(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        try context.save()
        XCTAssertEqual(appearanceMarkers(in: context).map(\.key), [markerKey])

        let phone = Category(
            id: phoneID,
            nameKey: "category.expense.phone",
            icon: "wifi",
            colorHex: "#06B6D4",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(phone)
        try context.save()

        XCTAssertFalse(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        XCTAssertEqual(phone.icon, "wifi")
        XCTAssertEqual(phone.colorHex, "#06B6D4")
        XCTAssertTrue(try ExpenseCategoryMigration.hasCompletedAppearanceUpgrade(
            for: phone,
            in: context
        ))
    }

    @MainActor
    func testMergeRemovesEveryAppearanceMarkerForDeletedSourceIdentity() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let winner = Category(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000000")!,
            nameKey: "category.expense.phone",
            icon: "phone.fill",
            colorHex: "#3B82F6",
            type: .expense,
            isSystemDefault: true
        )
        let source = Category(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000000")!,
            nameKey: "category.expense.phone",
            icon: "phone.fill",
            colorHex: "#3B82F6",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(winner)
        context.insert(source)
        try ExpenseCategoryMigration.markVersionedUpgradeCompleted(in: context)
        try context.save()
        XCTAssertEqual(appearanceMarkers(in: context).count, 2)

        XCTAssertTrue(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Flux.Category>()).map(\.id), [winner.id])
        XCTAssertEqual(appearanceMarkers(in: context).count, 1)
        XCTAssertTrue(try ExpenseCategoryMigration.hasCompletedAppearanceUpgrade(
            for: winner,
            in: context
        ))
        XCTAssertFalse(try ExpenseCategoryMigration.hasCompletedAppearanceUpgrade(
            for: source,
            in: context
        ))
    }

    @MainActor
    func testCategoryServiceDeleteRemovesAppearanceMarker() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        try await DefaultDataSeeder(context: context).seedIfNeeded()
        let phone = try XCTUnwrap(context.fetch(FetchDescriptor<Flux.Category>()).first {
            $0.nameKey == "category.expense.phone" && $0.isSystemDefault
        })
        XCTAssertTrue(try ExpenseCategoryMigration.hasCompletedAppearanceUpgrade(
            for: phone,
            in: context
        ))

        try CategoryService(context: context).delete(phone)

        XCTAssertFalse(try ExpenseCategoryMigration.hasCompletedAppearanceUpgrade(
            for: phone,
            in: context
        ))
    }

    @MainActor
    func testExplicitCategoryResetReplacesOldPerIDMarkersWithoutAccumulating() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let seeder = DefaultDataSeeder(context: context)
        try await seeder.seedIfNeeded()
        let oldMarkerKeys = Set(appearanceMarkers(in: context).map(\.key))
        XCTAssertEqual(oldMarkerKeys.count, 23)

        for category in try context.fetch(FetchDescriptor<Flux.Category>()) {
            context.delete(category)
        }
        try context.save()
        try seeder.seedCategoriesForExplicitReset()
        try context.save()

        let newMarkerKeys = Set(appearanceMarkers(in: context).map(\.key))
        XCTAssertEqual(newMarkerKeys.count, 23)
        XCTAssertTrue(oldMarkerKeys.isDisjoint(with: newMarkerKeys))
        XCTAssertTrue(try ExpenseCategoryMigration.hasCompletedAppearanceUpgrade(in: context))
    }

    @MainActor
    func testUnmarkedReusedLegacyAliasModernizesAndRecordsCompletion() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        context.insert(AppMigrationState(key: ExpenseCategoryMigration.appearanceMigrationKey))
        let bills = Category(
            nameKey: "category.expense.bills",
            icon: "doc.text.fill",
            colorHex: "#64748B",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(bills)
        try context.save()

        XCTAssertTrue(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        try context.save()

        XCTAssertEqual(bills.nameKey, "category.expense.miscellaneous")
        XCTAssertEqual(bills.icon, "ellipsis.circle.fill")
        XCTAssertEqual(bills.colorHex, "#64748B")
        XCTAssertTrue(try ExpenseCategoryMigration.hasCompletedAppearanceUpgrade(
            for: bills,
            in: context
        ))
    }

    @MainActor
    func testPerCategoryAppearanceMigrationIsIdempotent() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let phone = Category(
            nameKey: "category.expense.phone",
            icon: "wifi",
            colorHex: "#06B6D4",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(phone)
        try context.save()

        XCTAssertTrue(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        try context.save()
        XCTAssertFalse(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        XCTAssertFalse(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        XCTAssertEqual(phone.icon, "phone.fill")
        XCTAssertEqual(phone.colorHex, "#3B82F6")
    }

    @MainActor
    func testPersonalCareHistoricalAliasesResolveAndMergeAsSystemDefaults() throws {
        for alias in [
            "Personal Care", "個人護理", "个人护理",
            "Beauty & Personal Care", "美容護理", "美容护理"
        ] {
            XCTAssertEqual(
                Category.resolveSystemCategoryKey(alias),
                "category.expense.personalCare"
            )
        }

        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let english = Category(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000000")!,
            nameKey: "Beauty & Personal Care",
            icon: "shower.fill",
            colorHex: "#F43F5E",
            type: .expense,
            isSystemDefault: true
        )
        let traditionalChinese = Category(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000000")!,
            nameKey: "美容護理",
            icon: "shower.fill",
            colorHex: "#F43F5E",
            type: .expense,
            isSystemDefault: true
        )
        let simplifiedChinese = Category(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000000")!,
            nameKey: "美容护理",
            icon: "shower.fill",
            colorHex: "#F43F5E",
            type: .expense,
            isSystemDefault: true
        )
        let customSameName = Category(
            nameKey: "個人護理",
            icon: "heart.fill",
            colorHex: "#123456",
            type: .expense,
            isSystemDefault: false
        )
        let transactions = [english, traditionalChinese, simplifiedChinese].map {
            transaction(category: $0)
        }
        [english, traditionalChinese, simplifiedChinese, customSameName].forEach(context.insert)
        transactions.forEach(context.insert)
        try context.save()

        XCTAssertTrue(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        try context.save()

        let categories = try context.fetch(FetchDescriptor<Flux.Category>())
        let systemCategories = categories.filter(\.isSystemDefault)
        XCTAssertEqual(systemCategories.count, 1)
        XCTAssertTrue(systemCategories[0] === english)
        XCTAssertEqual(english.nameKey, "category.expense.personalCare")
        XCTAssertEqual(english.icon, "comb")
        XCTAssertEqual(english.colorHex, "#F43F5E")
        XCTAssertTrue(transactions.allSatisfy { $0.category === english })
        XCTAssertEqual(customSameName.nameKey, "個人護理")
        XCTAssertEqual(customSameName.icon, "heart.fill")
        XCTAssertEqual(customSameName.colorHex, "#123456")
    }

    @MainActor
    func testPersonalCareLegacyAliasPreservesCustomizedAppearance() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let personalCare = Category(
            nameKey: "個人護理",
            icon: "heart.fill",
            colorHex: "#123456",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(personalCare)
        try context.save()

        XCTAssertTrue(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))

        XCTAssertEqual(personalCare.nameKey, "category.expense.personalCare")
        XCTAssertEqual(personalCare.icon, "heart.fill")
        XCTAssertEqual(personalCare.colorHex, "#123456")
    }

    @MainActor
    func testOneTimeUpgradeModernizesOnlyPreviouslyShippedAppearance() async throws {
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
        let phone = Category(
            nameKey: "category.expense.phone",
            icon: "wifi",
            colorHex: "#06B6D4",
            type: .expense,
            isSystemDefault: true
        )
        let customizedPhoneIcon = Category(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000000")!,
            nameKey: "category.expense.phone",
            icon: "star.fill",
            colorHex: "#06B6D4",
            type: .expense,
            isSystemDefault: false
        )
        let home = Category(
            nameKey: "category.expense.home",
            icon: "house.fill",
            colorHex: "#123456",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(personalCare)
        context.insert(entertainment)
        context.insert(phone)
        context.insert(customizedPhoneIcon)
        context.insert(home)
        try context.save()

        try await DefaultDataSeeder(context: context).seedIfNeeded()

        XCTAssertEqual(personalCare.icon, "comb")
        XCTAssertEqual(personalCare.colorHex, "#F43F5E")
        XCTAssertEqual(entertainment.icon, "gamecontroller.fill")
        XCTAssertEqual(entertainment.colorHex, "#112233")
        XCTAssertEqual(phone.icon, "phone.fill")
        XCTAssertEqual(phone.colorHex, "#3B82F6")
        XCTAssertEqual(customizedPhoneIcon.icon, "star.fill")
        XCTAssertEqual(customizedPhoneIcon.colorHex, "#06B6D4")
        XCTAssertEqual(home.icon, "sofa.fill")
        XCTAssertEqual(home.colorHex, "#123456")
        XCTAssertTrue(try ExpenseCategoryMigration.hasCompletedAppearanceUpgrade(in: context))
    }

    @MainActor
    func testAppearanceUpgradeRunsAfterV2WithoutRecreatingDeletedCategories() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        context.insert(Currency(code: "HKD", exchangeRateToBase: 1, isBaseCurrency: true))
        context.insert(AppMigrationState(key: ExpenseCategoryMigration.versionedMigrationKey))
        let phone = Category(
            nameKey: "category.expense.phone",
            icon: "wifi",
            colorHex: "#06B6D4",
            type: .expense,
            isSystemDefault: true
        )
        let customizedEntertainment = Category(
            nameKey: "category.expense.entertainment",
            icon: "gamecontroller.fill",
            colorHex: "#112233",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(phone)
        context.insert(customizedEntertainment)
        try context.save()

        try await DefaultDataSeeder(context: context).seedIfNeeded()

        let categories = try context.fetch(FetchDescriptor<Flux.Category>())
        XCTAssertEqual(categories.filter { $0.type == .expense }.count, 2)
        XCTAssertEqual(phone.icon, "phone.fill")
        XCTAssertEqual(phone.colorHex, "#3B82F6")
        XCTAssertEqual(customizedEntertainment.icon, "gamecontroller.fill")
        XCTAssertEqual(customizedEntertainment.colorHex, "#112233")
        XCTAssertTrue(try ExpenseCategoryMigration.hasCompletedAppearanceUpgrade(in: context))
    }

    @MainActor
    func testMergingLegacyAliasCarriesCustomizedAppearanceOntoDefaultTarget() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let learning = Category(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000000")!,
            nameKey: "category.expense.learning",
            icon: "books.vertical.fill",
            colorHex: "#3B82F6",
            type: .expense,
            isSystemDefault: true
        )
        let customizedEducation = Category(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000000")!,
            nameKey: "category.expense.education",
            icon: "star.fill",
            colorHex: "#123456",
            type: .expense,
            isSystemDefault: true
        )
        context.insert(learning)
        context.insert(customizedEducation)
        try context.save()

        XCTAssertTrue(try ExpenseCategoryMigration.normalizeLegacySystemCategories(in: context))
        try context.save()

        let categories = try context.fetch(FetchDescriptor<Flux.Category>())
        XCTAssertEqual(categories.count, 1)
        XCTAssertTrue(categories[0] === learning)
        XCTAssertEqual(learning.icon, "star.fill")
        XCTAssertEqual(learning.colorHex, "#123456")
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

    @MainActor
    private func appearanceMarkers(in context: ModelContext) throws -> [AppMigrationState] {
        try context.fetch(FetchDescriptor<AppMigrationState>()).filter {
            $0.key.hasPrefix("flux.expenseCategories.v3Appearance.category.")
        }
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ExpenseCategoryMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func clear(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: ExpenseCategoryMigration.versionedMigrationKey)
        defaults.removeObject(forKey: ExpenseCategoryMigration.appearanceMigrationKey)
    }
}
