import XCTest
import SwiftData
@testable import Flux

@MainActor
final class ExchangeCalculatorViewModelTests: XCTestCase {
    private struct MockConversionError: LocalizedError {
        let errorDescription: String? = "conversion failed"
    }

    private struct MockExchangeRateProvider: ExchangeRateProvider {
        let providerName: String = "mock-rates"
        let snapshot: ExchangeRateSnapshot

        func fetchRates(
            baseCurrencyCode: String,
            quoteCurrencyCodes: [String],
            on date: Date?
        ) async throws -> ExchangeRateSnapshot {
            snapshot
        }
    }

    private final class MockConversionService: CurrencyQuoteProviding {
        var nextResult: Result<CurrencyConversionQuote, Error>
        private(set) var requests: [(amount: Decimal, from: String, to: String)] = []

        init(nextResult: Result<CurrencyConversionQuote, Error>) {
            self.nextResult = nextResult
        }

        func convertWithQuote(
            _ amount: Decimal,
            from sourceCurrencyCode: String,
            to targetCurrencyCode: String,
            on date: Date,
            mode: ConversionMode
        ) async throws -> CurrencyConversionQuote {
            requests.append((amount, sourceCurrencyCode, targetCurrencyCode))
            switch nextResult {
            case .success(let quote):
                return quote
            case .failure(let error):
                throw error
            }
        }
    }

    private final class MockLocationService: TravelCurrencyLocationServicing {
        var authorizationStatusValue: TravelLocationAuthorizationStatus
        var requestAuthorizationResult: TravelLocationAuthorizationStatus
        var detectedCurrency: SupportedCurrency?

        init(
            authorizationStatusValue: TravelLocationAuthorizationStatus,
            requestAuthorizationResult: TravelLocationAuthorizationStatus,
            detectedCurrency: SupportedCurrency?
        ) {
            self.authorizationStatusValue = authorizationStatusValue
            self.requestAuthorizationResult = requestAuthorizationResult
            self.detectedCurrency = detectedCurrency
        }

        func authorizationStatus() -> TravelLocationAuthorizationStatus {
            authorizationStatusValue
        }

        func requestAuthorizationIfNeeded() async -> TravelLocationAuthorizationStatus {
            requestAuthorizationResult
        }

        func detectLocalCurrency() async -> SupportedCurrency? {
            detectedCurrency
        }
    }

    private var container: ModelContainer!
    private var context: ModelContext!
    private var originalLastSuccessfulSyncDate: Date?
    private var originalTravelCurrencySource: TravelCurrencySource?
    private var originalDetectedTravelCurrencyCode: String?
    private var originalManualTravelCurrencyCode: String?

    override func setUp() async throws {
        container = try ModelContainerConfiguration.createTestContainer()
        context = container.mainContext
        originalLastSuccessfulSyncDate = ExchangeRateSyncPreference.lastSuccessfulSyncDate
        originalTravelCurrencySource = TravelCurrencyPreference.source
        originalDetectedTravelCurrencyCode = TravelCurrencyPreference.detectedCurrencyCode
        originalManualTravelCurrencyCode = TravelCurrencyPreference.manualCurrencyCode
        ExchangeRateSyncPreference.lastSuccessfulSyncDate = nil
        TravelCurrencyPreference.source = .automatic
        TravelCurrencyPreference.detectedCurrencyCode = nil
        TravelCurrencyPreference.manualCurrencyCode = nil
    }

    override func tearDown() async throws {
        ExchangeRateSyncPreference.lastSuccessfulSyncDate = originalLastSuccessfulSyncDate
        originalLastSuccessfulSyncDate = nil
        TravelCurrencyPreference.source = originalTravelCurrencySource ?? .automatic
        TravelCurrencyPreference.detectedCurrencyCode = originalDetectedTravelCurrencyCode
        TravelCurrencyPreference.manualCurrencyCode = originalManualTravelCurrencyCode
        originalTravelCurrencySource = nil
        originalDetectedTravelCurrencyCode = nil
        originalManualTravelCurrencyCode = nil
        container = nil
        context = nil
    }

