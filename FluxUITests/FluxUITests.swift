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
        let app = configuredApp()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testCategoryPickerOpensFromTrigger() throws {
        let app = configuredApp()
        app.launch()

        tapElement(app.tabBars.buttons["Transactions"])
        tapElement(app.buttons["transactions.addButton"])

        let typeControl = app.segmentedControls["transaction.type.mode"]
        XCTAssertTrue(typeControl.waitForExistence(timeout: 10))

        let confirmButton = keypadButton(in: app, label: "Confirm")
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))
        tapElement(confirmButton)

        let categoryPicker = app.buttons["transaction.categoryPicker.trigger"].firstMatch
        XCTAssertTrue(categoryPicker.waitForExistence(timeout: 10))
        tapElement(categoryPicker)

        let pickerSheet = app.descendants(matching: .any)["transaction.categoryPicker.sheet"]
        if !pickerSheet.waitForExistence(timeout: 1) {
            tapElement(categoryPicker)
        }
        XCTAssertTrue(pickerSheet.waitForExistence(timeout: 10))
    }

    @MainActor
    func testSettingsDoesNotPersistWhenSwitchingTabs() throws {
        let app = configuredApp()
        app.launch()

        let settingsButton = app.navigationBars.buttons["Settings"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        tapElement(settingsButton)

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))

        tapElement(app.tabBars.buttons["Transactions"])

        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 2))
        tapElement(dashboardTab)

        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.navigationBars["Settings"].exists)
    }

    @MainActor
    func testSettingsShowsCloudSyncAndBackupRestoreControls() throws {
        let app = configuredApp()
        app.launch()

        let settingsButton = app.navigationBars.buttons["Settings"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        tapElement(settingsButton)

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(scrollToElement(app.staticTexts["Enable iCloud Sync"], in: app))
        XCTAssertFalse(app.images["settings.backup.icon"].exists)
        XCTAssertTrue(scrollToElement(app.staticTexts["Automatic Backup"], in: app))
        XCTAssertTrue(scrollToElement(app.staticTexts["Keep Backups"], in: app))
        XCTAssertTrue(scrollToElement(app.staticTexts["settings.backup.restore.behavior"], in: app))

        let backupButton = app.buttons["settings.backup.sheet.button"]
        XCTAssertTrue(scrollToElement(backupButton, in: app))
        tapElement(backupButton)

        XCTAssertTrue(app.navigationBars["Backup"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["settings.backup.export.button"].waitForExistence(timeout: 10))
        let emptyBackupMessage = app.staticTexts["settings.backup.list.empty.message"]
        let backupRow = app.buttons["settings.backup.list.row"].firstMatch
        XCTAssertTrue(
            emptyBackupMessage.waitForExistence(timeout: 5) || backupRow.waitForExistence(timeout: 5)
        )
        if !backupRow.exists {
            tapElement(app.buttons["settings.backup.export.button"])
            XCTAssertTrue(backupRow.waitForExistence(timeout: 10))
        }
        XCTAssertTrue(app.images["settings.backup.list.row.disclosure"].waitForExistence(timeout: 5))

        tapElement(backupRow)
        XCTAssertTrue(app.alerts["Restore Backup?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.alerts.buttons["Confirm Restore"].exists)
        app.alerts.buttons["Cancel"].tap()

        XCTAssertTrue(app.buttons["settings.backup.close.button"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testSettingsShowsDisabledCloudSyncToggleWhenICloudSignInIsRequired() throws {
        let app = configuredApp([
            "-FluxCloudSyncAvailability", "noAccount"
        ])
        app.launch()

        let settingsButton = app.navigationBars.buttons["Settings"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        tapElement(settingsButton)

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            scrollToElement(
                app.staticTexts["settings.cloudSync.message"],
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
        let app = configuredApp()
        app.launch()

        tapElement(app.tabBars.buttons["Transactions"])
        tapElement(app.buttons["transactions.addButton"])

        let dockedNumberPad = app.descendants(matching: .any)["numberPad.docked"]
        XCTAssertTrue(dockedNumberPad.waitForExistence(timeout: 3))

        dockedNumberPad.swipeDown()
        XCTAssertTrue(dockedNumberPad.waitForNonExistence(timeout: 2))

        let amountTrigger = app.buttons["amountInput.trigger"]
        tapElement(amountTrigger)
        XCTAssertTrue(dockedNumberPad.waitForExistence(timeout: 2))

        let confirmButton = keypadButton(in: app, label: "Confirm")
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))

        tapElement(keypadButton(in: app, label: "1"))
        tapElement(keypadButton(in: app, label: "2"))
        tapElement(app.buttons["numberPad.operation.add"])
        tapElement(keypadButton(in: app, label: "3"))
        tapElement(app.buttons["numberPad.operation.multiply"])
        tapElement(keypadButton(in: app, label: "4"))
        tapElement(confirmButton)

        XCTAssertTrue(amountTrigger.waitForExistence(timeout: 2))
        XCTAssertEqual(amountTrigger.value as? String, "24")
    }

    @MainActor
    func testTravelExpenseAccountPickerShowsDefaultAndTravelCurrencyAccountsOnly() throws {
        let app = configuredApp([
            "-FluxUITestFixture", "travelAccountPicker"
        ])
        app.launch()

        let transactionsTab = app.tabBars.buttons["Transactions"]
        XCTAssertTrue(
            transactionsTab.waitForExistence(timeout: 10),
            "Transactions tab should exist after launching the travel account picker fixture."
        )
        tapElement(transactionsTab)

        let addButton = app.buttons["transactions.addButton"]
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 10),
            "Transaction add button should exist on the Transactions tab."
        )
        tapElement(addButton)

        let accountPicker = app.buttons["transaction.accountPicker.trigger"].firstMatch
        XCTAssertTrue(
            accountPicker.waitForExistence(timeout: 10),
            "Account picker trigger should exist in the Add Expense sheet."
        )
        tapElement(accountPicker)

        let accountSheetTitle = app.navigationBars["Select Account"]
        if !accountSheetTitle.waitForExistence(timeout: 2) {
            tapElement(accountPicker)
        }
        XCTAssertTrue(
            accountSheetTitle.waitForExistence(timeout: 10),
            "Account picker sheet should open from the Add Expense sheet."
        )

        XCTAssertEqual(
            app.buttons.matching(identifier: "transaction.accountPicker.option.11111111-1111-1111-1111-111111111111").count,
            1
        )
        XCTAssertEqual(
            app.buttons.matching(identifier: "transaction.accountPicker.option.22222222-2222-2222-2222-222222222222").count,
            1
        )
        XCTAssertEqual(
            app.buttons.matching(identifier: "transaction.accountPicker.option.44444444-4444-4444-4444-444444444444").count,
            1
        )
        XCTAssertEqual(
            app.buttons.matching(identifier: "transaction.accountPicker.option.33333333-3333-3333-3333-333333333333").count,
            0
        )
    }

    @MainActor
    func testIncomeCategoryPersistsWhenReopeningTransaction() throws {
        let app = configuredApp()
        app.launch()

        tapElement(app.tabBars.buttons["Transactions"])
        tapElement(app.buttons["transactions.addButton"])

        let typeControl = app.segmentedControls["transaction.type.mode"]
        XCTAssertTrue(typeControl.waitForExistence(timeout: 10))
        tapElement(typeControl.buttons["Income"])

        let confirmButton = keypadButton(in: app, label: "Confirm")
        if !confirmButton.waitForExistence(timeout: 3) {
            let amountTrigger = app.buttons["amountInput.trigger"]
            XCTAssertTrue(amountTrigger.waitForExistence(timeout: 10))
            tapElement(amountTrigger)
        }
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))
        tapElement(keypadButton(in: app, label: "1"))
        tapElement(keypadButton(in: app, label: "2"))
        tapElement(confirmButton)

        let pickerSheet = app.descendants(matching: .any)["transaction.categoryPicker.sheet"]
        if !pickerSheet.waitForExistence(timeout: 3) {
            let categoryPicker = app.buttons.matching(identifier: "transaction.categoryPicker.trigger").firstMatch
            XCTAssertTrue(categoryPicker.waitForExistence(timeout: 2))
            tapElement(categoryPicker)
        }
        XCTAssertTrue(pickerSheet.waitForExistence(timeout: 10))

        let salaryButton = app.buttons["Salary"].firstMatch
        XCTAssertTrue(salaryButton.waitForExistence(timeout: 2))
        tapElement(salaryButton)

        let saveButton = app.navigationBars.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        tapElement(saveButton)

        let salaryRow = app.staticTexts["Salary"].firstMatch
        XCTAssertTrue(salaryRow.waitForExistence(timeout: 10))
        tapElement(salaryRow)

        let reopenedCategoryPicker = app.buttons["transaction.categoryPicker.trigger"].firstMatch
        XCTAssertTrue(reopenedCategoryPicker.waitForExistence(timeout: 2))
        XCTAssertTrue(reopenedCategoryPicker.label.contains("Salary"))
    }

    private func configuredApp(_ launchArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-flux.appLanguageCode", "english"
        ]
        app.launchArguments += launchArguments
        return app
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

    private func staticTextCount(in element: XCUIElement, label: String) -> Int {
        element.staticTexts.matching(
            NSPredicate(format: "label == %@", label)
        ).count
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

    private func tapElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), file: file, line: line)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.isHittable {
                element.tap()
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
