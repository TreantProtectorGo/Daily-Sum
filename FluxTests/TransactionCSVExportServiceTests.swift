import XCTest
import SwiftData
@testable import Flux

@MainActor
final class TransactionCSVExportServiceTests: XCTestCase {
    private final class MockQuoteProvider: CurrencyQuoteProviding {
        struct Request: Equatable {
            let amount: Decimal
            let source: String
            let target: String
            let date: Date
            let mode: ConversionMode
        }

        var result: Result<CurrencyConversionQuote, Error>
        private(set) var requests: [Request] = []

        init(result: Result<CurrencyConversionQuote, Error>) {
            self.result = result
        }

        func convertWithQuote(
            _ amount: Decimal,
            from sourceCurrencyCode: String,
            to targetCurrencyCode: String,
            on date: Date,
            mode: ConversionMode
        ) async throws -> CurrencyConversionQuote {
            requests.append(
                Request(
                    amount: amount,
                    source: sourceCurrencyCode,
                    target: targetCurrencyCode,
                    date: date,
                    mode: mode
                )
            )
            return try result.get()
        }
    }

    private var container: ModelContainer!
    private var context: ModelContext!
    private var exportDirectory: URL!

    override func setUpWithError() throws {
        container = try ModelContainerConfiguration.createTestContainer()
        context = container.mainContext
        exportDirectory = FileManager.default.temporaryDirectory
            .appending(path: "TransactionCSVExportServiceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: exportDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let exportDirectory {
            try? FileManager.default.removeItem(at: exportDirectory)
        }
        exportDirectory = nil
        context = nil
        container = nil
    }