    func testInitializeDefaultsWithoutLocationUsesPreferredAndUSDFallback() async throws {
        let conversionService = MockConversionService(
            nextResult: .success(
                CurrencyConversionQuote(
                    convertedAmount: 12,
                    rate: 1.2,
                    effectiveDate: Date(timeIntervalSince1970: 1_739_571_200),
                    provider: "test-provider"
                )
            )
        )
        let locationService = MockLocationService(
            authorizationStatusValue: .notDetermined,
            requestAuthorizationResult: .notDetermined,
            detectedCurrency: .TWD
        )

        let viewModel = ExchangeCalculatorViewModel(
            modelContext: context,
            conversionService: conversionService,
            locationService: locationService,
            preferredCurrencyCode: "EUR",
            travelCurrencySource: .manual,
            debounceDuration: .milliseconds(1)
        )

        await viewModel.initializeDefaults()

        XCTAssertEqual(viewModel.fromCurrencyCode, "EUR")
        XCTAssertEqual(viewModel.toCurrencyCode, "USD")
    }

    func testInitializeDefaultsUsesDetectedLocalCurrencyWhenAuthorized() async throws {
        let conversionService = MockConversionService(
            nextResult: .success(
                CurrencyConversionQuote(
                    convertedAmount: 100,
                    rate: 100,
                    effectiveDate: Date(timeIntervalSince1970: 1_739_571_200),
                    provider: "test-provider"
                )
            )
        )
        let locationService = MockLocationService(
            authorizationStatusValue: .authorized,
            requestAuthorizationResult: .authorized,
            detectedCurrency: .TWD
        )

        let viewModel = ExchangeCalculatorViewModel(
            modelContext: context,
            conversionService: conversionService,
            locationService: locationService,
            preferredCurrencyCode: "USD",
            travelCurrencySource: .automatic,
            debounceDuration: .milliseconds(1)
        )

        await viewModel.initializeDefaults()

        XCTAssertEqual(viewModel.fromCurrencyCode, "USD")
        XCTAssertEqual(viewModel.toCurrencyCode, "TWD")
    }

    func testInitializeDefaultsFallsBackToUSDWhenLocationUnavailable() async throws {
        let conversionService = MockConversionService(
            nextResult: .success(
                CurrencyConversionQuote(
                    convertedAmount: 10,
                    rate: 10,
                    effectiveDate: Date(timeIntervalSince1970: 1_739_571_200),
                    provider: "test-provider"
                )
            )
        )
        let locationService = MockLocationService(
            authorizationStatusValue: .denied,
            requestAuthorizationResult: .denied,
            detectedCurrency: .TWD
        )

        let viewModel = ExchangeCalculatorViewModel(
            modelContext: context,
            conversionService: conversionService,
            locationService: locationService,
            preferredCurrencyCode: "CNY",
            travelCurrencySource: .automatic,
            debounceDuration: .milliseconds(1)
        )

        await viewModel.initializeDefaults()

        XCTAssertEqual(viewModel.fromCurrencyCode, "CNY")
        XCTAssertEqual(viewModel.toCurrencyCode, "USD")
    }

    func testInitializeDefaultsResolvesSameCurrencyToFirstDifferentSupportedCurrency() async throws {
        let conversionService = MockConversionService(
            nextResult: .success(
                CurrencyConversionQuote(
                    convertedAmount: 10,
                    rate: 10,
                    effectiveDate: Date(timeIntervalSince1970: 1_739_571_200),
                    provider: "test-provider"
                )
            )
        )
        let locationService = MockLocationService(
            authorizationStatusValue: .denied,
            requestAuthorizationResult: .denied,
            detectedCurrency: nil
        )

        let viewModel = ExchangeCalculatorViewModel(
            modelContext: context,
            conversionService: conversionService,
            locationService: locationService,
            preferredCurrencyCode: "USD",
            travelCurrencySource: .manual,
            debounceDuration: .milliseconds(1)
        )

        await viewModel.initializeDefaults()

        let firstDifferent = SupportedCurrency.allCases
            .first(where: { $0.rawValue != "USD" })?.rawValue
        XCTAssertEqual(viewModel.toCurrencyCode, firstDifferent)
    }

