import Foundation
import SwiftData

enum UITestFixture {
    static let travelAccountPickerName = "travelAccountPicker"

    @MainActor
    static func makeContainerIfRequested() throws -> ModelContainer? {
        guard RuntimeEnvironment.uiTestFixtureName == travelAccountPickerName else {
            return nil
        }

        let container = try ModelContainerConfiguration.createTestContainer()
        try seedTravelAccountPickerFixture(in: container.mainContext)
        configureTravelAccountPickerPreferences()
        return container
    }

    @MainActor
    private static func seedTravelAccountPickerFixture(in context: ModelContext) throws {
        let accounts = [
            Account(
                id: Self.hkdDefaultAccountId,
                name: "HKD Default",
                type: .bank,
                currencyCode: "HKD",
                createdAt: Date(timeIntervalSinceReferenceDate: 1)
            ),
            Account(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "CNY Wallet",
                type: .cash,
                currencyCode: "CNY",
                createdAt: Date(timeIntervalSinceReferenceDate: 2)
            ),
            Account(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                name: "USD Wallet",
                type: .cash,
                currencyCode: "USD",
                createdAt: Date(timeIntervalSinceReferenceDate: 3)
            ),
            Account(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                name: "CNY Card",
                type: .creditCard,
                currencyCode: "CNY",
                createdAt: Date(timeIntervalSinceReferenceDate: 4)
            )
        ]

        accounts.forEach(context.insert)
        try context.save()
    }

    private static func configureTravelAccountPickerPreferences() {
        UserCurrencyPreference.currencyCode = "HKD"
        TravelCurrencyPreference.source = .manual
        TravelCurrencyPreference.detectedCurrencyCode = nil
        TravelCurrencyPreference.manualCurrencyCode = "CNY"
        TransactionAccountPreference.defaultAccountId = hkdDefaultAccountId
        TransactionAccountPreference.rememberLastUsedAccount = false
        TransactionAccountPreference.lastUsedAccountId = nil
        TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection = false
    }

    private static let hkdDefaultAccountId = UUID(
        uuidString: "11111111-1111-1111-1111-111111111111"
    )!
}
