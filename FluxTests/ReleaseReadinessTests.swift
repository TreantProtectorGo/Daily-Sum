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

    func testAppColorTokensDeclareRoleNamespaces() throws {
        let appColorsURL = repositoryRoot.appendingPathComponent("Flux/Theme/AppColors.swift")
        let source = try String(contentsOf: appColorsURL, encoding: .utf8)

        for namespace in ["Brand", "UI", "Finance", "Budget", "Account", "Category"] {
            XCTAssertTrue(source.contains("enum \(namespace)"), "Missing AppColors.\(namespace) namespace.")
        }

        XCTAssertTrue(source.contains("Token rules:"))
        XCTAssertTrue(source.contains("static let selectedNavigation = UI.selectedNavigation"))
        XCTAssertTrue(source.contains("static let sectionAccent = UI.sectionAccent"))
        XCTAssertTrue(source.contains("static let income = Finance.income"))
        XCTAssertTrue(source.contains("static let expense = Finance.expense"))
        XCTAssertTrue(source.contains("static let accountCash = Account.cash"))
        XCTAssertTrue(source.contains("static let budgetSafe = Budget.safe"))
        XCTAssertTrue(source.contains("Budget.progressColor(for: progress)"))
    }

    func testAppSourceUsesNamespacedColorTokensOutsideCompatibilityAliases() throws {
        let legacyTokens = [
            "AppColors.selectedNavigation",
            "AppColors.interactiveText",
            "AppColors.mutedDataIcon",
            "AppColors.sectionAccent",
            "AppColors.primary",
            "AppColors.onPrimary",
            "AppColors.income",
            "AppColors.expense",
            "AppColors.transfer",
            "AppColors.budgetSafe",
            "AppColors.budgetWarning",
            "AppColors.budgetDanger",
            "AppColors.budgetProgressColor",
            "AppColors.accountCash",
            "AppColors.accountBank",
            "AppColors.accountCreditCard",
            "AppColors.accountEWallet",
            "AppColors.accountInvestment",
            "AppColors.accountOther",
            "AppColors.categoryColors",
            "AppColors.glassTint",
            "AppColors.glassBorder"
        ]
        let sourceRoot = repositoryRoot.appendingPathComponent("Flux")
        let appColorsURL = sourceRoot.appendingPathComponent("Theme/AppColors.swift")
        let swiftFiles = try XCTUnwrap(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: nil
            )?.compactMap { $0 as? URL }
                .filter { $0.pathExtension == "swift" && $0 != appColorsURL }
        )

        for fileURL in swiftFiles {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for token in legacyTokens {
                XCTAssertFalse(
                    source.contains(token),
                    "\(fileURL.path) should use the namespaced color token instead of \(token)."
                )
            }
        }
    }
}