    func testExportUsesStableSchemaAndExportsActualTransactionsNewestFirst() async throws {
        let account = Account(name: "HK Card", type: .creditCard, currencyCode: "HKD")
        let category = Category(
            nameKey: "Dining",
            icon: "fork.knife",
            colorHex: "#FF0000",
            type: .expense
        )
        context.insert(account)
        context.insert(category)

        let older = Transaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            amount: 100,
            currencyCode: "HKD",
            type: .expense,
            date: isoDate("2024-01-01T10:00:00Z"),
            createdAt: isoDate("2024-01-01T10:01:00Z"),
            notes: "Lunch",
            account: account,
            category: category
        )
        let newerGenerated = Transaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            amount: 50,
            currencyCode: "HKD",
            type: .income,
            date: isoDate("2024-01-02T10:00:00Z"),
            createdAt: isoDate("2024-01-02T10:01:00Z"),
            notes: nil,
            isTravelTransaction: true,
            travelAmount: 1_000,
            travelCurrencyCode: "JPY",
            travelExchangeRate: 0.05,
            travelExchangeRateEffectiveDate: isoDate("2024-01-02T00:00:00Z"),
            travelExchangeRateProvider: "Travel FX",
            receiptImageData: Data([0x01]),
            recurringTemplateId: UUID(),
            generatedDate: isoDate("2024-01-01T00:00:00Z"),
            account: account,
            category: category
        )
        let template = Transaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            amount: 999,
            currencyCode: "HKD",
            type: .expense,
            date: isoDate("2024-01-03T10:00:00Z"),
            isRecurringTemplate: true,
            account: account,
            category: category
        )
        context.insert(older)
        context.insert(newerGenerated)
        context.insert(template)
        try context.save()

        let quoteProvider = MockQuoteProvider(
            result: .success(
                CurrencyConversionQuote(
                    convertedAmount: 6.4,
                    rate: 0.128,
                    effectiveDate: isoDate("2024-01-02T00:00:00Z"),
                    provider: "Test FX"
                )
            )
        )
        let service = TransactionCSVExportService(
            context: context,
            quoteProvider: quoteProvider,
            exportDirectory: exportDirectory,
            now: { self.isoDate("2024-01-03T12:00:00Z") }
        )

        let url = try await service.exportTransactions(displayCurrencyCode: "USD")
        let lines = try csvLines(at: url)

        XCTAssertEqual(url.lastPathComponent, "Flux_Transactions_2024-01-03.csv")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(
            lines[0],
            "id,date,created_at,type,original_amount,original_currency,converted_amount,converted_currency,conversion_rate,account,category,notes,is_travel_transaction,travel_amount,travel_currency,travel_exchange_rate,travel_exchange_rate_effective_date,travel_exchange_rate_provider,has_receipt"
        )
        XCTAssertTrue(lines[1].hasPrefix("00000000-0000-0000-0000-000000000002,"))
        XCTAssertTrue(lines[2].hasPrefix("00000000-0000-0000-0000-000000000001,"))
        XCTAssertEqual(
            lines[1],
            "00000000-0000-0000-0000-000000000002,2024-01-02T10:00:00.000Z,2024-01-02T10:01:00.000Z,income,50,HKD,6.4,USD,0.128,HK Card,Dining,,true,1000,JPY,0.05,2024-01-02T00:00:00.000Z,Travel FX,true"
        )
        XCTAssertEqual(quoteProvider.requests.count, 2)
        XCTAssertEqual(quoteProvider.requests.map(\.mode), [.historical, .historical])
    }

    func testExportLeavesConversionFieldsEmptyWhenQuoteFails() async throws {
        let transaction = Transaction(
            amount: 20,
            currencyCode: "EUR",
            type: .expense,
            date: isoDate("2024-02-01T00:00:00Z")
        )
        context.insert(transaction)
        try context.save()
        let quoteProvider = MockQuoteProvider(
            result: .failure(NSError(domain: "FX", code: 1))
        )
        let service = makeService(quoteProvider: quoteProvider)

        let url = try await service.exportTransactions(displayCurrencyCode: "USD")
        let fields = try XCTUnwrap(csvLines(at: url).dropFirst().first).split(
            separator: ",",
            omittingEmptySubsequences: false
        )

        XCTAssertEqual(fields.count, 19)
        XCTAssertEqual(String(fields[4]), "20")
        XCTAssertEqual(String(fields[5]), "EUR")
        XCTAssertEqual(String(fields[6]), "")
        XCTAssertEqual(String(fields[7]), "")
        XCTAssertEqual(String(fields[8]), "")
    }

    func testExportUsesCreationDateThenUUIDAsDeterministicTieBreakers() async throws {
        let transactionDate = isoDate("2024-02-01T00:00:00Z")
        let newestCreated = Transaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            amount: 3,
            currencyCode: "USD",
            type: .expense,
            date: transactionDate,
            createdAt: isoDate("2024-02-01T00:02:00Z")
        )
        let lowerUUID = Transaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            amount: 1,
            currencyCode: "USD",
            type: .expense,
            date: transactionDate,
            createdAt: isoDate("2024-02-01T00:01:00Z")
        )
        let higherUUID = Transaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            amount: 2,
            currencyCode: "USD",
            type: .expense,
            date: transactionDate,
            createdAt: isoDate("2024-02-01T00:01:00Z")
        )
        context.insert(higherUUID)
        context.insert(lowerUUID)
        context.insert(newestCreated)
        try context.save()
        let quoteProvider = MockQuoteProvider(
            result: .failure(NSError(domain: "Unexpected", code: 1))
        )

        let url = try await makeService(quoteProvider: quoteProvider)
            .exportTransactions(displayCurrencyCode: "USD")
        let ids = try csvLines(at: url).dropFirst().map {
            String($0.split(separator: ",", maxSplits: 1)[0])
        }

        XCTAssertEqual(
            ids,
            [
                "00000000-0000-0000-0000-000000000003",
                "00000000-0000-0000-0000-000000000001",
                "00000000-0000-0000-0000-000000000002"
            ]
        )
    }

    func testExportSameCurrencyUsesOriginalAmountWithoutQuoteRequest() async throws {
        context.insert(
            Transaction(
                amount: 12.34,
                currencyCode: "USD",
                type: .expense,
                date: isoDate("2024-02-01T00:00:00Z")
            )
        )
        try context.save()
        let quoteProvider = MockQuoteProvider(
            result: .failure(NSError(domain: "Unexpected", code: 1))
        )
        let service = makeService(quoteProvider: quoteProvider)

        let url = try await service.exportTransactions(displayCurrencyCode: "USD")
        let fields = try XCTUnwrap(csvLines(at: url).dropFirst().first).split(
            separator: ",",
            omittingEmptySubsequences: false
        )

        XCTAssertEqual(String(fields[6]), "12.34")
        XCTAssertEqual(String(fields[7]), "USD")
        XCTAssertEqual(String(fields[8]), "1")
        XCTAssertTrue(quoteProvider.requests.isEmpty)
    }

    func testExportWithNoTransactionsProducesHeaderOnlyFile() async throws {
        let quoteProvider = MockQuoteProvider(
            result: .failure(NSError(domain: "Unexpected", code: 1))
        )
        let service = makeService(quoteProvider: quoteProvider)

        let url = try await service.exportTransactions(displayCurrencyCode: "USD")
        let data = try Data(contentsOf: url)

        XCTAssertTrue(data.starts(with: [0xEF, 0xBB, 0xBF]))
        XCTAssertEqual(try csvLines(at: url).count, 1)
        XCTAssertTrue(quoteProvider.requests.isEmpty)
    }

    func testExportRemovesPreviousTransactionCSVWithoutTouchingOtherFiles() async throws {
        let previousExport = exportDirectory.appending(path: "Flux_Transactions_2024-01-02.csv")
        let unrelatedFile = exportDirectory.appending(path: "keep-me.txt")
        try Data("old".utf8).write(to: previousExport)
        try Data("keep".utf8).write(to: unrelatedFile)
        let quoteProvider = MockQuoteProvider(
            result: .failure(NSError(domain: "Unexpected", code: 1))
        )

        let newExport = try await makeService(quoteProvider: quoteProvider)
            .exportTransactions(displayCurrencyCode: "USD")

        XCTAssertFalse(FileManager.default.fileExists(atPath: previousExport.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newExport.path))
    }

    private func makeService(quoteProvider: MockQuoteProvider) -> TransactionCSVExportService {
        TransactionCSVExportService(
            context: context,
            quoteProvider: quoteProvider,
            exportDirectory: exportDirectory,
            now: { self.isoDate("2024-01-03T12:00:00Z") }
        )
    }

    private func csvLines(at url: URL) throws -> [String] {
        let data = try Data(contentsOf: url)
        let contents = String(decoding: data.dropFirst(3), as: UTF8.self)
        let records = contents.components(separatedBy: "\r\n")
        return Array(records.dropLast())
    }

    private func isoDate(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
}
