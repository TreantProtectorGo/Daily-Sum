import XCTest
import SwiftUI
import SwiftData
@testable import Flux

final class LocalizationTests: XCTestCase {
    
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

    func testLocalizedValuesFollowSelectedAppLanguage() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        AppLanguagePreference.language = .english
        XCTAssertEqual(TransactionType.income.localizedName, "Income")
        XCTAssertEqual(SupportedCurrency.USD.localizedName, "US Dollar")

        AppLanguagePreference.language = .simplifiedChinese
        XCTAssertEqual(TransactionType.income.localizedName, "收入")
        XCTAssertEqual(SupportedCurrency.USD.localizedName, "美元")
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
        XCTAssertEqual(
            AppLocalization.string(key: "category.expense.food", table: "CategoryLocalizations"),
            "Ingredients"
        )
        XCTAssertEqual(
            AppLocalization.string(key: "category.expense.dining", table: "CategoryLocalizations"),
            "Dining"
        )
        XCTAssertEqual(
            AppLocalization.string(key: "category.expense.coffee", table: "CategoryLocalizations"),
            "Drinks"
        )
        XCTAssertEqual(
            AppLocalization.string(key: "category.expense.home", table: "CategoryLocalizations"),
            "Household"
        )
        XCTAssertEqual(
            AppLocalization.string(key: "category.expense.tax", table: "CategoryLocalizations"),
            "Taxes"
        )
        XCTAssertEqual(
            AppLocalization.string(key: "category.expense.pet", table: "CategoryLocalizations"),
            "Pets"
        )
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
            localizedStringValue(key: "dashboard.viewAllInReports", locale: "en"),
            "View all in Reports"
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
            localizedStringValue(key: "settings.privacy.message", locale: "en"),
            "Data stays local-first, with optional iCloud sync and manual backup restore controls."
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
            "未啟用"
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
    }

    func testTravelCurrencyCopyMatchesCurrentWordingAcrossLanguages() {
        let expectedValues: [String: [String: String]] = [
            "en": [
                "settings.exchangeRate.travelSection": "Travel Currency",
                "settings.exchangeRate.configuration": "Travel Currency Mode",
                "settings.exchangeRate.configuration.automatic": "Automatic",
                "settings.exchangeRate.configuration.manual": "Manual",
                "settings.exchangeRate.configuration.summary.manual.unset": "Manual (Not Set)",
                "settings.exchangeRate.configuration.footer": "Automatic mode follows your current location. Manual mode stays active until you switch back.",
                "settings.exchangeRate.detectedCurrency": "Detected Currency",
                "settings.exchangeRate.detectedCurrency.none": "Not Detected",
                "settings.exchangeRate.currentTravelCurrency": "Current Travel Currency",
                "settings.exchangeRate.currentTravelCurrency.none": "Inactive",
                "settings.exchangeRate.manualTravelCurrency": "Selected Travel Currency",
                "settings.exchangeRate.manualTravelCurrency.placeholder": "Select Currency",
                "settings.exchangeRate.manualTravelCurrency.auto": "Use Detected Currency",
                "settings.exchangeRate.openCalculator": "Exchange Calculator",
                "transaction.travel": "Travel Transaction",
                "transaction.travel.badge": "Travel",
                "transaction.travel.chargedAs": "Charged as",
                "transaction.travel.modeHelper": "Travel mode on — amount is entered in %@",
                "filter.advanced": "Advanced Filters",
                "filter.travelTransactions": "Show Travel Transactions Only",
                "filter.showUpcomingScheduled": "Include Upcoming Subscriptions",
                "account.error.travelCurrencyChangeUnsupported": "This account has travel transactions. Create a new account instead of changing its currency."
            ],
            "zh-Hans": [
                "settings.exchangeRate.travelSection": "旅行货币",
                "settings.exchangeRate.configuration": "旅行货币设定",
                "settings.exchangeRate.configuration.automatic": "自动",
                "settings.exchangeRate.configuration.manual": "手动",
                "settings.exchangeRate.configuration.summary.manual.unset": "手动（未设定）",
                "settings.exchangeRate.configuration.footer": "自动模式会根据你目前的位置更新旅行货币。手动模式会持续生效，直到你切回自动。",
                "settings.exchangeRate.detectedCurrency": "定位货币",
                "settings.exchangeRate.detectedCurrency.none": "未侦测到",
                "settings.exchangeRate.currentTravelCurrency": "目前旅行货币",
                "settings.exchangeRate.currentTravelCurrency.none": "未启用",
                "settings.exchangeRate.manualTravelCurrency": "选择的旅行货币",
                "settings.exchangeRate.manualTravelCurrency.placeholder": "请选择货币",
                "settings.exchangeRate.manualTravelCurrency.auto": "使用定位货币",
                "settings.exchangeRate.openCalculator": "汇率计算器",
                "transaction.travel": "旅行交易",
                "transaction.travel.badge": "旅行",
                "transaction.travel.chargedAs": "入账为",
                "transaction.travel.modeHelper": "旅行模式已开启，金额会以 %@ 输入",
                "filter.advanced": "进阶筛选",
                "filter.travelTransactions": "仅显示旅行交易",
                "filter.showUpcomingScheduled": "显示即将到来的订阅交易",
                "account.error.travelCurrencyChangeUnsupported": "此账户已有旅行交易。请改为建立新账户，而不是直接更改币别。"
            ],
            "zh-Hant": [
                "settings.exchangeRate.travelSection": "旅行貨幣",
                "settings.exchangeRate.configuration": "旅行貨幣設定",
                "settings.exchangeRate.configuration.automatic": "自動",
                "settings.exchangeRate.configuration.manual": "手動",
                "settings.exchangeRate.configuration.summary.manual.unset": "手動（未設定）",
                "settings.exchangeRate.configuration.footer": "自動模式會根據你目前的位置更新旅行貨幣。手動模式會持續生效，直到你切回自動。",
                "settings.exchangeRate.detectedCurrency": "定位貨幣",
                "settings.exchangeRate.detectedCurrency.none": "未偵測到",
                "settings.exchangeRate.currentTravelCurrency": "目前旅行貨幣",
                "settings.exchangeRate.currentTravelCurrency.none": "未啟用",
                "settings.exchangeRate.manualTravelCurrency": "選擇的旅行貨幣",
                "settings.exchangeRate.manualTravelCurrency.placeholder": "請選擇貨幣",
                "settings.exchangeRate.manualTravelCurrency.auto": "使用定位貨幣",
                "settings.exchangeRate.openCalculator": "匯率計算器",
                "transaction.travel": "旅行交易",
                "transaction.travel.badge": "旅行",
                "transaction.travel.chargedAs": "入帳為",
                "transaction.travel.modeHelper": "旅行模式已開啟，金額會以 %@ 輸入",
                "filter.advanced": "進階篩選",
                "filter.travelTransactions": "僅顯示旅遊交易",
                "filter.showUpcomingScheduled": "顯示即將到來的訂閱交易",
                "account.error.travelCurrencyChangeUnsupported": "此帳戶已有旅行交易。請改為建立新帳戶，而不是直接更改幣別。"
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
                "settings.backup.list.title": "Backups",
                "settings.backup.list.empty.message": "Tap Back Up Now to create your first backup.",
                "settings.backup.restore.result": "Restore Result",
                "settings.backup.restore.confirm.title": "Restore Backup?",
                "settings.backup.restore.confirm": "Confirm Restore",
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
                "settings.cloudSync.status.needsAttention": "需要处理",
                "settings.cloudSync.message.on": "所作更改，均会透过 iCloud 同步。",
                "settings.cloudSync.message.off": "同步目前已关闭。",
                "settings.cloudSync.message.signInRequired": "请先在“设置”中登入 iCloud，然后返回这里启用同步。",
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
                "settings.backup.restore.behavior": "可建立 iCloud Drive 备份，也可从现有备份还原。",
                "settings.backup.title": "备份",
                "settings.backup.export": "立即备份",
                "settings.backup.footer": "可用时备份会储存到 iCloud Drive，否则会储存在此装置。",
                "settings.backup.list.title": "备份",
                "settings.backup.list.empty.message": "点一下「立即备份」建立第一个备份。",
                "settings.backup.restore.result": "还原结果",
                "settings.backup.restore.confirm.title": "要还原备份吗？",
                "settings.backup.restore.confirm": "确认还原",
                "settings.backup.restore.confirm.message": "还原会取代目前的财务数据，并还原此备份内包含的偏好设定。",
                "settings.backup.summary": "%1$@，%2$lld 个账户，%3$lld 笔交易",
                "settings.backup.record.accounts.one": "%lld 个账户",
                "settings.backup.record.accounts.other": "%lld 个账户",
                "settings.backup.record.summary": "%1$@，%2$@，%3$@，%4$@",
                "settings.backup.record.transactions.one": "%lld 笔交易",
                "settings.backup.record.transactions.other": "%lld 笔交易",
                "settings.backup.import.summary": "已汇入 %1$lld，已更新 %2$lld，已略过 %3$lld，失败 %4$lld"
            ],
            "zh-Hant": [
                "action.close": "關閉",
                "settings.dataContinuity": "同步與備份",
                "settings.cloudSync": "iCloud 同步",
                "settings.cloudSync.enable": "啟用 iCloud 同步",
                "settings.cloudSync.status.on": "開啟",
                "settings.cloudSync.status.off": "關閉",
                "settings.cloudSync.status.needsAttention": "需要處理",
                "settings.cloudSync.message.on": "所作更改，均會透過 iCloud 同步。",
                "settings.cloudSync.message.off": "同步目前已關閉。",
                "settings.cloudSync.message.signInRequired": "請先在「設定」中登入 iCloud，然後返回這裡啟用同步。",
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
                "settings.backup.restore.behavior": "可建立 iCloud Drive 備份，亦可由現有備份還原。",
                "settings.backup.title": "備份",
                "settings.backup.export": "立即備份",
                "settings.backup.footer": "可用時備份會儲存到 iCloud Drive，否則會儲存在此裝置。",
                "settings.backup.list.title": "備份",
                "settings.backup.list.empty.message": "點一下「立即備份」建立第一個備份。",
                "settings.backup.restore.result": "還原結果",
                "settings.backup.restore.confirm.title": "要還原備份嗎？",
                "settings.backup.restore.confirm": "確認還原",
                "settings.backup.restore.confirm.message": "還原會取代目前的財務資料，並還原此備份內包含的偏好設定。",
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
            (.simplifiedChinese, "Food 已达到预算的 80%。"),
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
                XCTFail("Missing localization value for key \(key) locale \(locale)")
                return ""
            }

            return value
        } catch {
            XCTFail("Failed to load \(table).xcstrings: \(error)")
            return ""
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
            date.formatted(.dateTime.month(.abbreviated).year().locale(Locale(identifier: "zh-Hans")))
        )
    }

    func testCategoryLocalizationUsesHongKongTraditionalChineseWording() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        AppLanguagePreference.language = .traditionalChinese
        XCTAssertEqual(
            AppLocalization.string(key: "category.expense.coffee", table: "CategoryLocalizations"),
            "飲品"
        )
        XCTAssertEqual(
            AppLocalization.string(key: "category.expense.dining", table: "CategoryLocalizations"),
            "食飯"
        )
    }

    func testCategoryLocalizationUsesRequestedSimplifiedChineseWording() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        AppLanguagePreference.language = .simplifiedChinese
        XCTAssertEqual(
            AppLocalization.string(key: "category.expense.upskilling", table: "CategoryLocalizations"),
            "自我增值"
        )
    }

    func testCategoryLocalizationUsesSimplifiedChineseDrinkWording() {
        let originalLanguage = AppLanguagePreference.language
        defer { AppLanguagePreference.language = originalLanguage }

        AppLanguagePreference.language = .simplifiedChinese
        XCTAssertEqual(
            AppLocalization.string(key: "category.expense.coffee", table: "CategoryLocalizations"),
            "饮品"
        )
    }

    func testCategoryPickerPlaceholderVisibilityByMode() {
        XCTAssertFalse(CategoryPickerMode.transaction(.expense).showsPlaceholderOption)
        XCTAssertFalse(CategoryPickerMode.transaction(.income).showsPlaceholderOption)
        XCTAssertTrue(CategoryPickerMode.budgetExpense.showsPlaceholderOption)
    }

    func testCategoryPickerExpenseGroupingOrder() {
        let order = CategoryPickerMode.transaction(.expense).preferredCategoryOrder
        XCTAssertEqual(order.prefix(5), [
            "category.expense.food",
            "category.expense.groceries",
            "category.expense.dining",
            "category.expense.coffee",
            "category.expense.home"
        ])
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
            "category.expense.education",
            "category.expense.upskilling",
            "category.expense.pet",
            "category.expense.travel",
            "category.expense.groceries",
            "category.expense.dining",
            "category.expense.coffee",
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
    func testFoodAndDiningUseUpdatedIconMapping() async throws {
        let container = try ModelContainerConfiguration.createTestContainer()
        let context = container.mainContext
        let seeder = DefaultDataSeeder(context: context)
        try await seeder.seedIfNeeded()

        let categories = try context.fetch(FetchDescriptor<Flux.Category>())
        let food = categories.first { $0.nameKey == "category.expense.food" }
        let dining = categories.first { $0.nameKey == "category.expense.dining" }

        XCTAssertEqual(food?.icon, "carrot.fill")
        XCTAssertEqual(dining?.icon, "fork.knife")
    }
}
