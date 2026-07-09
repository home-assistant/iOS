import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public extension Color {
    static let haPrimary = srgb(0x00, 0x9A, 0xC7, opacity: 1)

    static let track = displayP3(0, 0, 0, opacity: 0.12)

    static let onSurface = adaptive(
        light: srgb(0x1A, 0x1C, 0x1E, opacity: 0.16),
        dark: srgb(0xE2, 0xE2, 0xE5, opacity: 0.16)
    )

    static let tileBorder = adaptive(
        light: displayP3(0xE0, 0xE0, 0xE0, opacity: 1),
        dark: displayP3(0x34, 0x37, 0x37, opacity: 1)
    )

    static let haColorBorderPrimaryQuiet = adaptive(
        light: srgb(0xB9, 0xE6, 0xFC, opacity: 1),
        dark: srgb(0x00, 0x9A, 0xC7, opacity: 1)
    )

    private static func srgb(_ red: Double, _ green: Double, _ blue: Double, opacity: Double) -> Color {
        Color(.sRGB, red: red / 255.0, green: green / 255.0, blue: blue / 255.0, opacity: opacity)
    }

    private static func displayP3(_ red: Double, _ green: Double, _ blue: Double, opacity: Double) -> Color {
        Color(.displayP3, red: red / 255.0, green: green / 255.0, blue: blue / 255.0, opacity: opacity)
    }

    private static func adaptive(light: Color, dark: Color) -> Color {
        #if os(watchOS)
        return dark
        #elseif canImport(UIKit)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        return light
        #endif
    }
}

#if canImport(UIKit)
public extension UIColor {
    static let haPrimary = UIColor(red: 0x00 / 255.0, green: 0x9A / 255.0, blue: 0xC7 / 255.0, alpha: 1)
}
#endif
