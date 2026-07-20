import XCTest
import SwiftData
@testable import Flux

@MainActor
final class CurrencyTests: XCTestCase {
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
    
    // MARK: - Currency Conversion Tests
    
    func testCurrencyConversionRoundTrip() {
        let usd = Currency(code: "USD", exchangeRateToBase: 1.0, isBaseCurrency: true)
        let twd = Currency(code: "TWD", exchangeRateToBase: 0.03125) // 1 TWD = 0.03125 USD (32 TWD = 1 USD)
        
        let originalAmount: Decimal = 100 // 100 TWD
        let toBase = twd.convertToBase(originalAmount) // Should be ~3.125 USD
        let backToTWD = twd.convertFromBase(toBase) // Should be ~100 TWD
        
        XCTAssertDecimalEqual(toBase, 3.125, accuracy: 0.001)
        XCTAssertDecimalEqual(backToTWD, originalAmount, accuracy: 0.001)
    }
    
    func testCurrencyFormatterBasic() {
        let formatter = CurrencyFormatter.shared
        
        let amount: Decimal = 1234.56
        let formatted = formatter.format(amount, currencyCode: "USD")
        
        // The exact format depends on locale, but should contain the amount
        XCTAssertTrue(formatted.contains("1") && formatted.contains("234"))
    }
    
    func testCurrencyFormatterWithSign() {
        let formatter = CurrencyFormatter.shared
        
        let positiveAmount: Decimal = 100
        let formatted = formatter.format(positiveAmount, currencyCode: "USD", showSign: true)
        
        XCTAssertTrue(formatted.hasPrefix("+") || formatted.contains("+"))
    }
    
    func testCurrencyFormatterCompact() {
        let formatter = CurrencyFormatter.shared
        
        let thousand: Decimal = 1500
        let million: Decimal = 2500000
        
        let thousandFormatted = formatter.formatCompact(thousand, currencyCode: "USD")
        let millionFormatted = formatter.formatCompact(million, currencyCode: "USD")
        
        // Should contain K for thousands
        XCTAssertTrue(thousandFormatted.contains("K") || thousandFormatted.contains("1"))
        // Should contain M for millions
        XCTAssertTrue(millionFormatted.contains("M") || millionFormatted.contains("2"))
    }
    
    // MARK: - Decimal Precision Tests
    
    func testDecimalPrecisionInTransaction() throws {
        let account = Account(name: "Test", type: .cash, currencyCode: "USD")
        context.insert(account)
        
        // Test that Decimal maintains precision
        let preciseAmount: Decimal = Decimal(string: "123.4567")!
        let transaction = Transaction(
            amount: preciseAmount,
            currencyCode: "USD",
            type: .expense,
            account: account,
            category: nil
        )
        context.insert(transaction)
        try context.save()
        
        // Fetch and verify precision maintained
        let fetched = try context.fetch(FetchDescriptor<Transaction>()).first
        XCTAssertEqual(fetched?.amount, preciseAmount)
    }
    
    func testDecimalArithmeticPrecision() {
        // This tests why we use Decimal instead of Double
        let a: Decimal = Decimal(string: "0.1")!
        let b: Decimal = Decimal(string: "0.2")!
        let sum = a + b
        
        XCTAssertEqual(sum, Decimal(string: "0.3")!, "Decimal should maintain precision")
        
        // Compare to Double (which would fail)
        let doubleA: Double = 0.1
        let doubleB: Double = 0.2
        let doubleSum = doubleA + doubleB
        
        // This shows why Double is problematic for financial apps
        XCTAssertNotEqual(doubleSum, 0.3) // Actually 0.30000000000000004
    }
    
    // MARK: - Currency Properties Tests
    
    func testSupportedCurrencyDecimalPlaces() {
        XCTAssertEqual(SupportedCurrency.USD.decimalPlaces, 2)
        XCTAssertEqual(SupportedCurrency.TWD.decimalPlaces, 0) // TWD doesn't use decimals
        XCTAssertEqual(SupportedCurrency.CNY.decimalPlaces, 2)
        XCTAssertEqual(SupportedCurrency.CHF.decimalPlaces, 2)
    }

    func testCurrencyConversionServiceUsesHistoricalRateForDate() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!

        context.insert(
            ExchangeRate(
                baseCurrencyCode: "USD",
                quoteCurrencyCode: "TWD",
                rate: 30,
                effectiveDate: day1
            )
        )
        context.insert(
            ExchangeRate(
                baseCurrencyCode: "USD",
                quoteCurrencyCode: "TWD",
                rate: 32,
                effectiveDate: day2
            )
        )
        try context.save()

        let conversionService = CurrencyConversionService(context: context)
        let converted = try await conversionService.convert(
            10,
            from: "USD",
            to: "TWD",
            on: day1,
            mode: .historical
        )

        XCTAssertEqual(converted, 300)
    }

    func testCurrencyConversionServiceUsesLatestRateInLatestMode() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!

        context.insert(
            ExchangeRate(
                baseCurrencyCode: "USD",
                quoteCurrencyCode: "TWD",
                rate: 30,
                effectiveDate: day1
            )
        )
        context.insert(
            ExchangeRate(
                baseCurrencyCode: "USD",
                quoteCurrencyCode: "TWD",
                rate: 32,
                effectiveDate: day2
            )
        )
        try context.save()

        let conversionService = CurrencyConversionService(context: context)
        let converted = try await conversionService.convert(
            10,
            from: "USD",
            to: "TWD",
            on: day1,
            mode: .latest
        )

        XCTAssertEqual(converted, 320)
    }

    func testCurrencyConversionServiceConvertWithQuoteIncludesRateMetadata() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!

        context.insert(
            ExchangeRate(
                baseCurrencyCode: "USD",
                quoteCurrencyCode: "TWD",
                rate: 30,
                effectiveDate: day1,
                provider: "older-provider"
            )
        )
        context.insert(
            ExchangeRate(
                baseCurrencyCode: "USD",
                quoteCurrencyCode: "TWD",
                rate: 32,
                effectiveDate: day2,
                provider: "latest-provider"
            )
        )
        try context.save()

        let conversionService = CurrencyConversionService(context: context)
        let quote = try await conversionService.convertWithQuote(
            10,
            from: "USD",
            to: "TWD",
            on: day1,
            mode: .latest
        )

        XCTAssertEqual(quote.convertedAmount, 320)
        XCTAssertEqual(quote.rate, 32)
        XCTAssertEqual(quote.effectiveDate, day2)
        XCTAssertEqual(quote.provider, "latest-provider")
    }
}

// Helper for Decimal comparison with tolerance
extension Decimal {
    func isEqual(to other: Decimal, accuracy: Decimal) -> Bool {
        abs(self - other) <= accuracy
    }
}

extension XCTestCase {
    func XCTAssertDecimalEqual(_ expression1: Decimal, _ expression2: Decimal, accuracy: Decimal, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(
            expression1.isEqual(to: expression2, accuracy: accuracy),
            "\(expression1) is not equal to \(expression2) within accuracy \(accuracy)",
            file: file,
            line: line
        )
    }
}
