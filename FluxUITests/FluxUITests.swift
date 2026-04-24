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

        let typeControl = app.segmentedControls["transaction.type.mode"]
        XCTAssertTrue(typeControl.waitForExistence(timeout: 10))

        let confirmButton = keypadButton(in: app, label: "Confirm")
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))
        confirmButton.tap()

        let categoryPicker = app.buttons["transaction.categoryPicker.trigger"].firstMatch
        XCTAssertTrue(categoryPicker.waitForExistence(timeout: 10))
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
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))

        app.tabBars.buttons["Transactions"].tap()

        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 2))
        dashboardTab.tap()

        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.navigationBars["Settings"].exists)
    }

    @MainActor
    func testSettingsShowsCloudSyncAndBackupRestoreControls() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let settingsButton = app.navigationBars.buttons["Settings"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(scrollToElement(app.staticTexts["Enable iCloud Sync"], in: app))
        XCTAssertFalse(app.images["settings.backup.icon"].exists)
        XCTAssertTrue(scrollToElement(app.buttons["Back Up Now"], in: app))
        XCTAssertTrue(scrollToElement(app.staticTexts["Restore Mode"], in: app))
        XCTAssertTrue(scrollToElement(app.staticTexts["Restore Scope"], in: app))
        XCTAssertTrue(scrollToElement(app.buttons["Restore from Backup"], in: app))
    }

    @MainActor
    func testSettingsShowsDisabledCloudSyncToggleWhenICloudSignInIsRequired() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-FluxCloudSyncAvailability", "noAccount"
        ]
        app.launch()

        let settingsButton = app.navigationBars.buttons["Settings"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            scrollToElement(
                app.staticTexts["Sign in to iCloud in Settings, then return here to enable sync."],
                in: app
            )
        )

        let toggle = app.switches["settings.cloudSync.toggle"].firstMatch
        XCTAssertTrue(scrollToElement(toggle, in: app))
        XCTAssertFalse(toggle.isEnabled)
        XCTAssertFalse(app.staticTexts["Needs Attention"].firstMatch.exists)
    }

    @MainActor
    func testTransactionAmountKeypadCommitsExpressionResult() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        app.tabBars.buttons["Transactions"].tap()
        app.buttons["transactions.addButton"].tap()

        let confirmButton = keypadButton(in: app, label: "Confirm")
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))

        keypadButton(in: app, label: "1").tap()
        keypadButton(in: app, label: "2").tap()
        keypadButton(in: app, label: "Add").tap()
        keypadButton(in: app, label: "3").tap()
        keypadButton(in: app, label: "Multiply").tap()
        keypadButton(in: app, label: "4").tap()
        confirmButton.tap()

        let amountTrigger = app.buttons["amountInput.trigger"]
        XCTAssertTrue(amountTrigger.waitForExistence(timeout: 2))
        XCTAssertEqual(amountTrigger.value as? String, "24")
    }

    @MainActor
    func testIncomeCategoryPersistsWhenReopeningTransaction() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        app.tabBars.buttons["Transactions"].tap()
        app.buttons["transactions.addButton"].tap()

        let typeControl = app.segmentedControls["transaction.type.mode"]
        XCTAssertTrue(typeControl.waitForExistence(timeout: 10))

        let confirmButton = keypadButton(in: app, label: "Confirm")
        if !confirmButton.waitForExistence(timeout: 3) {
            let amountTrigger = app.buttons["amountInput.trigger"]
            XCTAssertTrue(amountTrigger.waitForExistence(timeout: 10))
            XCTAssertTrue(amountTrigger.isHittable)
            amountTrigger.tap()
        }
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))
        keypadButton(in: app, label: "1").tap()
        keypadButton(in: app, label: "2").tap()
        confirmButton.tap()

        typeControl.buttons["Income"].tap()

        let categoryPicker = app.buttons.matching(identifier: "transaction.categoryPicker.trigger").firstMatch
        XCTAssertTrue(categoryPicker.waitForExistence(timeout: 2))
        categoryPicker.tap()

        let pickerSheet = app.descendants(matching: .any)["transaction.categoryPicker.sheet"]
        XCTAssertTrue(pickerSheet.waitForExistence(timeout: 10))

        let salaryButton = app.buttons["Salary"].firstMatch
        XCTAssertTrue(salaryButton.waitForExistence(timeout: 2))
        salaryButton.tap()

        let saveButton = app.navigationBars.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        let salaryRow = app.staticTexts["Salary"].firstMatch
        XCTAssertTrue(salaryRow.waitForExistence(timeout: 10))
        salaryRow.tap()

        let reopenedCategoryPicker = app.buttons["transaction.categoryPicker.trigger"].firstMatch
        XCTAssertTrue(reopenedCategoryPicker.waitForExistence(timeout: 2))
        XCTAssertTrue(reopenedCategoryPicker.label.contains("Salary"))
    }

    private func keypadButton(in app: XCUIApplication, label: String) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label == %@",
                "numberPad.",
                label
            )
        ).firstMatch
    }

    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        if element.waitForExistence(timeout: 1) {
            return true
        }

        for _ in 0..<6 {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        return false
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
