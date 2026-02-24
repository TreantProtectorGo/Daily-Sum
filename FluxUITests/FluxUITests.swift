//
//  FluxUITests.swift
//  FluxUITests
//
//  Created by Wing - on 9/2/2026.
//

import XCTest

final class FluxUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testCategoryPickerOpensFromTrigger() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        app.tabBars.buttons["Transactions"].tap()
        app.buttons["transactions.addButton"].tap()

        let pickerButtons = app.buttons.matching(identifier: "transaction.categoryPicker.trigger")
        XCTAssertGreaterThan(pickerButtons.count, 0)

        let categoryPicker = pickerButtons.allElementsBoundByIndex.first(where: \.isHittable) ?? pickerButtons.firstMatch
        XCTAssertTrue(categoryPicker.waitForExistence(timeout: 2))
        XCTAssertTrue(categoryPicker.isHittable)
        categoryPicker.tap()

        let pickerSheet = app.descendants(matching: .any)["transaction.categoryPicker.sheet"]
        if !pickerSheet.waitForExistence(timeout: 1) {
            categoryPicker.tap()
        }
        XCTAssertTrue(pickerSheet.waitForExistence(timeout: 10))
    }

    @MainActor
    func testSettingsDoesNotPersistWhenSwitchingTabs() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let settingsButton = app.navigationBars.buttons["Settings"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
        settingsButton.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Transactions"].tap()

        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 2))
        dashboardTab.tap()

        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.navigationBars["Settings"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
