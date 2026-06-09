import XCTest

final class AppStoreScreenshotTests: XCTestCase {
    private struct ScreenshotLocale {
        let appleLanguages: String
        let appleLocale: String
        let appLanguageCode: String
        let navigationTitles: [String]

        static let english = ScreenshotLocale(
            appleLanguages: "(en)",
            appleLocale: "en_US",
            appLanguageCode: "english",
            navigationTitles: ["Dashboard", "Transactions", "Reports", "Budgets", "Settings"]
        )

        static let simplifiedChinese = ScreenshotLocale(
            appleLanguages: "(zh-Hans)",
            appleLocale: "zh_CN",
            appLanguageCode: "simplifiedChinese",
            navigationTitles: ["仪表板", "交易", "报告", "预算", "设置"]
        )

        static let traditionalChinese = ScreenshotLocale(
            appleLanguages: "(zh-Hant)",
            appleLocale: "zh_HK",
            appLanguageCode: "traditionalChinese",
            navigationTitles: ["儀表板", "交易", "報告", "預算", "設定"]
        )
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureEnglishAppStoreScreenshots() throws {
        try captureAppStoreScreenshots(locale: .english)
    }

    @MainActor
    func testCaptureSimplifiedChineseAppStoreScreenshots() throws {
        try captureAppStoreScreenshots(locale: .simplifiedChinese)
    }

    @MainActor
    func testCaptureTraditionalChineseAppStoreScreenshots() throws {
        try captureAppStoreScreenshots(locale: .traditionalChinese)
    }

    @MainActor
    private func captureAppStoreScreenshots(locale: ScreenshotLocale) throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", locale.appleLanguages,
            "-AppleLocale", locale.appleLocale,
            "-flux.appLanguageCode", locale.appLanguageCode,
            "-flux.appThemeCode", "light",
            "-FluxSkipNotificationAuthorizationOnLaunch"
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars[locale.navigationTitles[0]].waitForExistence(timeout: 15))
        capture("01-dashboard")

        tapTab(app, title: locale.navigationTitles[1])
        XCTAssertTrue(app.navigationBars[locale.navigationTitles[1]].waitForExistence(timeout: 10))
        capture("02-transactions")

        tapTab(app, title: locale.navigationTitles[2])
        XCTAssertTrue(app.navigationBars[locale.navigationTitles[2]].waitForExistence(timeout: 10))
        capture("03-reports")

        tapTab(app, title: locale.navigationTitles[3])
        XCTAssertTrue(app.navigationBars[locale.navigationTitles[3]].waitForExistence(timeout: 10))
        capture("04-budgets")

        tapTab(app, title: locale.navigationTitles[0])
        XCTAssertTrue(app.navigationBars[locale.navigationTitles[0]].waitForExistence(timeout: 10))
        tap(app.navigationBars.buttons.firstMatch)
        XCTAssertTrue(app.navigationBars[locale.navigationTitles[4]].waitForExistence(timeout: 10))
        capture("05-settings")
    }

    @MainActor
    private func capture(_ name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func tap(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), file: file, line: line)
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    @MainActor
    private func tapTab(
        _ app: XCUIApplication,
        title: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let tab = app.tabBars.buttons[title]
        tap(tab, file: file, line: line)
    }
}
