import SwiftData
import XCTest
@testable import Flux

@MainActor
final class TransactionServiceTests: XCTestCase {
    func testGroupsTransactionTotalsByStableCategoryID() throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let account = Account(name: "Cash", type: .cash, currencyCode: "USD")
        let food = Category(
            nameKey: "Food",
            icon: "fork.knife",
            colorHex: "#FF9500",
            type: .expense
        )
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        context.insert(account)
        context.insert(food)
        context.insert(Transaction(
            amount: 12,
            currencyCode: "USD",
            type: .expense,
            date: date,
            account: account,
            category: food
        ))
        context.insert(Transaction(
            amount: 8,
            currencyCode: "USD",
            type: .expense,
            date: date,
            account: account,
            category: food
        ))
        try context.save()

        let service = TransactionService(context: context)
        let grouped = try service.groupedByCategory(
            from: date.addingTimeInterval(-1),
            to: date.addingTimeInterval(1),
            type: .expense
        )

        XCTAssertEqual(grouped, [food.id: 20])
    }
}
