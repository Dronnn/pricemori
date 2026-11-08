import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case english = "en"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case portugueseBrazil = "pt-BR"
    case polish = "pl"
    case russian = "ru"
    case ukrainian = "uk"
    case armenian = "hy"
    case japanese = "ja"
    case vietnamese = "vi"
    case chineseSimplified = "zh-Hans"
    case korean = "ko"
    case italian = "it"
    case dutch = "nl"
    case turkish = "tr"
    case indonesian = "id"

    var id: String { rawValue }

    nonisolated static let storageKey = "appLanguage"

    nonisolated static var selected: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    nonisolated var isSystem: Bool { self == .system }

    nonisolated var locale: Locale {
        switch self {
        case .system: Locale.current
        case .english: Locale(identifier: "en")
        case .german: Locale(identifier: "de")
        case .french: Locale(identifier: "fr")
        case .spanish: Locale(identifier: "es")
        case .portugueseBrazil: Locale(identifier: "pt-BR")
        case .polish: Locale(identifier: "pl")
        case .russian: Locale(identifier: "ru")
        case .ukrainian: Locale(identifier: "uk")
        case .armenian: Locale(identifier: "hy")
        case .japanese: Locale(identifier: "ja")
        case .vietnamese: Locale(identifier: "vi")
        case .chineseSimplified: Locale(identifier: "zh-Hans")
        case .korean: Locale(identifier: "ko")
        case .italian: Locale(identifier: "it")
        case .dutch: Locale(identifier: "nl")
        case .turkish: Locale(identifier: "tr")
        case .indonesian: Locale(identifier: "id")
        }
    }

    /// English dates follow the editorial en-GB order used by the design.
    nonisolated var formattingLocale: Locale {
        self == .english ? Locale(identifier: "en_GB") : locale
    }

    var nativeName: String {
        switch self {
        case .system: L10n.string("System")
        case .english: "English"
        case .german: "Deutsch"
        case .french: "Français"
        case .spanish: "Español"
        case .portugueseBrazil: "Português (Brasil)"
        case .polish: "Polski"
        case .russian: "Русский"
        case .ukrainian: "Українська"
        case .armenian: "Հայերեն"
        case .japanese: "日本語"
        case .vietnamese: "Tiếng Việt"
        case .chineseSimplified: "简体中文"
        case .korean: "한국어"
        case .italian: "Italiano"
        case .dutch: "Nederlands"
        case .turkish: "Türkçe"
        case .indonesian: "Bahasa Indonesia"
        }
    }
}

enum L10n {
    nonisolated static var language: AppLanguage { AppLanguage.selected }

    nonisolated static var locale: Locale { language.locale }

    nonisolated static var formattingLocale: Locale { language.formattingLocale }

    nonisolated static func string(_ key: String) -> String {
        let language = AppLanguage.selected
        guard !language.isSystem else {
            return NSLocalizedString(key, comment: "")
        }
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return key
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    nonisolated static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }
}
