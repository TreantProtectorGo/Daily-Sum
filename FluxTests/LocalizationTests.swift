import XCTest
import SwiftUI
@testable import Flux

final class LocalizationTests: XCTestCase {
    
    // MARK: - Regional Settings Tests
    
    func testRegionDetection() {
        // US locale
        let usLocale = Locale(identifier: "en_US")
        let usRegion = RegionalSettings.Region.fromLocale(usLocale)
        XCTAssertEqual(usRegion, .unitedStates)
        
        // Taiwan locale
        let twLocale = Locale(identifier: "zh_TW")
        let twRegion = RegionalSettings.Region.fromLocale(twLocale)
        XCTAssertEqual(twRegion, .taiwan)
        
        // China locale
        let cnLocale = Locale(identifier: "zh_CN")
        let cnRegion = RegionalSettings.Region.fromLocale(cnLocale)
        XCTAssertEqual(cnRegion, .china)
    }
    
    func testGainLossColorsAreFixed() {
        XCTAssertEqual(RegionalSettings.shared.gainColor, .green)
        XCTAssertEqual(RegionalSettings.shared.lossColor, .red)
    }

    func testDefaultCurrencyForRegion() {
        XCTAssertEqual(RegionalSettings.Region.unitedStates.defaultCurrency, .USD)
        XCTAssertEqual(RegionalSettings.Region.taiwan.defaultCurrency, .TWD)
        XCTAssertEqual(RegionalSettings.Region.china.defaultCurrency, .CNY)
    }
    
    // MARK: - Enum Localization Tests
    
    func testTransactionTypeLocalization() {
        // Just verify strings are not empty
        XCTAssertFalse(TransactionType.income.localizedName.isEmpty)
        XCTAssertFalse(TransactionType.expense.localizedName.isEmpty)
    }
    
    func testAccountTypeLocalization() {
        for type in AccountType.allCases {
            XCTAssertFalse(type.localizedName.isEmpty, "\(type) should have localized name")
            XCTAssertFalse(type.defaultIcon.isEmpty, "\(type) should have default icon")
        }
    }
    
    func testSupportedCurrencyLocalization() {
        for currency in SupportedCurrency.allCases {
            XCTAssertFalse(currency.localizedName.isEmpty, "\(currency) should have localized name")
            XCTAssertFalse(currency.symbol.isEmpty, "\(currency) should have symbol")
        }
    }
    
    // MARK: - Currency Default Tests
    
    func testDefaultCurrencyFromLocale() {
        // This tests the static property - actual behavior depends on device locale
        let defaultCurrency = SupportedCurrency.defaultFromLocale
        XCTAssertTrue(SupportedCurrency.allCases.contains(defaultCurrency))
    }

    // MARK: - App Language Tests

    func testAppLanguageLocaleIdentifierMapping() {
        XCTAssertNil(AppLanguage.system.localeIdentifier)
        XCTAssertEqual(AppLanguage.english.localeIdentifier, "en")
        XCTAssertEqual(AppLanguage.simplifiedChinese.localeIdentifier, "zh-Hans")
        XCTAssertEqual(AppLanguage.traditionalChinese.localeIdentifier, "zh-Hant")
    }

    func testAppLanguageFallbackToSystemForInvalidRawValue() {
        XCTAssertEqual(AppLanguage.from(rawValue: nil), .system)
        XCTAssertEqual(AppLanguage.from(rawValue: "invalid"), .system)
    }

    func testLocalizedValuesFollowSelectedAppLanguage() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        AppLanguagePreference.language = .english
        XCTAssertEqual(TransactionType.income.localizedName, "Income")
        XCTAssertEqual(SupportedCurrency.USD.localizedName, "US Dollar")

        AppLanguagePreference.language = .simplifiedChinese
        XCTAssertEqual(TransactionType.income.localizedName, "收入")
        XCTAssertEqual(SupportedCurrency.USD.localizedName, "美元")
    }

    func testLegacySystemCategoryNameIsLocalizedInEnglishMode() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        AppLanguagePreference.language = .english

        let legacyCategory = Category(
            nameKey: "外食",
            icon: "cup.and.saucer.fill",
            colorHex: "#F8B500",
            type: .expense,
            isSystemDefault: true
        )

        XCTAssertEqual(legacyCategory.displayName, "Dining Out")
    }

    func testReportMonthFormattingFollowsSelectedAppLanguage() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        let date = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 1, day: 15)
        )!

        AppLanguagePreference.language = .english
        let englishLabel = DateFormatterUtility.shared.formatReportMonth(date)

        AppLanguagePreference.language = .simplifiedChinese
        let simplifiedChineseLabel = DateFormatterUtility.shared.formatReportMonth(date)

        XCTAssertNotEqual(englishLabel, simplifiedChineseLabel)
        XCTAssertEqual(
            englishLabel,
            date.formatted(.dateTime.month(.abbreviated).year().locale(Locale(identifier: "en")))
        )
        XCTAssertEqual(
            simplifiedChineseLabel,
            date.formatted(.dateTime.month(.abbreviated).year().locale(Locale(identifier: "zh-Hans")))
        )
    }
}
