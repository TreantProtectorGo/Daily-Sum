import XCTest
@testable import Flux

@MainActor
final class ActionButtonShortcutTests: XCTestCase {
    func testControlWidgetExtensionDeclaresThreeDailySumControls() throws {
        let sourceURL = repositoryURL.appending(path: "DailySumControls/DailySumControls.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))

        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertEqual(source.components(separatedBy: "StaticControlConfiguration(").count - 1, 3)
        XCTAssertTrue(source.contains("com.dailysum.control.open"))
        XCTAssertTrue(source.contains("com.dailysum.control.expense"))
        XCTAssertTrue(source.contains("com.dailysum.control.income"))
        XCTAssertTrue(source.contains("dailysum://open"))
        XCTAssertTrue(source.contains("dailysum://transaction/expense"))
        XCTAssertTrue(source.contains("dailysum://transaction/income"))
    }

    func testControlWidgetExtensionIsEmbeddedInApp() throws {
        let project = try sourceContents(at: "Flux.xcodeproj/project.pbxproj")
        let infoPlist = try sourceContents(at: "DailySumControls/Info.plist")

        XCTAssertTrue(project.contains("DailySumControls.appex"))
        XCTAssertTrue(project.contains("com.apple.product-type.app-extension"))
        XCTAssertTrue(project.contains("Wing.Flux.DailySumControls"))
        XCTAssertTrue(project.contains("Embed App Extensions"))
        XCTAssertTrue(infoPlist.contains("com.apple.widgetkit-extension"))
    }

    func testControlWidgetExtensionVersionMatchesContainingApp() throws {
        let project = try sourceContents(at: "Flux.xcodeproj/project.pbxproj")

        XCTAssertEqual(project.components(separatedBy: "CURRENT_PROJECT_VERSION = 37;").count - 1, 4)
        XCTAssertEqual(project.components(separatedBy: "MARKETING_VERSION = 1.7;").count - 1, 4)
    }

    func testShortcutCopyUsesDailySumBranding() throws {
        let source = try sourceContents(at: "Flux/AppShortcuts/FluxAppShortcuts.swift")

        XCTAssertTrue(source.contains("\"Open Daily Sum\""))
        XCTAssertFalse(source.contains("\"Open Flux\""))
        XCTAssertFalse(source.contains("Open Flux and"))
    }

    func testBundleNameUsesPublicAppNameAcrossLanguages() throws {
        let data = try Data(contentsOf: repositoryURL.appending(path: "Flux/Resources/InfoPlist.xcstrings"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        let bundleName = try XCTUnwrap(strings["CFBundleName"] as? [String: Any])
        let localizations = try XCTUnwrap(bundleName["localizations"] as? [String: Any])

        XCTAssertEqual(localizedValue(in: localizations, locale: "en"), "Daily Sum")
        XCTAssertEqual(localizedValue(in: localizations, locale: "zh-Hans"), "日常账")
        XCTAssertEqual(localizedValue(in: localizations, locale: "zh-Hant"), "日常帳")
    }

    func testRouterPublishesExpenseRequest() {
        let router = ActionButtonShortcutRouter()

        router.requestTransactionEntry(type: .expense)

        XCTAssertEqual(router.pendingTransactionEntry?.type, .expense)
    }

    func testRouterPublishesIncomeRequest() {
        let router = ActionButtonShortcutRouter()

        router.requestTransactionEntry(type: .income)

        XCTAssertEqual(router.pendingTransactionEntry?.type, .income)
    }

    func testControlURLsResolveToExpectedDestinations() throws {
        XCTAssertEqual(
            ActionButtonShortcutRoute.resolve(try XCTUnwrap(URL(string: "dailysum://open"))),
            .openApp
        )
        XCTAssertEqual(
            ActionButtonShortcutRoute.resolve(try XCTUnwrap(URL(string: "dailysum://transaction/expense"))),
            .transaction(.expense)
        )
        XCTAssertEqual(
            ActionButtonShortcutRoute.resolve(try XCTUnwrap(URL(string: "dailysum://transaction/income"))),
            .transaction(.income)
        )
    }

    func testControlURLRejectsUnknownDestinations() throws {
        XCTAssertNil(
            ActionButtonShortcutRoute.resolve(try XCTUnwrap(URL(string: "dailysum://transaction/transfer")))
        )
        XCTAssertNil(
            ActionButtonShortcutRoute.resolve(try XCTUnwrap(URL(string: "https://transaction/expense")))
        )
    }

    func testRouterHandlesExpenseControlURL() throws {
        let router = ActionButtonShortcutRouter()

        router.handle(try XCTUnwrap(URL(string: "dailysum://transaction/expense")))

        XCTAssertEqual(router.pendingTransactionEntry?.type, .expense)
    }

    func testRepeatedRequestsHaveFreshIdentity() throws {
        let router = ActionButtonShortcutRouter()
        router.requestTransactionEntry(type: .expense)
        let firstID = try XCTUnwrap(router.pendingTransactionEntry?.id)

        router.requestTransactionEntry(type: .expense)
        let secondID = try XCTUnwrap(router.pendingTransactionEntry?.id)

        XCTAssertNotEqual(firstID, secondID)
    }

    func testTransactionEntryDefaultsToExpenseWithoutShortcutRequest() {
        XCTAssertEqual(TransactionEntryInitialType.resolved(nil), .expense)
    }

    func testTransactionEntryUsesShortcutRequestedType() {
        XCTAssertEqual(TransactionEntryInitialType.resolved(.income), .income)
    }

    private var repositoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sourceContents(at relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryURL.appending(path: relativePath),
            encoding: .utf8
        )
    }

    private func localizedValue(
        in localizations: [String: Any],
        locale: String
    ) -> String? {
        let localization = localizations[locale] as? [String: Any]
        let stringUnit = localization?["stringUnit"] as? [String: Any]
        return stringUnit?["value"] as? String
    }
}
