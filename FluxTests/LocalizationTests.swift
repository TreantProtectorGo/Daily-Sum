import XCTest
import SwiftUI
import SwiftData
import UIKit
@testable import Flux

final class LocalizationTests: XCTestCase {
    private let defaultExpenseCategoryKeys = [
        "category.expense.dining",
        "category.expense.coffee",
        "category.expense.groceries",
        "category.expense.transport",
        "category.expense.housing",
        "category.expense.utilities",
        "category.expense.phone",
        "category.expense.home",
        "category.expense.shopping",
        "category.expense.electronics",
        "category.expense.personalCare",
        "category.expense.sports",
        "category.expense.medical",
        "category.expense.entertainment",
        "category.expense.subscriptions",
        "category.expense.learning",
        "category.expense.family",
        "category.expense.travel",
        "category.expense.gifts",
        "category.expense.pet",
        "category.expense.insurance",
        "category.expense.tax",
        "category.expense.miscellaneous"
    ]

    private func expenseCategoryDisplayNames() -> [String] {
        defaultExpenseCategoryKeys.map {
            AppLocalization.string(key: $0, table: "CategoryLocalizations")
        }
    }
    
    // MARK: - Regional Settings Tests
    
    func testRegionDetection() {
        // US locale
        let usLocale = Locale(identifier: "en_US")
        let usRegion = RegionalSettings.Region.fromLocale(usLocale)
        XCTAssertEqual(usRegion, .unitedStates)
        
        // Taiwan locale
        let twLocale = Locale(identifier: "zh_TW")
        let twRegion = RegionalSettings.Region.fromLocale(twLocale)
        XCTAssertEqual(twRegion, .taiwan)
        
        // China locale
        let cnLocale = Locale(identifier: "zh_CN")
        let cnRegion = RegionalSettings.Region.fromLocale(cnLocale)
        XCTAssertEqual(cnRegion, .china)
    }
    
    func testGainLossColorsAreFixed() {
        XCTAssertEqual(RegionalSettings.shared.gainColor, .green)
        XCTAssertEqual(RegionalSettings.shared.lossColor, .red)
    }

    func testDefaultCurrencyForRegion() {
        XCTAssertEqual(RegionalSettings.Region.unitedStates.defaultCurrency, .USD)
        XCTAssertEqual(RegionalSettings.Region.taiwan.defaultCurrency, .TWD)
        XCTAssertEqual(RegionalSettings.Region.china.defaultCurrency, .CNY)
    }
    
    // MARK: - Enum Localization Tests
    
    func testTransactionTypeLocalization() {
        // Just verify strings are not empty
        XCTAssertFalse(TransactionType.income.localizedName.isEmpty)
        XCTAssertFalse(TransactionType.expense.localizedName.isEmpty)
    }

    @MainActor
    func testSFSymbolCatalogSelectableIconsDoNotRenderDuplicates() {
        let renderedSymbols = SFSymbolCatalog.selectable.map(SFSymbolCatalog.filledVariant)

        XCTAssertEqual(
            renderedSymbols.count,
            Set(renderedSymbols).count
        )
    }
    
    func testAccountTypeLocalization() {
        for type in AccountType.allCases {
            XCTAssertFalse(type.localizedName.isEmpty, "\(type) should have localized name")
            XCTAssertFalse(type.defaultIcon.isEmpty, "\(type) should have default icon")
        }
    }
    
    func testSupportedCurrencyLocalization() {
        for currency in SupportedCurrency.allCases {
            XCTAssertFalse(currency.localizedName.isEmpty, "\(currency) should have localized name")
            XCTAssertFalse(currency.symbol.isEmpty, "\(currency) should have symbol")
        }
    }
    
    // MARK: - Currency Default Tests
    
    func testDefaultCurrencyFromLocale() {
        // This tests the static property - actual behavior depends on device locale
        let defaultCurrency = SupportedCurrency.defaultFromLocale
        XCTAssertTrue(SupportedCurrency.allCases.contains(defaultCurrency))
    }

    func testSwissRegionsResolveToSwissFranc() {
        XCTAssertEqual(SupportedCurrency.currency(forRegionCode: "CH"), .CHF)
        XCTAssertEqual(SupportedCurrency.currency(forRegionCode: "LI"), .CHF)
    }

    // MARK: - App Language Tests

    func testAppLanguageLocaleIdentifierMapping() {
        XCTAssertNil(AppLanguage.system.localeIdentifier)
        XCTAssertEqual(AppLanguage.english.localeIdentifier, "en")
        XCTAssertEqual(AppLanguage.simplifiedChinese.localeIdentifier, "zh-Hans")
        XCTAssertEqual(AppLanguage.traditionalChinese.localeIdentifier, "zh-Hant")
    }

    func testAppLanguageFallbackToSystemForInvalidRawValue() {
        XCTAssertEqual(AppLanguage.from(rawValue: nil), .system)
        XCTAssertEqual(AppLanguage.from(rawValue: "invalid"), .system)
    }

    func testAppThemeFallbackToSystemForInvalidRawValue() {
        XCTAssertEqual(AppTheme.from(rawValue: nil), .system)
        XCTAssertEqual(AppTheme.from(rawValue: "invalid"), .system)
    }

    func testAppThemePreferredColorSchemeMapping() {
        XCTAssertNil(AppTheme.system.preferredColorScheme)
        XCTAssertEqual(AppTheme.light.preferredColorScheme, .light)
        XCTAssertEqual(AppTheme.dark.preferredColorScheme, .dark)
    }

