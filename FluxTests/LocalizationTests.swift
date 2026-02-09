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
}
