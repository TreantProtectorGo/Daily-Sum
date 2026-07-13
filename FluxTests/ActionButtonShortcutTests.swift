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

        XCTAssertTrue(
            try synchronizedGroupNames(forTarget: "DailySumControls", in: project)
                .contains("SharedAppIntents")
        )
        XCTAssertTrue(
            try synchronizedGroupNames(forTarget: "Flux", in: project)
                .contains("SharedAppIntents")
        )
    }

    func testControlWidgetExtensionVersionMatchesContainingApp() throws {
        let project = try sourceContents(at: "Flux.xcodeproj/project.pbxproj")

        let appBuildVersions = try buildSettingValues(
            named: "CURRENT_PROJECT_VERSION",
            forTarget: "Flux",
            in: project
        )
        let extensionBuildVersions = try buildSettingValues(
            named: "CURRENT_PROJECT_VERSION",
            forTarget: "DailySumControls",
            in: project
        )
        let appMarketingVersions = try buildSettingValues(
            named: "MARKETING_VERSION",
            forTarget: "Flux",
            in: project
        )
        let extensionMarketingVersions = try buildSettingValues(
            named: "MARKETING_VERSION",
            forTarget: "DailySumControls",
            in: project
        )

        XCTAssertFalse(appBuildVersions.isEmpty)
        XCTAssertFalse(appMarketingVersions.isEmpty)
        XCTAssertEqual(Set(appBuildVersions), Set(extensionBuildVersions))
        XCTAssertEqual(Set(appMarketingVersions), Set(extensionMarketingVersions))
    }

    func testShortcutCopyUsesDailySumBranding() throws {
        let source = try sourceContents(at: "Flux/AppShortcuts/FluxAppShortcuts.swift")

        XCTAssertTrue(source.contains("\"Open Daily Sum\""))
        XCTAssertFalse(source.contains("\"Open Flux\""))
        XCTAssertFalse(source.contains("Open Flux and"))
    }

    func testShortcutIntentsUseSameFastForegroundRouterAsControls() throws {
        let source = try sourceContents(at: "Flux/AppShortcuts/FluxAppShortcuts.swift")

        XCTAssertFalse(source.contains("ActionButtonShortcutRouter.shared.requestTransactionEntry"))
        XCTAssertTrue(source.contains("DailySumControlIntentRouter.shared.request(.expense)"))
        XCTAssertTrue(source.contains("DailySumControlIntentRouter.shared.request(.income)"))
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

    private func synchronizedGroupNames(
        forTarget targetName: String,
        in project: String
    ) throws -> Set<String> {
        let escapedTarget = NSRegularExpression.escapedPattern(for: targetName)
        let targetPattern = "(?s)[A-F0-9]+ /\\* \(escapedTarget) \\*/ = \\{.*?isa\\s*=\\s*PBXNativeTarget;.*?\\n\\s*\\};"
        let targetExpression = try NSRegularExpression(pattern: targetPattern)
        let projectRange = NSRange(project.startIndex..<project.endIndex, in: project)
        let targetMatch = try XCTUnwrap(targetExpression.firstMatch(in: project, range: projectRange))
        let targetBlockRange = try XCTUnwrap(Range(targetMatch.range, in: project))
        let targetBlock = String(project[targetBlockRange])

        let groupsPattern = "(?s)fileSystemSynchronizedGroups\\s*=\\s*\\((.*?)\\);"
        let groupsExpression = try NSRegularExpression(pattern: groupsPattern)
        let targetRange = NSRange(targetBlock.startIndex..<targetBlock.endIndex, in: targetBlock)
        let groupsMatch = try XCTUnwrap(
            groupsExpression.firstMatch(in: targetBlock, range: targetRange)
        )
        let namesRange = try XCTUnwrap(Range(groupsMatch.range(at: 1), in: targetBlock))
        let namesSource = String(targetBlock[namesRange])
        let nameExpression = try NSRegularExpression(pattern: "/\\*\\s*(.*?)\\s*\\*/")
        let sourceRange = NSRange(namesSource.startIndex..<namesSource.endIndex, in: namesSource)

        return Set(nameExpression.matches(in: namesSource, range: sourceRange).compactMap { match in
            guard let range = Range(match.range(at: 1), in: namesSource) else { return nil }
            return String(namesSource[range])
        })
    }

    private func buildSettingValues(
        named name: String,
        forTarget targetName: String,
        in project: String
    ) throws -> [String] {
        let escapedTarget = NSRegularExpression.escapedPattern(for: targetName)
        let configurationListExpression = try NSRegularExpression(
            pattern: "(?s)[A-F0-9]+ /\\* Build configuration list for PBXNativeTarget \"\(escapedTarget)\" \\*/ = \\{.*?buildConfigurations\\s*=\\s*\\((.*?)\\);"
        )
        let projectRange = NSRange(project.startIndex..<project.endIndex, in: project)
        let listMatch = try XCTUnwrap(
            configurationListExpression.firstMatch(in: project, range: projectRange)
        )
        let identifiersRange = try XCTUnwrap(Range(listMatch.range(at: 1), in: project))
        let identifiersSource = String(project[identifiersRange])
        let identifierExpression = try NSRegularExpression(pattern: "([A-F0-9]+)\\s*/\\*")
        let sourceRange = NSRange(
            identifiersSource.startIndex..<identifiersSource.endIndex,
            in: identifiersSource
        )
        let identifiers = identifierExpression.matches(
            in: identifiersSource,
            range: sourceRange
        ).compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: identifiersSource) else { return nil }
            return String(identifiersSource[range])
        }

        let escapedName = NSRegularExpression.escapedPattern(for: name)
        return try identifiers.compactMap { identifier in
            let escapedIdentifier = NSRegularExpression.escapedPattern(for: identifier)
            let configurationExpression = try NSRegularExpression(
                pattern: "(?s)\(escapedIdentifier) /\\* .*? \\*/ = \\{.*?buildSettings\\s*=\\s*\\{(.*?)\\};"
            )
            guard let configurationMatch = configurationExpression.firstMatch(
                in: project,
                range: projectRange
            ), let settingsRange = Range(configurationMatch.range(at: 1), in: project) else {
                return nil
            }
            let settings = String(project[settingsRange])
            let settingExpression = try NSRegularExpression(
                pattern: "\\b\(escapedName)\\s*=\\s*([^;]+);"
            )
            let settingsNSRange = NSRange(settings.startIndex..<settings.endIndex, in: settings)
            guard let settingMatch = settingExpression.firstMatch(
                in: settings,
                range: settingsNSRange
            ), let valueRange = Range(settingMatch.range(at: 1), in: settings) else {
                return nil
            }
            return settings[valueRange].trimmingCharacters(in: .whitespacesAndNewlines)
        }
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