    func testLocalizedValuesFollowSelectedAppLanguage() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        AppLanguagePreference.language = .english
        XCTAssertEqual(TransactionType.income.localizedName, "Income")
        XCTAssertEqual(SupportedCurrency.USD.localizedName, "US Dollar")
        XCTAssertEqual(SupportedCurrency.CHF.localizedName, "Swiss Franc")

        AppLanguagePreference.language = .simplifiedChinese
        XCTAssertEqual(TransactionType.income.localizedName, "收入")
        XCTAssertEqual(SupportedCurrency.USD.localizedName, "美元")
        XCTAssertEqual(SupportedCurrency.CHF.localizedName, "瑞士法郎")

        AppLanguagePreference.language = .traditionalChinese
        XCTAssertEqual(SupportedCurrency.CHF.localizedName, "瑞士法郎")
    }

    func testThemeCopyMatchesCurrentWordingAcrossLanguages() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        let expectations: [(AppLanguage, [String: String])] = [
            (
                .english,
                [
                    "settings.theme": "Appearance",
                    "settings.theme.system": "System",
                    "settings.theme.light": "Light",
                    "settings.theme.dark": "Dark",
                    "settings.options": "Options",
                    "settings.startup": "Startup",
                    "settings.defaultLaunchPage": "Default Page",
                    "settings.defaultLaunchPage.footer": "Choose which tab opens when you launch Daily Sum."
                ]
            ),
            (
                .simplifiedChinese,
                [
                    "settings.theme": "外观",
                    "settings.theme.system": "跟随系统",
                    "settings.theme.light": "浅色",
                    "settings.theme.dark": "深色",
                    "settings.options": "选项",
                    "settings.startup": "启动",
                    "settings.defaultLaunchPage": "默认页面",
                    "settings.defaultLaunchPage.footer": "选择启动日常账时打开的标签页。"
                ]
            ),
            (
                .traditionalChinese,
                [
                    "settings.theme": "外觀",
                    "settings.theme.system": "跟隨系統",
                    "settings.theme.light": "淺色",
                    "settings.theme.dark": "深色",
                    "settings.options": "選項",
                    "settings.startup": "啟動",
                    "settings.defaultLaunchPage": "預設頁面",
                    "settings.defaultLaunchPage.footer": "選擇啟動日常帳時開啟的分頁。"
                ]
            )
        ]

        for (language, localizedValues) in expectations {
            AppLanguagePreference.language = language
            for (key, expectedValue) in localizedValues {
                XCTAssertEqual(
                    AppLocalization.string(key, defaultValue: ""),
                    expectedValue,
                    "\(key) should match \(language)"
                )
            }
        }
    }

    func testSystemCategoryKeyIsLocalizedInEnglishMode() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        AppLanguagePreference.language = .english

        let category = Category(
            nameKey: "category.expense.dining",
            icon: "cup.and.saucer.fill",
            colorHex: "#F8B500",
            type: .expense,
            isSystemDefault: true
        )

        XCTAssertEqual(category.displayName, "Dining")
    }

    func testEnglishCategoryCopyMatchesCurrentCategoryIntent() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        AppLanguagePreference.language = .english
        XCTAssertEqual(expenseCategoryDisplayNames(), [
            "Dining",
            "Drinks",
            "Groceries",
            "Transport",
            "Housing",
            "Utilities",
            "Phone Bill",
            "Household",
            "Shopping",
            "Electronics",
            "Personal Care",
            "Sports",
            "Medical",
            "Entertainment",
            "Subscriptions",
            "Learning",
            "Family",
            "Travel",
            "Gifts",
            "Pets",
            "Insurance",
            "Taxes",
            "Miscellaneous"
        ])
        XCTAssertEqual(
            AppLocalization.string(key: "category.income.gift", table: "CategoryLocalizations"),
            "Gift"
        )
    }

    func testEnglishGeneralCopyMatchesCurrentWording() {
        XCTAssertEqual(
            localizedStringValue(key: "account.delete.confirm.title", locale: "en"),
            "Delete this account?"
        )
        XCTAssertEqual(
            localizedStringValue(key: "account.delete.confirm.action", locale: "en"),
            "Delete Account"
        )
        XCTAssertEqual(
            localizedStringValue(key: "account.delete.confirm.message", locale: "en"),
            "Deleting an account removes all its transactions. This cannot be undone."
        )
        XCTAssertEqual(
            localizedStringValue(key: "dashboard.viewAllInReports", locale: "en"),
            "View All"
        )
        XCTAssertEqual(
            localizedStringValue(key: "schedule.reminder.title", locale: "en"),
            "Bill due soon"
        )
        XCTAssertEqual(
            localizedStringValue(key: "schedule.reminder.body", locale: "en"),
            "A subscription expense is due soon."
        )
        XCTAssertEqual(
            localizedStringValue(key: "settings.clearData.title", locale: "en"),
            "Clear all data?"
        )
        XCTAssertEqual(
            localizedStringValue(key: "settings.privacyPolicy.title", locale: "en"),
            "Privacy Policy"
        )
    }

    func testTraditionalChineseSettingsCopyMatchesCurrentWording() {
        XCTAssertEqual(
            localizedStringValue(
                key: "settings.exchangeRate.openCalculator",
                locale: "zh-Hant"
            ),
            "匯率計算器"
        )
        XCTAssertEqual(
            localizedStringValue(
                key: "settings.reminders.notDetermined",
                locale: "zh-Hant"
            ),
            "尚未要求"
        )
        XCTAssertEqual(
            localizedStringValue(
                key: "settings.reminders.denied",
                locale: "zh-Hant"
            ),
            "已關閉"
        )
        XCTAssertEqual(
            localizedStringValue(
                key: "transaction.edit.expense",
                locale: "zh-Hant"
            ),
            "編輯支出"
        )
        XCTAssertEqual(
            localizedStringValue(
                key: "transaction.edit.income",
                locale: "zh-Hant"
            ),
            "編輯收入"
        )
        XCTAssertEqual(
            localizedStringValue(
                key: "settings.privacyPolicy.title",
                locale: "zh-Hant"
            ),
            "私隱政策"
        )
    }

    func testSimplifiedChinesePrivacyPolicyCopyMatchesCurrentWording() {
        XCTAssertEqual(
            localizedStringValue(
                key: "settings.privacyPolicy.title",
                locale: "zh-Hans"
            ),
            "隐私政策"
        )
    }

    func testVersionOneDoesNotShipSupportFluxCopy() {
        XCTAssertNil(localizedStringValueIfPresent(key: "settings.supportFlux.title", locale: "en"))
        XCTAssertNil(localizedStringValueIfPresent(key: "settings.supportFlux.disclaimer", locale: "en"))
        XCTAssertNil(localizedStringValueIfPresent(key: "settings.supportFlux.title", locale: "zh-Hant"))
        XCTAssertNil(localizedStringValueIfPresent(key: "settings.supportFlux.disclaimer", locale: "zh-Hant"))
        XCTAssertNil(localizedStringValueIfPresent(key: "settings.supportFlux.title", locale: "zh-Hans"))
        XCTAssertNil(localizedStringValueIfPresent(key: "settings.supportFlux.disclaimer", locale: "zh-Hans"))
    }

    func testTravelCurrencyCopyMatchesCurrentWordingAcrossLanguages() {
        let expectedValues: [String: [String: String]] = [
            "en": [
                "settings.exchangeRate.travelSection": "Foreign Currency",
                "settings.exchangeRate.configuration.title": "Foreign Currency Settings",
                "settings.exchangeRate.configuration.toggle": "Enable Foreign Currency Mode",
                "settings.exchangeRate.configuration.mode": "Mode",
                "settings.exchangeRate.configuration.automatic": "Automatic",
                "settings.exchangeRate.configuration.manual": "Manual",
                "settings.exchangeRate.configuration.summary.automatic": "Automatic · %@",
                "settings.exchangeRate.configuration.summary.manual": "Manual · %@",
                "settings.exchangeRate.configuration.summary.manual.unset": "Manual (Not Set)",
                "settings.exchangeRate.configuration.footer": "When off, new transactions will not default to foreign currency.\nWhen on, Automatic follows your location; Manual uses your selected currency.",
                "settings.exchangeRate.detectedCurrency": "Detected Currency",
                "settings.exchangeRate.detectedCurrency.none": "Not Detected",
                "settings.exchangeRate.locationNotEnabled": "Location Not Enabled",
                "settings.exchangeRate.currentTravelCurrency": "Current Foreign Currency",
                "settings.exchangeRate.currentTravelCurrency.none": "Inactive",
                "settings.exchangeRate.manualTravelCurrency": "Selected Foreign Currency",
                "settings.exchangeRate.manualTravelCurrency.placeholder": "Select Currency",
                "settings.exchangeRate.manualTravelCurrency.auto": "Use Detected Currency",
                "settings.exchangeRate.refreshLocation": "Use Location to Update",
                "settings.exchangeRate.openCalculator": "Exchange Calculator",
                "transaction.travel": "Foreign Currency Transaction",
                "transaction.travel.currency": "Foreign Currency",
                "transaction.travel.badge": "Foreign",
                "transaction.travel.settledAs": "Settled as",
                "transaction.travel.modeHelper": "Foreign currency mode on — amount is entered in %@",
                "transaction.currencyPicker.title": "Select Currency",
                "transaction.currencyPicker.search": "Search code or currency name",
                "transaction.currencyPicker.suggested": "Suggested by Location",
                "transaction.currencyPicker.recent": "Recently Used",
                "transaction.currencyPicker.all": "All Currencies",
                "filter.advanced": "Advanced Filters",
                "filter.travelTransactions": "Show Foreign Currency Transactions Only",
                "filter.showUpcomingScheduled": "Include Upcoming Subscriptions",
                "account.error.travelCurrencyChangeUnsupported": "This account has foreign currency transactions. Create a new account instead of changing its currency."
            ],
            "zh-Hans": [
                "settings.exchangeRate.travelSection": "外币",
                "settings.exchangeRate.configuration.title": "外币设置",
                "settings.exchangeRate.configuration.toggle": "启用外币模式",
                "settings.exchangeRate.configuration.mode": "模式",
                "settings.exchangeRate.configuration.automatic": "自动",
                "settings.exchangeRate.configuration.manual": "手动",
                "settings.exchangeRate.configuration.summary.automatic": "自动 · %@",
                "settings.exchangeRate.configuration.summary.manual": "手动 · %@",
                "settings.exchangeRate.configuration.summary.manual.unset": "手动（未设置）",
                "settings.exchangeRate.configuration.footer": "关闭后，新交易不会默认使用外币。\n自动模式按所在地区设置货币；手动模式沿用你选择的货币。",
                "settings.exchangeRate.detectedCurrency": "检测到的货币",
                "settings.exchangeRate.detectedCurrency.none": "未检测到",
                "settings.exchangeRate.locationNotEnabled": "未启用定位",
                "settings.exchangeRate.currentTravelCurrency": "目前外币",
                "settings.exchangeRate.currentTravelCurrency.none": "未启用",
                "settings.exchangeRate.manualTravelCurrency": "所选外币",
                "settings.exchangeRate.manualTravelCurrency.placeholder": "选择货币",
                "settings.exchangeRate.manualTravelCurrency.auto": "使用定位货币",
                "settings.exchangeRate.refreshLocation": "使用定位更新",
                "settings.exchangeRate.openCalculator": "汇率计算器",
                "transaction.travel": "外币交易",
                "transaction.travel.currency": "外币",
                "transaction.travel.badge": "外币",
                "transaction.travel.settledAs": "结算为",
                "transaction.travel.modeHelper": "外币模式已开启，金额会以 %@ 输入",
                "transaction.currencyPicker.title": "选择货币",
                "transaction.currencyPicker.search": "搜索代码或货币名称",
                "transaction.currencyPicker.suggested": "定位建议",
                "transaction.currencyPicker.recent": "最近使用",
                "transaction.currencyPicker.all": "所有货币",
                "filter.advanced": "进阶筛选",
                "filter.travelTransactions": "仅显示外币交易",
                "filter.showUpcomingScheduled": "显示即将到期的订阅交易",
                "account.error.travelCurrencyChangeUnsupported": "此账户已有外币交易。请新建账户，不要直接更改币种。"
            ],
            "zh-Hant": [
                "settings.exchangeRate.travelSection": "外幣",
                "settings.exchangeRate.configuration.title": "外幣設定",
                "settings.exchangeRate.configuration.toggle": "啟用外幣模式",
                "settings.exchangeRate.configuration.mode": "模式",
                "settings.exchangeRate.configuration.automatic": "自動",
                "settings.exchangeRate.configuration.manual": "手動",
                "settings.exchangeRate.configuration.summary.automatic": "自動 · %@",
                "settings.exchangeRate.configuration.summary.manual": "手動 · %@",
                "settings.exchangeRate.configuration.summary.manual.unset": "手動（未設定）",
                "settings.exchangeRate.configuration.footer": "關閉後，新交易不會預設使用外幣。\n自動模式按所在地區設定貨幣；手動模式則沿用你選定的貨幣。",
                "settings.exchangeRate.detectedCurrency": "偵測到的貨幣",
                "settings.exchangeRate.detectedCurrency.none": "未偵測到",
                "settings.exchangeRate.locationNotEnabled": "未啟用定位",
                "settings.exchangeRate.currentTravelCurrency": "目前外幣",
                "settings.exchangeRate.currentTravelCurrency.none": "未啟用",
                "settings.exchangeRate.manualTravelCurrency": "所選外幣",
                "settings.exchangeRate.manualTravelCurrency.placeholder": "選擇貨幣",
                "settings.exchangeRate.manualTravelCurrency.auto": "使用定位貨幣",
                "settings.exchangeRate.refreshLocation": "使用定位更新",
                "settings.exchangeRate.openCalculator": "匯率計算器",
                "transaction.travel": "外幣交易",
                "transaction.travel.currency": "外幣",
                "transaction.travel.badge": "外幣",
                "transaction.travel.settledAs": "結算為",
                "transaction.travel.modeHelper": "外幣模式已開啟，金額會以 %@ 輸入",
                "transaction.currencyPicker.title": "選擇貨幣",
                "transaction.currencyPicker.search": "搜尋代碼或貨幣名稱",
                "transaction.currencyPicker.suggested": "定位建議",
                "transaction.currencyPicker.recent": "最近使用",
                "transaction.currencyPicker.all": "所有貨幣",
                "filter.advanced": "進階篩選",
                "filter.travelTransactions": "僅顯示外幣交易",
                "filter.showUpcomingScheduled": "顯示即將到期的訂閱交易",
                "account.error.travelCurrencyChangeUnsupported": "此帳戶已有外幣交易。請另建新帳戶，勿直接更改貨幣。"
            ]
        ]

        for (locale, keyValues) in expectedValues {
            for (key, expectedValue) in keyValues {
                XCTAssertEqual(
                    localizedStringValue(key: key, locale: locale),
                    expectedValue,
                    "Unexpected value for \(key) in \(locale)"
                )
            }
        }
    }

    func testSyncAndBackupCopyMatchesCurrentWordingAcrossLanguages() {
        let expectedValues: [String: [String: String]] = [
            "en": [
                "action.close": "Close",
                "settings.dataContinuity": "Sync & Backup",
                "settings.cloudSync": "iCloud Sync",
                "settings.cloudSync.enable": "Enable iCloud Sync",
                "settings.cloudSync.status.on": "On",
                "settings.cloudSync.status.off": "Off",
                "settings.cloudSync.status.needsAttention": "Needs Attention",
                "settings.cloudSync.message.on": "Changes sync through iCloud.",
                "settings.cloudSync.message.off": "Sync is currently off.",
                "settings.cloudSync.message.signInRequired": "Sign in to iCloud in Settings, then return here to enable sync.",
                "settings.backup.action": "Backup",
                "settings.backup.automatic": "Automatic Backup",
                "settings.backup.automatic.never": "Never",
                "settings.backup.automatic.daily": "Daily",
                "settings.backup.automatic.weekly": "Weekly",
                "settings.backup.automatic.monthly": "Monthly",
                "settings.backup.retention": "Keep Backups",
                "settings.backup.retention.noLimit": "No Limit",
                "settings.backup.location.iCloudDrive": "iCloud Drive",
                "settings.backup.location.thisDevice": "This Device",
                "settings.backup.restore.behavior": "Create iCloud Drive backups or restore from an existing backup. Restore replaces current financial data and restores all included preferences.",
                "settings.backup.title": "Backup",
                "settings.backup.export": "Back Up Now",
                "settings.backup.footer": "Backups are saved to iCloud Drive when available, otherwise to this device.",
                "settings.backup.list.title": "Backup History",
                "settings.backup.list.empty.message": "Tap Back Up Now to create your first backup.",
                "settings.backup.restore.result": "Restore Result",
                "settings.backup.restore.confirm.title": "Restore Backup?",
                "settings.backup.restore.confirm": "Confirm Restore",
                "settings.backup.restore.confirm.action": "Restore Backup",
                "settings.backup.restore.confirm.message": "Restore replaces current financial data and restores the preferences included in this backup.",
                "settings.backup.summary": "%1$@, %2$lld accounts, %3$lld transactions",
                "settings.backup.record.accounts.one": "%lld account",
                "settings.backup.record.accounts.other": "%lld accounts",
                "settings.backup.record.summary": "%1$@, %2$@, %3$@, %4$@",
                "settings.backup.record.transactions.one": "%lld transaction",
                "settings.backup.record.transactions.other": "%lld transactions",
                "settings.backup.import.summary": "Imported %1$lld, updated %2$lld, skipped %3$lld, failed %4$lld"
            ],
            "zh-Hans": [
                "action.close": "关闭",
                "settings.dataContinuity": "同步与备份",
                "settings.cloudSync": "iCloud 同步",
                "settings.cloudSync.enable": "启用 iCloud 同步",
                "settings.cloudSync.status.on": "开启",
                "settings.cloudSync.status.off": "关闭",
                "settings.cloudSync.status.needsAttention": "待处理",
                "settings.cloudSync.message.on": "更改会通过 iCloud 同步。",
                "settings.cloudSync.message.off": "同步目前已关闭。",
                "settings.cloudSync.message.signInRequired": "请先在“设置”中登录 iCloud，然后返回此处启用同步。",
                "settings.backup.action": "备份",
                "settings.backup.automatic": "自动备份",
                "settings.backup.automatic.never": "永不",
                "settings.backup.automatic.daily": "每日",
                "settings.backup.automatic.weekly": "每周",
                "settings.backup.automatic.monthly": "每月",
                "settings.backup.retention": "保留备份",
                "settings.backup.retention.noLimit": "无限制",
                "settings.backup.location.iCloudDrive": "iCloud Drive",
                "settings.backup.location.thisDevice": "此设备",
                "settings.backup.restore.behavior": "可将数据备份到 iCloud Drive，或从现有备份恢复。恢复时会替换现有财务数据，并应用备份中的偏好设置。",
                "settings.backup.title": "备份",
                "settings.backup.export": "立即备份",
                "settings.backup.footer": "如果 iCloud Drive 可用，备份将存储到其中；否则存储到此设备。",
                "settings.backup.list.title": "备份记录",
                "settings.backup.list.empty.message": "点击“立即备份”创建首个备份。",
                "settings.backup.restore.result": "恢复结果",
                "settings.backup.restore.confirm.title": "要恢复备份吗？",
                "settings.backup.restore.confirm": "确认恢复",
                "settings.backup.restore.confirm.action": "恢复备份",
                "settings.backup.restore.confirm.message": "现有财务数据将由此备份替换，备份中的偏好设置也会一并应用。",
                "settings.backup.summary": "%1$@，%2$lld 个账户，%3$lld 笔交易",
                "settings.backup.record.accounts.one": "%lld 个账户",
                "settings.backup.record.accounts.other": "%lld 个账户",
                "settings.backup.record.summary": "%1$@，%2$@，%3$@，%4$@",
                "settings.backup.record.transactions.one": "%lld 笔交易",
                "settings.backup.record.transactions.other": "%lld 笔交易",
                "settings.backup.import.summary": "已导入 %1$lld，已更新 %2$lld，已跳过 %3$lld，失败 %4$lld"
            ],
            "zh-Hant": [
                "action.close": "關閉",
                "settings.dataContinuity": "同步與備份",
                "settings.cloudSync": "iCloud 同步",
                "settings.cloudSync.enable": "啟用 iCloud 同步",
                "settings.cloudSync.status.on": "開啟",
                "settings.cloudSync.status.off": "關閉",
                "settings.cloudSync.status.needsAttention": "待處理",
                "settings.cloudSync.message.on": "更改會透過 iCloud 同步。",
                "settings.cloudSync.message.off": "同步目前已關閉。",
                "settings.cloudSync.message.signInRequired": "請先在「設定」登入 iCloud，再返回此處啟用同步。",
                "settings.backup.action": "備份",
                "settings.backup.automatic": "自動備份",
                "settings.backup.automatic.never": "永不",
                "settings.backup.automatic.daily": "每日",
                "settings.backup.automatic.weekly": "每週",
                "settings.backup.automatic.monthly": "每月",
                "settings.backup.retention": "保留備份",
                "settings.backup.retention.noLimit": "無限制",
                "settings.backup.location.iCloudDrive": "iCloud Drive",
                "settings.backup.location.thisDevice": "此裝置",
                "settings.backup.restore.behavior": "可將資料備份至 iCloud Drive，或從現有備份還原。還原時會取代現有財務資料，並套用備份內的偏好設定。",
                "settings.backup.title": "備份",
                "settings.backup.export": "立即備份",
                "settings.backup.footer": "如可使用 iCloud Drive，備份會存於其中；否則存於此裝置。",
                "settings.backup.list.title": "備份記錄",
                "settings.backup.list.empty.message": "點按「立即備份」建立首個備份。",
                "settings.backup.restore.result": "還原結果",
                "settings.backup.restore.confirm.title": "要還原備份嗎？",
                "settings.backup.restore.confirm": "確認還原",
                "settings.backup.restore.confirm.action": "還原備份",
                "settings.backup.restore.confirm.message": "現有財務資料將由此備份取代，備份內的偏好設定亦會套用。",
                "settings.backup.summary": "%1$@，%2$lld 個帳戶，%3$lld 筆交易",
                "settings.backup.record.accounts.one": "%lld 個帳戶",
                "settings.backup.record.accounts.other": "%lld 個帳戶",
                "settings.backup.record.summary": "%1$@，%2$@，%3$@，%4$@",
                "settings.backup.record.transactions.one": "%lld 筆交易",
                "settings.backup.record.transactions.other": "%lld 筆交易",
                "settings.backup.import.summary": "已匯入 %1$lld，已更新 %2$lld，已略過 %3$lld，失敗 %4$lld"
            ]
        ]

        for (locale, keyValues) in expectedValues {
            for (key, expectedValue) in keyValues {
                XCTAssertEqual(
                    localizedStringValue(key: key, locale: locale),
                    expectedValue,
                    "Unexpected value for \(key) in \(locale)"
                )
            }
        }
    }

    func testCSVExportCopyMatchesCurrentWordingAcrossLanguages() {
        let expectedValues: [String: [String: String]] = [
            "en": [
                "settings.csvExport.action": "Export Transactions CSV",
                "settings.csvExport.footer": "Exports all transactions with original and converted amounts.",
                "settings.csvExport.error": "Unable to export transactions. Please try again."
            ],
            "zh-Hans": [
                "settings.csvExport.action": "导出交易 CSV",
                "settings.csvExport.footer": "导出所有交易，并包括原始金额和换算金额。",
                "settings.csvExport.error": "无法导出交易，请再试一次。"
            ],
            "zh-Hant": [
                "settings.csvExport.action": "匯出交易 CSV",
                "settings.csvExport.footer": "匯出所有交易，並包括原始金額及換算金額。",
                "settings.csvExport.error": "無法匯出交易，請再試一次。"
            ]
        ]

        for (locale, keyValues) in expectedValues {
            for (key, expectedValue) in keyValues {
                XCTAssertEqual(
                    localizedStringValue(key: key, locale: locale),
                    expectedValue,
                    "Unexpected value for \(key) in \(locale)"
                )
            }
        }
    }

    func testTransactionFilterCopyUsesShorterChineseDateLabelsAndAllAccountsOption() {
        let expectedValues: [String: [String: String]] = [
            "en": [
                "filter.from": "From",
                "filter.to": "To",
                "filter.allAccounts": "All Accounts"
            ],
            "zh-Hans": [
                "filter.from": "从",
                "filter.to": "到",
                "filter.allAccounts": "全部账户"
            ],
            "zh-Hant": [
                "filter.from": "從",
                "filter.to": "到",
                "filter.allAccounts": "全部帳戶"
            ]
        ]

        for (locale, keyValues) in expectedValues {
            for (key, expectedValue) in keyValues {
                XCTAssertEqual(
                    localizedStringValue(key: key, locale: locale),
                    expectedValue,
                    "Unexpected value for \(key) in \(locale)"
                )
            }
        }
    }

    func testScheduleHeaderCopyUsesDistinctSectionTitleAcrossLanguages() {
        let expectedValues = [
            "en": "Entry Type",
            "zh-Hans": "记录方式",
            "zh-Hant": "記錄方式"
        ]

        for (locale, expectedValue) in expectedValues {
            let headerValue = localizedStringValue(
                key: "transaction.schedule.header",
                locale: locale
            )
            let recurringValue = localizedStringValue(
                key: "transaction.schedule.recurring",
                locale: locale
            )

            XCTAssertEqual(headerValue, expectedValue)
            XCTAssertNotEqual(
                headerValue,
                recurringValue,
                "Schedule section title should stay distinct from the recurring option for \(locale)"
            )
        }
    }

    func testUpcomingHintSubtitleFormatSpecifiersAreConsistentAcrossLanguages() {
        let localesByLanguage: [(AppLanguage, String)] = [
            (.english, "en"),
            (.simplifiedChinese, "zh-Hans"),
            (.traditionalChinese, "zh-Hant")
        ]

        for (language, locale) in localesByLanguage {
            let value = localizedStringValue(key: "transaction.upcomingHint.subtitle", locale: locale)
            let integerSpecifiers = value.matches(of: /%(?:\d+\$)?lld/).count
            let objectSpecifiers = value.matches(of: /%(?:\d+\$)?@/).count

            XCTAssertEqual(
                integerSpecifiers,
                2,
                "Expected exactly two integer placeholders for \(language)"
            )
            XCTAssertEqual(
                objectSpecifiers,
                1,
                "Expected exactly one object placeholder for \(language)"
            )
        }
    }

    func testBudgetAlertWarningBodyFormatsAcrossLanguages() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        let cases: [(AppLanguage, String)] = [
            (.english, "Food has reached 80% of its budget."),
            (.simplifiedChinese, "Food 已使用 80% 预算。"),
            (.traditionalChinese, "Food 已用八成預算。")
        ]

        for (language, expectedValue) in cases {
            AppLanguagePreference.language = language

            XCTAssertEqual(
                AppLocalization.formatted(
                    "budget.alert.notification.warning.body",
                    defaultValue: "%1$@ has reached 80%% of its budget.",
                    "Food"
                ),
                expectedValue
            )
        }
    }

    private func localizedStringValue(
        key: String,
        locale: String,
        table: String = "Localizable"
    ) -> String {
        guard let value = localizedStringValueIfPresent(key: key, locale: locale, table: table) else {
            XCTFail("Missing localization value for key \(key) locale \(locale)")
            return ""
        }

        return value
    }

    private func localizedStringValueIfPresent(
        key: String,
        locale: String,
        table: String = "Localizable"
    ) -> String? {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repoRoot = testsDirectory.deletingLastPathComponent()
        let xcstringsURL = repoRoot
            .appendingPathComponent("Flux")
            .appendingPathComponent("Resources")
            .appendingPathComponent("\(table).xcstrings")

        do {
            let data = try Data(contentsOf: xcstringsURL)
            let object = try JSONSerialization.jsonObject(with: data)
            guard
                let root = object as? [String: Any],
                let strings = root["strings"] as? [String: Any],
                let keyNode = strings[key] as? [String: Any],
                let localizations = keyNode["localizations"] as? [String: Any],
                let localeNode = localizations[locale] as? [String: Any],
                let stringUnit = localeNode["stringUnit"] as? [String: Any],
                let value = stringUnit["value"] as? String
            else {
                return nil
            }

            return value
        } catch {
            XCTFail("Failed to load \(table).xcstrings: \(error)")
            return nil
        }
    }

    func testReportMonthFormattingFollowsSelectedAppLanguage() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        let date = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 1, day: 15)
        )!

        AppLanguagePreference.language = .english
        let englishLabel = DateFormatterUtility.shared.formatReportMonth(date)

        AppLanguagePreference.language = .simplifiedChinese
        let simplifiedChineseLabel = DateFormatterUtility.shared.formatReportMonth(date)

        XCTAssertNotEqual(englishLabel, simplifiedChineseLabel)
        XCTAssertEqual(
            englishLabel,
            date.formatted(.dateTime.month(.abbreviated).year().locale(Locale(identifier: "en")))
        )
        XCTAssertEqual(
            simplifiedChineseLabel,
            "26年1月"
        )
    }

    func testReportMonthUsesShortChineseFormat() {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!

        XCTAssertEqual(
            DateFormatterUtility.shared.formatReportMonth(
                date,
                locale: Locale(identifier: "zh-Hant")
            ),
            "25年12月"
        )
        XCTAssertEqual(
            DateFormatterUtility.shared.formatReportChartMonth(
                date,
                locale: Locale(identifier: "zh-Hant")
            ),
            "12月"
        )
    }

    func testCategoryLocalizationUsesHongKongTraditionalChineseWording() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        AppLanguagePreference.language = .traditionalChinese
        XCTAssertEqual(expenseCategoryDisplayNames(), [
            "餐飲",
            "飲品",
            "超市",
            "交通",
            "住屋",
            "水電煤",
            "電話費",
            "家居",
            "購物",
            "電子產品",
            "個人護理",
            "運動",
            "醫療",
            "娛樂",
            "訂閱",
            "學習",
            "家庭",
            "旅遊",
            "禮物",
            "寵物",
            "保險",
            "稅務",
            "雜費"
        ])
    }

    func testReportsNetUsesFinancialWordingAcrossChineseLocalizations() {
        XCTAssertEqual(
            localizedStringValue(key: "reports.net", locale: "zh-Hans"),
            "净额"
        )
        XCTAssertEqual(
            localizedStringValue(key: "reports.net", locale: "zh-Hant"),
            "淨額"
        )
    }

    func testReportsExpensesUsesSpendingWordingAcrossChineseLocalizations() {
        XCTAssertEqual(
            localizedStringValue(key: "reports.expenses", locale: "zh-Hans"),
            "支出"
        )
        XCTAssertEqual(
            localizedStringValue(key: "reports.expenses", locale: "zh-Hant"),
            "支出"
        )
        XCTAssertEqual(
            localizedStringValue(key: "reports.totalExpenses", locale: "zh-Hans"),
            "总支出"
        )
        XCTAssertEqual(
            localizedStringValue(key: "reports.totalExpenses", locale: "zh-Hant"),
            "總支出"
        )
        XCTAssertEqual(
            localizedStringValue(key: "reports.expensesByCategory", locale: "zh-Hans"),
            "分类支出"
        )
        XCTAssertEqual(
            localizedStringValue(key: "reports.expensesByCategory", locale: "zh-Hant"),
            "類別支出"
        )
    }

    func testReportsMonthlyTrendsTitleUsesRecentHalfYearWordingInChinese() {
        XCTAssertEqual(
            localizedStringValue(key: "reports.monthlyTrends", locale: "zh-Hans"),
            "近半年走势"
        )
        XCTAssertEqual(
            localizedStringValue(key: "reports.monthlyTrends", locale: "zh-Hant"),
            "近半年走勢"
        )
    }

    func testCategoryLocalizationUsesRequestedSimplifiedChineseWording() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        AppLanguagePreference.language = .simplifiedChinese
        XCTAssertEqual(expenseCategoryDisplayNames(), [
            "餐饮",
            "饮品",
            "超市",
            "交通",
            "住房",
            "水电燃气",
            "电话费",
            "家居",
            "购物",
            "电子产品",
            "个人护理",
            "运动",
            "医疗",
            "娱乐",
            "订阅",
            "学习",
            "家庭",
            "旅游",
            "礼物",
            "宠物",
            "保险",
            "税费",
            "杂费"
        ])
    }

    func testCategoryPickerPlaceholderVisibilityByMode() {
        XCTAssertFalse(CategoryPickerMode.transaction(.expense).showsPlaceholderOption)
        XCTAssertFalse(CategoryPickerMode.transaction(.income).showsPlaceholderOption)
        XCTAssertTrue(CategoryPickerMode.budgetExpense.showsPlaceholderOption)
    }

    func testAllSystemCategoryKeysResolveForAllAppLanguages() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        let categoryKeys = [
            "category.expense.food",
            "category.expense.home",
            "category.expense.transport",
            "category.expense.shopping",
            "category.expense.entertainment",
            "category.expense.bills",
            "category.expense.insurance",
            "category.expense.tax",
            "category.expense.health",
            "category.expense.medical",
            "category.expense.education",
            "category.expense.upskilling",
            "category.expense.learning",
            "category.expense.pet",
            "category.expense.travel",
            "category.expense.groceries",
            "category.expense.dining",
            "category.expense.coffee",
            "category.expense.utilities",
            "category.expense.phone",
            "category.expense.electronics",
            "category.expense.sports",
            "category.expense.family",
            "category.expense.miscellaneous",
            "category.expense.subscriptions",
            "category.expense.housing",
            "category.expense.personalCare",
            "category.expense.gifts",
            "category.income.salary",
            "category.income.bonus",
            "category.income.freelance",
            "category.income.interest",
            "category.income.governmentSubsidy",
            "category.income.secondHandSale",
            "category.income.investment",
            "category.income.gift",
            "category.income.refund"
        ]
        let languages: [AppLanguage] = [.english, .simplifiedChinese, .traditionalChinese]

        for language in languages {
            AppLanguagePreference.language = language
            for key in categoryKeys {
                let localized = AppLocalization.string(key: key, table: "CategoryLocalizations")
                XCTAssertFalse(localized.isEmpty, "\(key) should not be empty for \(language)")
                XCTAssertNotEqual(localized, key, "\(key) should resolve for \(language)")
            }
        }
    }

    @MainActor
    func testIncomeAndExpenseGiftUseSameIcon() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let seeder = DefaultDataSeeder(context: context)
        try await seeder.seedIfNeeded()

        let categories = try context.fetch(FetchDescriptor<Flux.Category>())
        let expenseGift = categories.first { $0.nameKey == "category.expense.gifts" }
        let incomeGift = categories.first { $0.nameKey == "category.income.gift" }

        XCTAssertNotNil(expenseGift)
        XCTAssertNotNil(incomeGift)
        XCTAssertEqual(expenseGift?.icon, incomeGift?.icon)
    }

    @MainActor
    func testDefaultExpenseCategoriesUseExpectedIconAndColorMapping() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let seeder = DefaultDataSeeder(context: context)
        try await seeder.seedIfNeeded()

        let categories = try context.fetch(FetchDescriptor<Flux.Category>())
        let expectations: [String: (icon: String, colorHex: String)] = [
            "category.expense.dining": ("fork.knife", "#F59E0B"),
            "category.expense.coffee": ("cup.and.saucer.fill", "#A16207"),
            "category.expense.groceries": ("cart.fill", "#22C55E"),
            "category.expense.transport": ("tram.fill", "#14B8A6"),
            "category.expense.housing": ("building.2.fill", "#3B82F6"),
            "category.expense.utilities": ("bolt.fill", "#F59E0B"),
            "category.expense.phone": ("wifi", "#06B6D4"),
            "category.expense.home": ("sofa.fill", "#06B6D4"),
            "category.expense.shopping": ("bag.fill", "#06B6D4"),
            "category.expense.electronics": ("desktopcomputer", "#6366F1"),
            "category.expense.personalCare": ("comb", "#F43F5E"),
            "category.expense.sports": ("dumbbell.fill", "#14B8A6"),
            "category.expense.medical": ("cross.case.fill", "#EC4899"),
            "category.expense.entertainment": ("ticket.fill", "#6366F1"),
            "category.expense.subscriptions": ("repeat", "#A855F7"),
            "category.expense.learning": ("books.vertical.fill", "#3B82F6"),
            "category.expense.family": ("person.3.fill", "#EF4444"),
            "category.expense.travel": ("airplane", "#F59E0B"),
            "category.expense.gifts": ("gift.fill", "#EF4444"),
            "category.expense.pet": ("pawprint.fill", "#A16207"),
            "category.expense.insurance": ("shield.fill", "#A855F7"),
            "category.expense.tax": ("building.columns.fill", "#F59E0B"),
            "category.expense.miscellaneous": ("ellipsis.circle.fill", "#64748B")
        ]

        for (key, expectation) in expectations {
            let category = try XCTUnwrap(categories.first { $0.nameKey == key })
            XCTAssertEqual(category.icon, expectation.icon, "\(key) icon")
            XCTAssertEqual(category.colorHex, expectation.colorHex, "\(key) color")
            XCTAssertNotNil(UIImage(systemName: category.icon), "\(key) must use a valid SF Symbol")
        }

        XCTAssertTrue(SFSymbolCatalog.all.contains("ellipsis.circle.fill"))
    }
}
