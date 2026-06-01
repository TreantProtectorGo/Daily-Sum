import XCTest

final class ReleaseReadinessTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testInfoPlistDeclaresOnlyExemptEncryptionUsage() throws {
        let plistURL = repositoryRoot.appendingPathComponent("Flux-Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                as? [String: Any]
        )

        XCTAssertEqual(plist["ITSAppUsesNonExemptEncryption"] as? Bool, false)
    }

    func testAppDoesNotLinkToExternalDonationPaymentProvider() throws {
        let settingsViewURL = repositoryRoot.appendingPathComponent("Flux/Views/SettingsView.swift")
        let settingsView = try String(contentsOf: settingsViewURL, encoding: .utf8)

        XCTAssertFalse(settingsView.localizedCaseInsensitiveContains("buymeacoffee"))
        XCTAssertFalse(settingsView.localizedCaseInsensitiveContains("donation"))
    }

    func testVersionOneDoesNotExposeInAppPurchaseTipJar() throws {
        let settingsViewURL = repositoryRoot.appendingPathComponent("Flux/Views/SettingsView.swift")
        let settingsView = try String(contentsOf: settingsViewURL, encoding: .utf8)

        XCTAssertFalse(settingsView.contains("import StoreKit"))
        XCTAssertFalse(settingsView.contains("flux.tip.small"))
        XCTAssertFalse(settingsView.contains("flux.tip.medium"))
        XCTAssertFalse(settingsView.contains("flux.tip.large"))
        XCTAssertFalse(settingsView.contains("SupportFluxSheet"))
        XCTAssertFalse(settingsView.localizedCaseInsensitiveContains("paypal"))
        XCTAssertFalse(settingsView.localizedCaseInsensitiveContains("stripe"))
    }
}
