import Foundation

enum AppLocalization {
    nonisolated private static var selectedLanguage: AppLanguage {
        AppLanguagePreference.language
    }

    nonisolated static var locale: Locale {
        if let localeIdentifier = selectedLanguage.localeIdentifier {
            return Locale(identifier: localeIdentifier)
        }
        return .autoupdatingCurrent
    }

    nonisolated private static var bundle: Bundle {
        guard let localeIdentifier = selectedLanguage.localeIdentifier else {
            return .main
        }

        for identifier in localizationCandidates(for: localeIdentifier) {
            if let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
               let localizedBundle = Bundle(path: path) {
                return localizedBundle
            }
        }

        return .main
    }

    nonisolated private static func localizationCandidates(for localeIdentifier: String) -> [String] {
        var candidates = [localeIdentifier]
        let separators = CharacterSet(charactersIn: "-_")
        let components = localeIdentifier.components(separatedBy: separators)
        let normalized = localeIdentifier.lowercased()

        if normalized.hasPrefix("zh-hk") || normalized.hasPrefix("zh-tw") {
            candidates.append("zh-Hant")
        }
        if normalized.hasPrefix("zh-hans") {
            candidates.append("zh-Hans")
        }

        if let languageCode = components.first, languageCode != localeIdentifier {
            candidates.append(languageCode)
        }

        // Keep original order while removing duplicates.
        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    nonisolated static func string(
        _ key: String,
        defaultValue: String,
        table: String? = nil
    ) -> String {
        bundle.localizedString(forKey: key, value: defaultValue, table: table)
    }

    nonisolated static func string(_ key: String, table: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: table)
    }

    nonisolated static func formatted(
        _ key: String,
        defaultValue: String,
        table: String? = nil,
        _ arguments: CVarArg...
    ) -> String {
        let format = string(key, defaultValue: defaultValue, table: table)
        return String(format: format, locale: locale, arguments: arguments)
    }

    nonisolated static func string(
        key: String,
        defaultValue: String,
        table: String? = nil
    ) -> String {
        string(key, defaultValue: defaultValue, table: table)
    }

    nonisolated static func string(
        key: String,
        table: String
    ) -> String {
        string(key, table: table)
    }
}
