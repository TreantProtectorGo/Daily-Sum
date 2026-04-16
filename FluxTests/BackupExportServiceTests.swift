import XCTest
import SwiftData
@testable import Flux

@MainActor
final class BackupExportServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var originalCurrencyCode: String!
    private var originalAppLanguage: AppLanguage!
    private var originalTravelSource: TravelCurrencySource!
    private var originalDetectedTravelCurrencyCode: String?
    private var originalManualTravelCurrencyCode: String?
    private var originalDefaultAccountId: UUID?
    private var originalRememberLastUsedAccount: Bool!
    private var originalLastUsedAccountId: UUID?
    private var originalAutoPresentAccountAfterCategorySelection: Bool!
    private var originalReportsCategoryRowLimit: Int!

    override func setUp() async throws {
        container = try ModelContainerConfiguration.createTestContainer()
        context = container.mainContext

        originalCurrencyCode = UserCurrencyPreference.currencyCode
        originalAppLanguage = AppLanguagePreference.language
        originalTravelSource = TravelCurrencyPreference.source
        originalDetectedTravelCurrencyCode = TravelCurrencyPreference.detectedCurrencyCode
        originalManualTravelCurrencyCode = TravelCurrencyPreference.manualCurrencyCode
        originalDefaultAccountId = TransactionAccountPreference.defaultAccountId
        originalRememberLastUsedAccount = TransactionAccountPreference.rememberLastUsedAccount
        originalLastUsedAccountId = TransactionAccountPreference.lastUsedAccountId
        originalAutoPresentAccountAfterCategorySelection =
            TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection
        originalReportsCategoryRowLimit = ReportsCategoryRowLimitPreference.rowLimit
    }

    override func tearDown() async throws {
        UserCurrencyPreference.currencyCode = originalCurrencyCode
        AppLanguagePreference.language = originalAppLanguage
        TravelCurrencyPreference.source = originalTravelSource
        TravelCurrencyPreference.detectedCurrencyCode = originalDetectedTravelCurrencyCode
        TravelCurrencyPreference.manualCurrencyCode = originalManualTravelCurrencyCode
        TransactionAccountPreference.defaultAccountId = originalDefaultAccountId
        TransactionAccountPreference.rememberLastUsedAccount = originalRememberLastUsedAccount
        TransactionAccountPreference.lastUsedAccountId = originalLastUsedAccountId
        TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection =
            originalAutoPresentAccountAfterCategorySelection
        ReportsCategoryRowLimitPreference.rowLimit = originalReportsCategoryRowLimit

        container = nil
        context = nil
    }

    func testBackupExportServiceAssemblesArchiveFromSwiftDataAndPreferences() throws {
        try seedExportFixtures()
        seedExportPreferences()

        let service = BackupExportService(context: context)
        let archive = try service.makeBackupArchive()

        XCTAssertEqual(archive.schemaVersion, BackupArchive.currentSchemaVersion)
        XCTAssertEqual(archive.financialData.currencies.count, 1)
        XCTAssertEqual(archive.financialData.exchangeRates.count, 1)
        XCTAssertEqual(archive.financialData.categories.count, 1)
        XCTAssertEqual(archive.financialData.accounts.count, 1)
        XCTAssertEqual(archive.financialData.transactions.count, 1)
        XCTAssertEqual(archive.financialData.scheduledOccurrenceExceptions.count, 1)
        XCTAssertEqual(archive.financialData.budgets.count, 1)
        let expectedLanguage: AppLanguage = .traditionalChinese
        let expectedTravelSource: TravelCurrencySource = .manual

        XCTAssertEqual(archive.preferences.crossDevice.appLanguage, expectedLanguage)
        XCTAssertEqual(archive.preferences.crossDevice.travelCurrencySource, expectedTravelSource)
        XCTAssertEqual(archive.preferences.deviceLocal.defaultTransactionAccountId, seedAccountID)
        XCTAssertEqual(archive.integrityMetadata.recordCounts.accounts, 1)
        XCTAssertEqual(archive.integrityMetadata.recordCounts.transactions, 1)
        XCTAssertTrue(archive.integrityMetadata.contentHash.hasPrefix("sha256:"))
    }

    func testBackupExportServiceProducesDeterministicOrderingAndCountsForSameData() throws {
        try seedExportFixtures()
        seedExportPreferences()

        let service = BackupExportService(context: context)

        let first = try service.makeBackupArchive()
        let second = try service.makeBackupArchive()

        XCTAssertEqual(first.integrityMetadata.recordCounts, second.integrityMetadata.recordCounts)
        XCTAssertEqual(
            first.financialData.transactions.map { $0.id },
            second.financialData.transactions.map { $0.id }
        )
    }

    func testBackupExportServiceDeduplicatesExchangeRatesByNaturalKey() throws {
        let effectiveDate = Date(timeIntervalSince1970: 1_700_000_200)
        let olderExchangeRate = ExchangeRate(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            baseCurrencyCode: "USD",
            quoteCurrencyCode: "HKD",
            rate: 7.8,
            effectiveDate: effectiveDate,
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_300),
            provider: "older"
        )
        let newerExchangeRate = ExchangeRate(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            baseCurrencyCode: "USD",
            quoteCurrencyCode: "HKD",
            rate: 7.81,
            effectiveDate: effectiveDate,
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_400),
            provider: "newer"
        )
        context.insert(olderExchangeRate)
        context.insert(newerExchangeRate)
        try context.save()

        let service = BackupExportService(context: context)
        let archive = try service.makeBackupArchive()

        XCTAssertEqual(archive.financialData.exchangeRates.count, 1)
        XCTAssertEqual(archive.financialData.exchangeRates.first?.provider, "newer")
        XCTAssertEqual(archive.financialData.exchangeRates.first?.rate, 7.81)
        XCTAssertEqual(archive.integrityMetadata.recordCounts.exchangeRates, 1)
    }

    private var seedAccountID: UUID {
        UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    }

    private func seedExportPreferences() {
        UserCurrencyPreference.currencyCode = "USD"
        let preferredLanguage: AppLanguage = .traditionalChinese
        let preferredTravelSource: TravelCurrencySource = .manual

        AppLanguagePreference.language = preferredLanguage
        TravelCurrencyPreference.source = preferredTravelSource
        TravelCurrencyPreference.detectedCurrencyCode = "HKD"
        TravelCurrencyPreference.manualCurrencyCode = "JPY"
        TransactionAccountPreference.defaultAccountId = seedAccountID
        TransactionAccountPreference.rememberLastUsedAccount = true
        TransactionAccountPreference.lastUsedAccountId = seedAccountID
        TransactionEntryFlowPreference.autoPresentAccountAfterCategorySelection = true
        ReportsCategoryRowLimitPreference.rowLimit = 8
    }

    private func seedExportFixtures() throws {
        let currency = Currency(
            code: "USD",
            exchangeRateToBase: 1,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_100),
            isBaseCurrency: true
        )
        let exchangeRate = ExchangeRate(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            baseCurrencyCode: "USD",
            quoteCurrencyCode: "HKD",
            rate: 7.8,
            effectiveDate: Date(timeIntervalSince1970: 1_700_000_200),
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_300),
            provider: "mock"
        )
        let category = Category(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            nameKey: "Food",
            icon: "fork.knife",
            colorHex: "#FF0000",
            type: .expense,
            isSystemDefault: false
        )
        let account = Account(
            id: seedAccountID,
            name: "Cash Wallet",
            type: .cash,
            currencyCode: "USD",
            initialBalance: 500,
            icon: "banknote",
            colorHex: "#007AFF",
            includeInTotal: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_400)
        )
        let transaction = Transaction(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            amount: 25.5,
            currencyCode: "USD",
            type: .expense,
            date: Date(timeIntervalSince1970: 1_700_000_500),
            notes: "Lunch",
            receiptImageData: Data([0x01, 0x02]),
            recurrenceRule: .monthly,
            schedulePlanType: .recurring,
            dueDayOfMonth: 15,
            reminderLeadDays: 3,
            account: account,
            category: category
        )
        let exception = ScheduledOccurrenceException(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            templateId: transaction.id,
            occurrenceDate: Date(timeIntervalSince1970: 1_700_000_600),
            createdAt: Date(timeIntervalSince1970: 1_700_000_700)
        )
        let budget = Budget(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            limitAmount: 1000,
            currencyCode: "USD",
            period: .monthly,
            alertThreshold: 0.8,
            alertsEnabled: true,
            alertTrackingPeriodStart: Date(timeIntervalSince1970: 1_700_000_800),
            hasSentWarningAlertInTrackedPeriod: false,
            hasSentExceededAlertInTrackedPeriod: false,
            createdAt: Date(timeIntervalSince1970: 1_700_000_900),
            isActive: true,
            category: category
        )

        context.insert(currency)
        context.insert(exchangeRate)
        context.insert(category)
        context.insert(account)
        context.insert(transaction)
        context.insert(exception)
        context.insert(budget)
        try context.save()
    }
}
