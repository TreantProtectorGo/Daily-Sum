import XCTest

final class SettingsViewLayoutTests: XCTestCase {
    func testForeignCurrencyRowsLiveInsideCurrencySection() throws {
        let source = try settingsViewSource()

        XCTAssertFalse(source.contains("exchangeRateSection(viewModel: viewModel)"))
        XCTAssertTrue(source.contains("defaultCurrencyMenu(viewModel: viewModel)"))
        XCTAssertTrue(source.contains("settings.exchangeRate.configuration"))
        XCTAssertTrue(source.contains("settings.exchangeRate.openCalculator"))
    }

    func testOptionsRowsLiveInsideOneOptionsSection() throws {
        let source = try settingsViewSource()

        XCTAssertTrue(source.contains("optionsSection(viewModel: viewModel)"))
        XCTAssertFalse(source.contains("languageSection(viewModel: viewModel)"))
        XCTAssertFalse(source.contains("startupSection(viewModel: viewModel)"))
        XCTAssertFalse(source.contains("remindersSection(viewModel: viewModel)"))
        XCTAssertFalse(source.contains("reportsSection(viewModel: viewModel)"))
        XCTAssertFalse(source.contains("\"settings.defaultLaunchPage.footer\""))

        XCTAssertTrue(source.contains("settings.options"))
        XCTAssertTrue(source.contains("appLanguagePicker(viewModel: viewModel)"))
        XCTAssertTrue(source.contains("defaultLaunchPagePicker(viewModel: viewModel)"))
        XCTAssertTrue(source.contains("allNotificationsToggle(viewModel: viewModel)"))
        XCTAssertTrue(source.contains("categoryRowsPicker(viewModel: viewModel)"))
    }

    private func settingsViewSource() throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Flux")
            .appendingPathComponent("Views")
            .appendingPathComponent("SettingsView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
