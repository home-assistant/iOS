import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public extension Color {
    static let haPrimary = Color(.sRGB, red: 0x00 / 255, green: 0x9A / 255, blue: 0xC7 / 255, opacity: 1)

    static let track = Color(.displayP3, red: 0, green: 0, blue: 0, opacity: 0.12)

    static let onSurface = adaptive(
        light: Color(.sRGB, red: 0x1A / 255, green: 0x1C / 255, blue: 0x1E / 255, opacity: 0.16),
        dark: Color(.sRGB, red: 0xE2 / 255, green: 0xE2 / 255, blue: 0xE5 / 255, opacity: 0.16)
    )

    static let tileBorder = adaptive(
        light: Color(.displayP3, red: 0xE0 / 255, green: 0xE0 / 255, blue: 0xE0 / 255, opacity: 1),
        dark: Color(.displayP3, red: 0x34 / 255, green: 0x37 / 255, blue: 0x37 / 255, opacity: 1)
    )

    static let haColorBorderPrimaryQuiet = adaptive(
        light: Color(.sRGB, red: 0xB9 / 255, green: 0xE6 / 255, blue: 0xFC / 255, opacity: 1),
        dark: Color(.sRGB, red: 0x00 / 255, green: 0x9A / 255, blue: 0xC7 / 255, opacity: 1)
    )

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
    static let haPrimary = UIColor(red: 0x00 / 255, green: 0x9A / 255, blue: 0xC7 / 255, alpha: 1)
}
#endif
