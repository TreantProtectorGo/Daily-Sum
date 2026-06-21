import Foundation
import SwiftData

@MainActor
protocol TransactionCSVExportServicing {
    func exportTransactions(displayCurrencyCode: String) async throws -> URL
}

@MainActor
final class TransactionCSVExportService: TransactionCSVExportServicing {
    static let headers = [
        "id",
        "date",
        "created_at",
        "type",
        "original_amount",
        "original_currency",
        "converted_amount",
        "converted_currency",
        "conversion_rate",
        "account",
        "category",
        "notes",
        "is_travel_transaction",
        "travel_amount",
        "travel_currency",
        "travel_exchange_rate",
        "travel_exchange_rate_effective_date",
        "travel_exchange_rate_provider",
        "has_receipt"
    ]

    private struct ConversionFields {
        let amount: String
        let currency: String
        let rate: String

        static let unavailable = ConversionFields(amount: "", currency: "", rate: "")
    }

    private let context: ModelContext
    private let quoteProvider: any CurrencyQuoteProviding
    private let encoder: CSVEncoder
    private let exportDirectory: URL
    private let now: () -> Date
    private let fileManager: FileManager
    private let dateFormatter: ISO8601DateFormatter
    private let filenameDateFormatter: DateFormatter

    init(
        context: ModelContext,
        quoteProvider: (any CurrencyQuoteProviding)? = nil,
        exportDirectory: URL = FileManager.default.temporaryDirectory,
        now: @escaping () -> Date = Date.init,
        fileManager: FileManager = .default
    ) {
        self.context = context
        self.quoteProvider = quoteProvider ?? CurrencyConversionService(context: context)
        self.encoder = CSVEncoder()
        self.exportDirectory = exportDirectory
        self.now = now
        self.fileManager = fileManager

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.dateFormatter = dateFormatter

        let filenameDateFormatter = DateFormatter()
        filenameDateFormatter.calendar = Calendar(identifier: .gregorian)
        filenameDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        filenameDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        filenameDateFormatter.dateFormat = "yyyy-MM-dd"
        self.filenameDateFormatter = filenameDateFormatter
    }

    func exportTransactions(displayCurrencyCode: String) async throws -> URL {
        let targetCurrencyCode = displayCurrencyCode.uppercased()
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { !$0.isRecurringTemplate }
        )
        let transactions = try context.fetch(descriptor).sorted(by: transactionSort)
        var rows: [[CSVField]] = []
        rows.reserveCapacity(transactions.count)

        for transaction in transactions {
            rows.append(
                await row(
                    for: transaction,
                    displayCurrencyCode: targetCurrencyCode
                )
            )
        }

        let data = try encoder.encode(headers: Self.headers, rows: rows)
        try fileManager.createDirectory(
            at: exportDirectory,
            withIntermediateDirectories: true
        )
        try removePreviousExports()
        let filename = "Flux_Transactions_\(filenameDateFormatter.string(from: now())).csv"
        let fileURL = exportDirectory.appending(path: filename, directoryHint: .notDirectory)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func removePreviousExports() throws {
        let files = try fileManager.contentsOfDirectory(
            at: exportDirectory,
            includingPropertiesForKeys: nil
        )
        for file in files where file.lastPathComponent.hasPrefix("Flux_Transactions_")
                && file.pathExtension.lowercased() == "csv" {
            try fileManager.removeItem(at: file)
        }
    }

    private func transactionSort(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date > rhs.date
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func row(
        for transaction: Transaction,
        displayCurrencyCode: String
    ) async -> [CSVField] {
        let conversion = await conversionFields(
            for: transaction,
            displayCurrencyCode: displayCurrencyCode
        )

        return [
            .raw(transaction.id.uuidString),
            .raw(dateFormatter.string(from: transaction.date)),
            .raw(dateFormatter.string(from: transaction.createdAt)),
            .raw(transaction.type.rawValue),
            .raw(decimalString(transaction.amount)),
            .raw(transaction.currencyCode.uppercased()),
            .raw(conversion.amount),
            .raw(conversion.currency),
            .raw(conversion.rate),
            .text(transaction.account?.displayName ?? ""),
            .text(transaction.category?.displayName ?? ""),
            .text(transaction.notes ?? ""),
            .raw(String(transaction.isTravelTransaction == true)),
            .raw(optionalDecimalString(transaction.travelAmount)),
            .raw(transaction.travelCurrencyCode?.uppercased() ?? ""),
            .raw(optionalDecimalString(transaction.travelExchangeRate)),
            .raw(optionalDateString(transaction.travelExchangeRateEffectiveDate)),
            .text(transaction.travelExchangeRateProvider ?? ""),
            .raw(String(transaction.hasReceipt))
        ]
    }

    private func conversionFields(
        for transaction: Transaction,
        displayCurrencyCode: String
    ) async -> ConversionFields {
        let sourceCurrencyCode = transaction.currencyCode.uppercased()
        if sourceCurrencyCode == displayCurrencyCode {
            return ConversionFields(
                amount: decimalString(transaction.amount),
                currency: displayCurrencyCode,
                rate: "1"
            )
        }

        do {
            let quote = try await quoteProvider.convertWithQuote(
                transaction.amount,
                from: sourceCurrencyCode,
                to: displayCurrencyCode,
                on: transaction.date,
                mode: .historical
            )
            return ConversionFields(
                amount: decimalString(quote.convertedAmount),
                currency: displayCurrencyCode,
                rate: decimalString(quote.rate)
            )
        } catch {
            return .unavailable
        }
    }

    private func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private func optionalDecimalString(_ value: Decimal?) -> String {
        guard let value else { return "" }
        return decimalString(value)
    }

    private func optionalDateString(_ value: Date?) -> String {
        guard let value else { return "" }
        return dateFormatter.string(from: value)
    }
}
