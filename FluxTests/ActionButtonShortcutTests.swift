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
        XCTAssertTrue(source.contains("OpenDailySumControlIntent(target: .open)"))
        XCTAssertTrue(source.contains("OpenDailySumControlIntent(target: .expense)"))
        XCTAssertTrue(source.contains("OpenDailySumControlIntent(target: .income)"))
    }

    func testControlWidgetsUseSharedOpenIntentInsteadOfURLHandoff() throws {
        let source = try sourceContents(at: "DailySumControls/DailySumControls.swift")
        let sharedIntentSource = try sourceContents(at: "SharedAppIntents/DailySumControlIntents.swift")
        let contentViewSource = try sourceContents(at: "Flux/ContentView.swift")

        XCTAssertFalse(source.contains("ControlWidgetButton(action: OpenURLIntent"))
        XCTAssertFalse(source.contains("OpenURLIntent("))
        XCTAssertFalse(source.contains("dailysum://"))
        XCTAssertTrue(sharedIntentSource.contains("struct OpenDailySumControlIntent: AppIntent"))
        XCTAssertTrue(sharedIntentSource.contains("@Parameter(title: \"Action\")"))
        XCTAssertTrue(sharedIntentSource.contains("static let supportedModes: IntentModes = .foreground(.immediate)"))
        XCTAssertTrue(sharedIntentSource.contains("DailySumControlIntentRouter.shared.request(target)"))
        XCTAssertTrue(contentViewSource.contains("@State private var controlIntentRouter = DailySumControlIntentRouter.shared"))
        XCTAssertTrue(contentViewSource.contains("handleControlIntentDestination"))
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

    func testSharedControlIntentIsAvailableToAppAndExtensionTargets() throws {
        let project = try sourceContents(at: "Flux.xcodeproj/project.pbxproj")

        XCTAssertTrue(project.contains("SharedAppIntents"))
        XCTAssertTrue(
            project.contains(
                "\t\t\tfileSystemSynchronizedGroups = (\n" +
                "\t\t\t\tC0DA00042F50000000C0DA04 /* DailySumControls */,\n" +
                "\t\t\t\tC0DA000F2F50000000C0DA0F /* SharedAppIntents */,\n" +
                "\t\t\t);"
            )
        )
        XCTAssertTrue(
            project.contains(
                "\t\t\tfileSystemSynchronizedGroups = (\n" +
                "\t\t\t\tD1473B7F2F39023C00F93BDF /* Flux */,\n" +
                "\t\t\t\tC0DA000F2F50000000C0DA0F /* SharedAppIntents */,\n" +
                "\t\t\t);"
            )
        )
    }

    func testControlWidgetExtensionVersionMatchesContainingApp() throws {
        let project = try sourceContents(at: "Flux.xcodeproj/project.pbxproj")

        XCTAssertEqual(project.components(separatedBy: "CURRENT_PROJECT_VERSION = 58;").count - 1, 4)
        XCTAssertEqual(project.components(separatedBy: "MARKETING_VERSION = 1.9;").count - 1, 4)
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
        let displayName = try XCTUnwrap(strings["CFBundleDisplayName"] as? [String: Any])
        let localizations = try XCTUnwrap(displayName["localizations"] as? [String: Any])

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

    func testSharedControlIntentRouterPublishesIncomeDestination() {
        let router = DailySumControlIntentRouter()

        router.request(.income)

        XCTAssertEqual(router.pendingDestination?.destination, .income)
    }

    func testSharedControlIntentRouterCanClearConsumedDestination() {
        let router = DailySumControlIntentRouter()
        router.request(.expense)

        router.clearPendingDestination()

        XCTAssertNil(router.pendingDestination)
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

    func testNewTransactionResetKeepsRequestedInitialType() throws {
        let source = try sourceContents(at: "Flux/Views/Sheets/TransactionEntrySheet.swift")

        XCTAssertTrue(source.contains("private let initialTransactionType: TransactionType"))
        XCTAssertTrue(source.contains("transactionType = initialTransactionType"))
        XCTAssertFalse(source.contains("func resetFormForNewTransaction() {\n        let now = Date()\n        transactionType = .expense"))
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
