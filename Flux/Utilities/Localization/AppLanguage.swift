import Foundation

private let kAppLanguageCode = "flux.appLanguageCode"

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese

    var id: Self { self }

    static func from(rawValue: String?) -> AppLanguage {
        guard let rawValue else {
            return .system
        }
        guard let language = AppLanguage(rawValue: rawValue) else {
            return .system
        }
        return language
    }

    var localeIdentifier: String? {
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
    static let storageKey = kAppLanguageCode

    static var language: AppLanguage {
        get {
            AppLanguage.from(rawValue: UserDefaults.standard.string(forKey: storageKey))
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}