    func testAutoCalculationSuccessPublishesQuoteMetadata() async throws {
        let expectedDate = Date(timeIntervalSince1970: 1_739_571_200)
        let conversionService = MockConversionService(
            nextResult: .success(
                CurrencyConversionQuote(
                    convertedAmount: 320,
                    rate: 32,
                    effectiveDate: expectedDate,
                    provider: "mock-provider"
                )
            )
        )
        let locationService = MockLocationService(
            authorizationStatusValue: .denied,
            requestAuthorizationResult: .denied,
            detectedCurrency: nil
        )

        let viewModel = ExchangeCalculatorViewModel(
            modelContext: context,
            conversionService: conversionService,
            locationService: locationService,
            preferredCurrencyCode: "USD",
            travelCurrencySource: .manual,
            debounceDuration: .milliseconds(1)
        )

        await viewModel.initializeDefaults()
        viewModel.amount = 10
        viewModel.fromCurrencyCode = "USD"
        viewModel.toCurrencyCode = "TWD"
        viewModel.scheduleCalculation()

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.convertedAmount, 320)
        XCTAssertEqual(viewModel.exchangeRate, 32)
        XCTAssertEqual(viewModel.effectiveDate, expectedDate)
        XCTAssertEqual(viewModel.provider, "mock-provider")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAutoCalculationFailureKeepsInputsAndShowsError() async throws {
        let conversionService = MockConversionService(
            nextResult: .failure(MockConversionError())
        )
        let locationService = MockLocationService(
            authorizationStatusValue: .denied,
            requestAuthorizationResult: .denied,
            detectedCurrency: nil
        )

        let viewModel = ExchangeCalculatorViewModel(
            modelContext: context,
            conversionService: conversionService,
            locationService: locationService,
            preferredCurrencyCode: "USD",
            travelCurrencySource: .manual,
            debounceDuration: .milliseconds(1)
        )

        await viewModel.initializeDefaults()
        viewModel.amount = 10
        viewModel.fromCurrencyCode = "USD"
        viewModel.toCurrencyCode = "TWD"
        viewModel.scheduleCalculation()

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.amount, 10)
        XCTAssertEqual(viewModel.fromCurrencyCode, "USD")
        XCTAssertEqual(viewModel.toCurrencyCode, "TWD")
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.convertedAmount)
    }

    func testSwapCurrenciesTriggersRecalculation() async throws {
        let conversionService = MockConversionService(
            nextResult: .success(
                CurrencyConversionQuote(
                    convertedAmount: 3.125,
                    rate: 0.03125,
                    effectiveDate: Date(timeIntervalSince1970: 1_739_571_200),
                    provider: "mock-provider"
                )
            )
        )
        let locationService = MockLocationService(
            authorizationStatusValue: .denied,
            requestAuthorizationResult: .denied,
            detectedCurrency: nil
        )

        let viewModel = ExchangeCalculatorViewModel(
            modelContext: context,
            conversionService: conversionService,
            locationService: locationService,
            preferredCurrencyCode: "USD",
            travelCurrencySource: .manual,
            debounceDuration: .milliseconds(1)
        )

        await viewModel.initializeDefaults()
        viewModel.amount = 100
        viewModel.fromCurrencyCode = "TWD"
        viewModel.toCurrencyCode = "USD"
        viewModel.swapCurrencies()

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.fromCurrencyCode, "USD")
        XCTAssertEqual(viewModel.toCurrencyCode, "TWD")
        XCTAssertFalse(conversionService.requests.isEmpty)
    }

    func testRefreshExchangeRatesUpdatesLastSuccessfulSyncDate() async throws {
        let conversionService = MockConversionService(
            nextResult: .success(
                CurrencyConversionQuote(
                    convertedAmount: 100,
                    rate: 1,
                    effectiveDate: Date(timeIntervalSince1970: 1_739_571_200),
                    provider: "mock-provider"
                )
            )
        )
        let locationService = MockLocationService(
            authorizationStatusValue: .denied,
            requestAuthorizationResult: .denied,
            detectedCurrency: nil
        )
        let scheduler = ExchangeRateRefreshScheduler(
            refreshInterval: 60 * 60 * 24,
            provider: MockExchangeRateProvider(
                snapshot: ExchangeRateSnapshot(
                    baseCurrencyCode: "USD",
                    effectiveDate: Date(timeIntervalSince1970: 1_739_571_200),
                    rates: ["HKD": 7.8, "TWD": 31.2],
                    provider: "mock-rates"
                )
            )
        )
        let viewModel = ExchangeCalculatorViewModel(
            modelContext: context,
            conversionService: conversionService,
            locationService: locationService,
            exchangeRateRefreshScheduler: scheduler,
            preferredCurrencyCode: "USD",
            travelCurrencySource: .manual,
            debounceDuration: .milliseconds(1)
        )

        XCTAssertNil(viewModel.lastSuccessfulRateSyncDate)

        await viewModel.refreshExchangeRates(force: true)

        XCTAssertNotNil(viewModel.lastSuccessfulRateSyncDate)
        XCTAssertFalse(viewModel.isRefreshingRates)
        XCTAssertNil(viewModel.errorMessage)
    }
}
