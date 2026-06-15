import Foundation
import SwiftUI

private let kAppLanguageCode = "flux.appLanguageCode"
private let kAppThemeCode = "flux.appThemeCode"

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese

    var id: Self { self }

    nonisolated static func from(rawValue: String?) -> AppLanguage {
        guard let rawValue else {
            return .system
        }
        guard let language = AppLanguage(rawValue: rawValue) else {
            return .system
        }
        return language
    }

    nonisolated var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        }
    }

    var displayName: String {
        switch self {
        case .system:
            return AppLocalization.string(
                "settings.language.system",
                defaultValue: "System Default"
            )
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        }
    }
}

enum AppLanguagePreference {
    nonisolated static let storageKey = kAppLanguageCode

    nonisolated static var language: AppLanguage {
        get {
            AppLanguage.from(rawValue: UserDefaults.standard.string(forKey: storageKey))
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: Self { self }

    static func from(rawValue: String?) -> AppTheme {
        guard let rawValue else {
            return .system
        }
        return AppTheme(rawValue: rawValue) ?? .system
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system:
            return AppLocalization.string(
                "settings.theme.system",
                defaultValue: "System"
            )
        case .light:
            return AppLocalization.string(
                "settings.theme.light",
                defaultValue: "Light"
            )
        case .dark:
            return AppLocalization.string(
                "settings.theme.dark",
                defaultValue: "Dark"
            )
        }
    }

    var systemImage: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
}

enum AppThemePreference {
    static let storageKey = kAppThemeCode

    static var theme: AppTheme {
        get {
            AppTheme.from(rawValue: UserDefaults.standard.string(forKey: storageKey))
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}
