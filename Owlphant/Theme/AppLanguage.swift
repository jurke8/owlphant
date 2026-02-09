import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case croatian = "hr"

    nonisolated static let storageKey = "appLanguage"
    nonisolated static let defaultValue: AppLanguage = .english

    var id: String { rawValue }

    nonisolated var localeIdentifier: String {
        rawValue
    }

    var title: String {
        switch self {
        case .english:
            return L10n.tr("language.english")
        case .croatian:
            return L10n.tr("language.croatian")
        }
    }
}
