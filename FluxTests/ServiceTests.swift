import XCTest
import SwiftData
@testable import Flux

@MainActor
final class ServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUp() async throws {
        container = try ModelContainerConfiguration.createTestContainer()
        context = container.mainContext
    }
    
    override func tearDown() async throws {
        container = nil
        context = nil
    }
    
    // MARK: - TransactionService Tests
    
    func testTransactionServiceCRUD() async throws {
        let service = TransactionService(context: context)
        
        // Create account and category first
        let account = Account(name: "Test", type: .cash, currencyCode: "USD", initialBalance: 1000)
        context.insert(account)
        
        let category = Category(nameKey: "Food", icon: "fork.knife", colorHex: "#FF0000", type: .expense, isSystemDefault: false)
        context.insert(category)
        try context.save()
        
        // Create
        let transaction = try service.create(
            amount: 50,
            type: .expense,
            date: .now,
            notes: "Test transaction",
            account: account,
            category: category
        )
        XCTAssertEqual(transaction.amount, 50)
        
        // Read
        let fetched = try service.fetch(byId: transaction.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.notes, "Test transaction")
        
        // Update
        try service.update(transaction, amount: 75, notes: "Updated notes")
        XCTAssertEqual(transaction.amount, 75)
        XCTAssertEqual(transaction.notes, "Updated notes")
        
        // Delete
        try service.delete(transaction)
        let afterDelete = try service.fetch(byId: transaction.id)
        XCTAssertNil(afterDelete)
    }
    
    func testTransactionServiceFiltering() async throws {
        let service = TransactionService(context: context)
        
        let account = Account(name: "Test", type: .cash, currencyCode: "USD")
        context.insert(account)
        
        let category = Category(nameKey: "Food", icon: "fork.knife", colorHex: "#FF0000", type: .expense, isSystemDefault: false)
        context.insert(category)
        try context.save()
        
        // Create multiple transactions
        for i in 0..<5 {
            let _ = try service.create(
                amount: Decimal(i * 10 + 10),
                type: i % 2 == 0 ? .expense : .income,
                date: Calendar.current.date(byAdding: .day, value: -i, to: .now)!,
                account: account,
                category: category
            )
        }
        
        // Test type filtering
        let expenses = try service.fetch(type: .expense)
        XCTAssertEqual(expenses.count, 3)
        
        let income = try service.fetch(type: .income)
        XCTAssertEqual(income.count, 2)
        
        // Test limit
        let limited = try service.fetch(limit: 2)
        XCTAssertEqual(limited.count, 2)
    }
    
    // MARK: - AccountService Tests
    
    func testAccountServiceTotalBalance() async throws {
        let service = AccountService(context: context)
        
        // Create accounts
        let _ = try service.create(
            name: "Checking",
            type: .bank,
            currencyCode: "USD",
            initialBalance: 1000
        )
        
        let _ = try service.create(
            name: "Savings",
            type: .bank,
            currencyCode: "USD",
            initialBalance: 5000
        )
        
        let total = try service.totalBalance(convertToBase: false)
        XCTAssertEqual(total, 6000)
    }
    
    func testAccountCurrencyUpdatePropagatesToTransactions() async throws {
        let accountService = AccountService(context: context)
        let transactionService = TransactionService(context: context)
        
        let account = try accountService.create(
            name: "Wallet",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 100
        )
        
        let transaction = try transactionService.create(
            amount: 25,
            type: .expense,
            account: account,
            category: nil
        )
        
        XCTAssertEqual(transaction.currencyCode, "USD")
        
        try accountService.update(account, currencyCode: "TWD")
        
        XCTAssertEqual(account.currencyCode, "TWD")
        XCTAssertEqual(transaction.currencyCode, "TWD")
    }
    
    func testAccountServiceUpdateInitialBalance() async throws {
        let accountService = AccountService(context: context)
        
        let account = try accountService.create(
            name: "Wallet",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 100
        )
        
        XCTAssertEqual(account.initialBalance, 100)
        
        try accountService.update(account, initialBalance: 250)
        
        XCTAssertEqual(account.initialBalance, 250)
    }
    
    func testAccountServiceAdjustCurrentBalanceCreatesDeltaTransaction() async throws {
        let accountService = AccountService(context: context)
        let transactionService = TransactionService(context: context)
        
        let account = try accountService.create(
            name: "Wallet",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 100
        )
        
        _ = try transactionService.create(
            amount: 40,
            type: .expense,
            account: account,
            category: nil
        )
        
        XCTAssertEqual(account.currentBalance, 60)
        
        let adjustment = try accountService.adjustCurrentBalance(
            account,
            to: 50,
            note: "Manual balance adjustment"
        )
        
        XCTAssertNotNil(adjustment)
        XCTAssertEqual(adjustment?.type, .expense)
        XCTAssertEqual(adjustment?.amount, 10)
        XCTAssertEqual(adjustment?.notes, "Manual balance adjustment")
        XCTAssertEqual(account.currentBalance, 50)
    }
    
    // MARK: - CategoryService Tests
    
    func testCategoryServiceHierarchy() async throws {
        let service = CategoryService(context: context)
        
        let parent = try service.create(
            name: "Food",
            icon: "fork.knife",
            colorHex: "#FF0000",
            type: .expense
        )
        
        let _ = try service.create(
            name: "Restaurants",
            icon: "cup.and.saucer",
            colorHex: "#FF5555",
            type: .expense,
            parentCategory: parent
        )
        
        let topLevel = try service.fetchTopLevel(type: .expense)
        XCTAssertEqual(topLevel.count, 1)
        
        let subcategories = try service.fetchSubcategories(of: parent)
        XCTAssertEqual(subcategories.count, 1)
    }
    
    func testCategoryServiceTypeMismatch() async throws {
        let service = CategoryService(context: context)
        
        let expenseCategory = try service.create(
            name: "Food",
            icon: "fork.knife",
            colorHex: "#FF0000",
            type: .expense
        )
        
        // Should throw error when trying to add income subcategory to expense parent
        do {
            let _ = try service.create(
                name: "Salary",
                icon: "banknote",
                colorHex: "#00FF00",
                type: .income,
                parentCategory: expenseCategory
            )
            XCTFail("Should have thrown typeMismatch error")
        } catch let error as CategoryService.CategoryError {
            XCTAssertEqual(error, .typeMismatch)
        }
    }
    
    // MARK: - BudgetService Tests
    
    func testBudgetServiceAlerts() async throws {
        let categoryService = CategoryService(context: context)
        let transactionService = TransactionService(context: context)
        let budgetService = BudgetService(context: context)
        let accountService = AccountService(context: context)
        
        let category = try categoryService.create(
            name: "Shopping",
            icon: "bag",
            colorHex: "#FF0000",
            type: .expense
        )
        
        let account = try accountService.create(
            name: "Test",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 10000
        )
        
        let budget = try budgetService.create(
            category: category,
            limitAmount: 100,
            currencyCode: "USD",
            alertThreshold: 0.5
        )
        
        // Add expense that triggers alert (> 50%)
        let _ = try transactionService.create(
            amount: 60,
            type: .expense,
            account: account,
            category: category
        )
        
        let triggered = try budgetService.triggeredAlerts()
        XCTAssertEqual(triggered.count, 1)
        XCTAssertEqual(triggered.first?.id, budget.id)
    }
    
    func testBudgetServiceRejectsDuplicateCategoryAndPeriod() async throws {
        let categoryService = CategoryService(context: context)
        let budgetService = BudgetService(context: context)
        
        let category = try categoryService.create(
            name: "Transport",
            icon: "car",
            colorHex: "#2E86DE",
            type: .expense
        )
        
        _ = try budgetService.create(
            category: category,
            limitAmount: 200,
            currencyCode: "USD",
            period: .monthly
        )
        
        do {
            _ = try budgetService.create(
                category: category,
                limitAmount: 300,
                currencyCode: "USD",
                period: .monthly
            )
            XCTFail("Expected duplicate budget validation to fail")
        } catch let error as BudgetService.BudgetError {
            XCTAssertEqual(error, .duplicateBudget)
        }
    }

    func testBudgetServiceRejectsDuplicateAllCategoriesAndPeriod() async throws {
        let budgetService = BudgetService(context: context)

        let allCategoriesBudget = try budgetService.create(
            category: nil,
            limitAmount: 500,
            currencyCode: "USD",
            period: .monthly
        )
        XCTAssertNil(allCategoriesBudget.category)

        do {
            _ = try budgetService.create(
                category: nil,
                limitAmount: 600,
                currencyCode: "USD",
                period: .monthly
            )
            XCTFail("Expected duplicate all-categories budget validation to fail")
        } catch let error as BudgetService.BudgetError {
            XCTAssertEqual(error, .duplicateBudget)
        }
    }

    func testBudgetServiceUpdateCanClearCategoryToAllCategories() async throws {
        let categoryService = CategoryService(context: context)
        let budgetService = BudgetService(context: context)

        let category = try categoryService.create(
            name: "Food",
            icon: "fork.knife",
            colorHex: "#FF0000",
            type: .expense
        )

        let budget = try budgetService.create(
            category: category,
            limitAmount: 300,
            currencyCode: "USD",
            period: .monthly
        )
        XCTAssertNotNil(budget.category)

        try budgetService.update(
            budget,
            category: nil,
            shouldUpdateCategory: true
        )

        XCTAssertNil(budget.category)
    }
}
