import XCTest
@testable import Flux

@MainActor
final class ActionButtonShortcutTests: XCTestCase {
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
