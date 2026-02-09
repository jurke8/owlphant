import Foundation

enum L10n {
    nonisolated static func tr(_ key: String) -> String {
        let language = currentLanguage
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: key, table: "Localizable")
        }
        return Bundle.main.localizedString(forKey: key, value: key, table: "Localizable")
    }

    nonisolated static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: tr(key), locale: Locale(identifier: currentLanguage.localeIdentifier), arguments: args)
    }

    nonisolated private static var currentLanguage: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.defaultValue.rawValue
        return AppLanguage(rawValue: raw) ?? .defaultValue
    }
}
