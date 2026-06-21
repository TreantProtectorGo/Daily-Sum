import XCTest
import SwiftData
@testable import Flux

@MainActor
final class SettingsViewModelCSVExportTests: XCTestCase {
    private final class MockCSVExportService: TransactionCSVExportServicing {
        var result: Result<URL, Error>
        var suspends = false
        private(set) var callCount = 0
        private(set) var displayCurrencyCodes: [String] = []
        private var continuation: CheckedContinuation<Result<URL, Error>, Never>?

        init(result: Result<URL, Error>) {
            self.result = result
        }

        func exportTransactions(displayCurrencyCode: String) async throws -> URL {
            callCount += 1
            displayCurrencyCodes.append(displayCurrencyCode)
            if suspends {
                let resumedResult = await withCheckedContinuation { continuation in
                    self.continuation = continuation
                }
                return try resumedResult.get()
            }
            return try result.get()
        }

        func resume() {
            continuation?.resume(returning: result)
            continuation = nil
        }
    }

    func testExportTransactionsCSVPublishesSuccessState() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let expectedURL = URL(fileURLWithPath: "/tmp/Flux_Transactions_2024-01-03.csv")
        let service = MockCSVExportService(result: .success(expectedURL))
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            transactionCSVExportService: service
        )
        viewModel.defaultCurrencyCode = "HKD"

        let result = await viewModel.exportTransactionsCSV()

        XCTAssertEqual(result, expectedURL)
        XCTAssertFalse(viewModel.isExportingTransactionsCSV)
        XCTAssertNil(viewModel.transactionCSVExportErrorMessage)
        XCTAssertEqual(service.displayCurrencyCodes, ["HKD"])
    }

    func testExportTransactionsCSVPublishesLocalizedFailureState() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let service = MockCSVExportService(
            result: .failure(NSError(domain: "CSV", code: 1))
        )
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            transactionCSVExportService: service
        )

        let result = await viewModel.exportTransactionsCSV()

        XCTAssertNil(result)
        XCTAssertFalse(viewModel.isExportingTransactionsCSV)
        XCTAssertEqual(
            viewModel.transactionCSVExportErrorMessage,
            AppLocalization.string(
                "settings.csvExport.error",
                defaultValue: "Unable to export transactions. Please try again."
            )
        )
    }

    func testExportTransactionsCSVIgnoresDuplicateRequestWhileRunning() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let expectedURL = URL(fileURLWithPath: "/tmp/Flux_Transactions_2024-01-03.csv")
        let service = MockCSVExportService(result: .success(expectedURL))
        service.suspends = true
        let viewModel = SettingsViewModel(
            modelContext: container.mainContext,
            transactionCSVExportService: service
        )

        let firstRequest = Task { await viewModel.exportTransactionsCSV() }
        while service.callCount == 0 {
            await Task.yield()
        }

        let duplicateResult = await viewModel.exportTransactionsCSV()

        XCTAssertNil(duplicateResult)
        XCTAssertEqual(service.callCount, 1)
        service.resume()
        let firstResult = await firstRequest.value
        XCTAssertEqual(firstResult, expectedURL)
        XCTAssertFalse(viewModel.isExportingTransactionsCSV)
    }
}
