import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum AppTheme {
    static let backgroundTop = dynamicColor(light: (0.97, 0.95, 0.92), dark: (0.13, 0.14, 0.15))
    static let backgroundBottom = dynamicColor(light: (0.93, 0.90, 0.85), dark: (0.09, 0.10, 0.11))
    static let surface = dynamicColor(light: (1.0, 0.97, 0.93), dark: (0.18, 0.19, 0.20))
    static let surfaceAlt = dynamicColor(light: (0.94, 0.90, 0.84), dark: (0.23, 0.24, 0.25))
    static let stroke = dynamicColor(light: (0.88, 0.82, 0.75), dark: (0.34, 0.35, 0.36))
    static let tint = dynamicColor(light: (0.18, 0.48, 0.42), dark: (0.34, 0.72, 0.63))
    static let accent = dynamicColor(light: (0.77, 0.56, 0.28), dark: (0.88, 0.71, 0.43))
    static let text = dynamicColor(light: (0.13, 0.09, 0.07), dark: (0.93, 0.91, 0.88))
    static let muted = dynamicColor(light: (0.40, 0.35, 0.31), dark: (0.71, 0.69, 0.66))

    private static func dynamicColor(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
#if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            let components = traitCollection.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat(components.0),
                green: CGFloat(components.1),
                blue: CGFloat(components.2),
                alpha: 1
            )
        })
#else
        Color(red: light.0, green: light.1, blue: light.2)
#endif
    }
}
