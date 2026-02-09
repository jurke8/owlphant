import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearanceMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light:
            return L10n.tr("appearance.light.title")
        case .dark:
            return L10n.tr("appearance.dark.title")
        case .system:
            return L10n.tr("appearance.system.title")
        }
    }

    var subtitle: String {
        switch self {
        case .light:
            return L10n.tr("appearance.light.subtitle")
        case .dark:
            return L10n.tr("appearance.dark.subtitle")
        case .system:
            return L10n.tr("appearance.system.subtitle")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}
