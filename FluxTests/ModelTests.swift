import XCTest
import SwiftData
@testable import Flux

@MainActor
final class ModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var originalAppLanguage: AppLanguage?
    
    override func setUp() async throws {
        container = try ModelContainerConfiguration.createTestContainer()
        context = container.mainContext
        originalAppLanguage = AppLanguagePreference.language
        AppLanguagePreference.language = .english
    }
    
    override func tearDown() async throws {
        if let originalAppLanguage {
            AppLanguagePreference.language = originalAppLanguage
        }
        originalAppLanguage = nil
        container = nil
        context = nil
    }
    
    // MARK: - Currency Tests
    
    func testCurrencyConversion() throws {
        let usd = Currency(code: "USD", exchangeRateToBase: 1.0, isBaseCurrency: true)
        let twd = Currency(code: "TWD", exchangeRateToBase: 0.031) // 1 TWD = 0.031 USD
        
        context.insert(usd)
        context.insert(twd)
        
        let amountInTWD: Decimal = 1000
        let convertedToUSD = twd.convertToBase(amountInTWD)
        
        XCTAssertEqual(convertedToUSD, 31, "1000 TWD should equal 31 USD")
    }
    
    // MARK: - Category Tests
    
    func testCategoryHierarchy() throws {
        let parent = Category(
            nameKey: "Food",
            icon: "fork.knife",
            colorHex: "#FF0000",
            type: .expense,
            isSystemDefault: false
        )
        context.insert(parent)
        
        let child = Category(
            nameKey: "Restaurants",
            icon: "cup.and.saucer",
            colorHex: "#FF5555",
            type: .expense,
            isSystemDefault: false,
            parentCategory: parent
        )
        context.insert(child)
        
        try context.save()
        
        XCTAssertTrue(child.isSubcategory)
        XCTAssertEqual(parent.subcategories?.count, 1)
        XCTAssertEqual(parent.subcategories?.first?.nameKey, "Restaurants")
    }
    
    // MARK: - Account Tests

    func testDefaultAccountDisplayNameFollowsSelectedLanguageWithoutChangingPersistedName() throws {
        AppLanguagePreference.language = .simplifiedChinese
        let typeDefinition = AccountTypeDefinition(
            name: AccountType.bank.defaultSeedName,
            icon: AccountType.bank.defaultIcon,
            colorHex: "#0A84FF",
            isSystemDefault: true,
            legacyType: .bank
        )
        let account = Account(
            name: AccountType.bank.defaultSeedName,
            type: .bank,
            currencyCode: "USD",
            typeDefinition: typeDefinition
        )

        XCTAssertEqual(account.displayName, "银行账户")
        XCTAssertEqual(
            account.persistedName(fromEditedDisplayName: account.displayName),
            "Bank Account"
        )
    }

    func testDefaultAccountEditedNamePersistsCustomName() throws {
        AppLanguagePreference.language = .traditionalChinese
        let account = Account(
            name: AccountType.creditCard.defaultSeedName,
            type: .creditCard,
            currencyCode: "HKD"
        )

        XCTAssertEqual(account.displayName, "信用卡")
        XCTAssertEqual(
            account.persistedName(fromEditedDisplayName: "Visa 主卡"),
            "Visa 主卡"
        )
    }

    func testDefaultAccountTypeChangePersistsNewDefaultSeedName() throws {
        AppLanguagePreference.language = .traditionalChinese
        let bankDefinition = AccountTypeDefinition(
            name: AccountType.bank.defaultSeedName,
            icon: AccountType.bank.defaultIcon,
            colorHex: "#0A84FF",
            isSystemDefault: true,
            legacyType: .bank
        )
        let bankDisplayName = Account.defaultDisplayName(for: .bank, typeDefinition: bankDefinition)

        XCTAssertEqual(bankDisplayName, "銀行帳戶")
        XCTAssertEqual(
            Account.persistedName(
                fromEditedDisplayName: bankDisplayName,
                matchingDefaultDisplayName: bankDisplayName,
                targetType: .bank,
                targetTypeDefinition: bankDefinition
            ),
            "Bank Account"
        )
    }
    
    func testAccountBalance() throws {
        let account = Account(
            name: "Test Account",
            type: .bank,
            currencyCode: "USD",
            initialBalance: 1000
        )
        context.insert(account)
        
        let income = Transaction(
            amount: 500,
            currencyCode: "USD",
            type: .income,
            account: account,
            category: nil
        )
        context.insert(income)
        
        let expense = Transaction(
            amount: 200,
            currencyCode: "USD",
            type: .expense,
            account: account,
            category: nil
        )
        context.insert(expense)
        
        try context.save()
        
        XCTAssertEqual(account.currentBalance, 1300, "Balance should be 1000 + 500 - 200")
    }

    func testAccountBalanceExcludesFutureAndTemplateTransactions() throws {
        let account = Account(
            name: "Future-safe Account",
            type: .bank,
            currencyCode: "USD",
            initialBalance: 1000
        )
        context.insert(account)

        context.insert(Transaction(
            amount: 100,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
            account: account,
            category: nil
        ))

        context.insert(Transaction(
            amount: 200,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 7, to: .now)!,
            account: account,
            category: nil
        ))

        context.insert(Transaction(
            amount: 50,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            isRecurringTemplate: true,
            recurrenceRule: .monthly,
            account: account
        ))

        try context.save()

        XCTAssertEqual(account.currentBalance, 900)
    }
    
    // MARK: - Transaction Tests
    
    func testRecurringTransactionTemplate() throws {
        let account = Account(name: "Test", type: .cash, currencyCode: "USD")
        context.insert(account)
        
        let template = Transaction(
            amount: 100,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            isRecurringTemplate: true,
            recurrenceRule: .monthly,
            account: account
        )
        context.insert(template)
        
        let instance = Transaction.fromTemplate(template, forDate: .now)
        context.insert(instance)
        
        try context.save()
        
        XCTAssertTrue(template.isRecurringTemplate)
        XCTAssertFalse(instance.isRecurringTemplate)
        XCTAssertEqual(instance.recurringTemplateId, template.id)
        XCTAssertEqual(instance.originalScheduledOccurrenceDate, instance.date)
        XCTAssertTrue(instance.isGeneratedFromRecurring)
        XCTAssertTrue(instance.isPendingScheduledOccurrence)
    }

    func testLegacyInstallmentRawValueResolvesAsRecurring() throws {
        let account = Account(name: "Legacy Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let template = Transaction(
            amount: 120,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            isRecurringTemplate: true,
            recurrenceRule: .monthly,
            account: account
        )
        template.schedulePlanTypeRawValue = "installment"
        context.insert(template)

        try context.save()

        XCTAssertEqual(template.schedulePlanType, nil)
        XCTAssertEqual(template.resolvedSchedulePlanType, .recurring)
    }

    func testFutureGeneratedScheduledFlag() throws {
        let account = Account(name: "Generated Account", type: .cash, currencyCode: "USD")
        context.insert(account)

        let transaction = Transaction(
            amount: 45,
            currencyCode: "USD",
            type: .expense,
            date: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
            recurringTemplateId: UUID(),
            account: account
        )
        context.insert(transaction)
        try context.save()

        XCTAssertTrue(transaction.isFutureGeneratedScheduled)
    }
    
    // MARK: - Budget Tests
    
    func testBudgetUsage() throws {
        let category = Category(
            nameKey: "Food",
            icon: "fork.knife",
            colorHex: "#FF0000",
            type: .expense,
            isSystemDefault: false
        )
        context.insert(category)
        
        let budget = Budget(
            limitAmount: 500,
            currencyCode: "USD",
            period: .monthly,
            alertThreshold: 0.8,
            category: category
        )
        context.insert(budget)
        
        let account = Account(name: "Test", type: .cash, currencyCode: "USD")
        context.insert(account)
        
        // Add expense within current month
        let expense = Transaction(
            amount: 400,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            account: account,
            category: category
        )
        context.insert(expense)
        
        try context.save()
        
        let spent = budget.spentAmount(in: context)
        let percentage = budget.usagePercentage(in: context)
        
        XCTAssertEqual(spent, 400)
        XCTAssertEqual(percentage, 0.8)
        XCTAssertTrue(budget.isAlertTriggered(in: context))
        XCTAssertFalse(budget.isExceeded(in: context))
    }

    func testBudgetUsageAllCategoriesTracksAllExpenses() throws {
        let food = Category(
            nameKey: "Food",
            icon: "fork.knife",
            colorHex: "#FF0000",
            type: .expense,
            isSystemDefault: false
        )
        context.insert(food)

        let transport = Category(
            nameKey: "Transport",
            icon: "car.fill",
            colorHex: "#00AAFF",
            type: .expense,
            isSystemDefault: false
        )
        context.insert(transport)

        let budget = Budget(
            limitAmount: 500,
            currencyCode: "USD",
            period: .monthly,
            alertThreshold: 0.8,
            category: nil
        )
        context.insert(budget)

        let account = Account(name: "Test", type: .cash, currencyCode: "USD")
        context.insert(account)

        context.insert(Transaction(
            amount: 120,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            account: account,
            category: food
        ))

        context.insert(Transaction(
            amount: 80,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            account: account,
            category: transport
        ))

        context.insert(Transaction(
            amount: 60,
            currencyCode: "USD",
            type: .expense,
            date: .now,
            account: account,
            category: nil
        ))

        context.insert(Transaction(
            amount: 200,
            currencyCode: "USD",
            type: .income,
            date: .now,
            account: account,
            category: nil
        ))

        try context.save()

        XCTAssertEqual(budget.spentAmount(in: context), 260)
    }
    
    // MARK: - RecurrenceRule Tests
    
    func testRecurrenceRuleNextDate() {
        let startDate = Date(timeIntervalSince1970: 0) // Jan 1, 1970
        let calendar = Calendar(identifier: .gregorian)
        
        let dailyNext = RecurrenceRule.daily.nextDate(from: startDate, calendar: calendar)
        XCTAssertEqual(
            calendar.dateComponents([.day], from: startDate, to: dailyNext).day,
            1
        )
        
        let weeklyNext = RecurrenceRule.weekly.nextDate(from: startDate, calendar: calendar)
        XCTAssertEqual(
            calendar.dateComponents([.day], from: startDate, to: weeklyNext).day,
            7
        )
        
        let monthlyNext = RecurrenceRule.monthly.nextDate(from: startDate, calendar: calendar)
        XCTAssertEqual(
            calendar.dateComponents([.month], from: startDate, to: monthlyNext).month,
            1
        )
    }
}
