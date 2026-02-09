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
            return "Light mode"
        case .dark:
            return "Dark mode"
        case .system:
            return "Device default"
        }
    }

    var subtitle: String {
        switch self {
        case .light:
            return "Always use the light appearance."
        case .dark:
            return "Always use the dark appearance."
        case .system:
            return "Match your iPhone appearance setting."
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
