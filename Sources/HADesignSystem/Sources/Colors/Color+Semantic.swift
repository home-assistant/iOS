import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public extension ShapeStyle where Self == Color {
    static var haPrimary: Color { srgb(0x00, 0x9A, 0xC7, opacity: 1) }

    /// The frontend's `--ha-color-fill-warning-loud-resting`: `orange-70` on light, `orange-40` on dark.
    /// The fill `ha-button variant="warning"` uses, for actions that need the user to step in.
    static var haWarning: Color {
        adaptive(
            light: srgb(0xFF, 0x93, 0x42, opacity: 1),
            dark: srgb(0x9D, 0x38, 0x00, opacity: 1)
        )
    }

    static var track: Color { displayP3(0, 0, 0, opacity: 0.12) }

    static var onSurface: Color {
        adaptive(
            light: srgb(0x1A, 0x1C, 0x1E, opacity: 0.16),
            dark: srgb(0xE2, 0xE2, 0xE5, opacity: 0.16)
        )
    }

    static var tileBorder: Color {
        adaptive(
            light: displayP3(0xE0, 0xE0, 0xE0, opacity: 1),
            dark: displayP3(0x34, 0x37, 0x37, opacity: 1)
        )
    }

    static var haColorBorderPrimaryQuiet: Color {
        adaptive(
            light: srgb(0xB9, 0xE6, 0xFC, opacity: 1),
            dark: srgb(0x00, 0x9A, 0xC7, opacity: 1)
        )
    }

    /// The card a single widget tile sits on. Mirrors the app's `tileBackground` asset colour,
    /// spelled out here because a widget extension has to draw it without the app's bundle.
    static var widgetTileBackground: Color {
        adaptive(
            light: displayP3(0xFF, 0xFF, 0xFF, opacity: 1),
            dark: displayP3(0x1C, 0x1B, 0x1B, opacity: 1)
        )
    }

    /// The surface behind a whole widget, which the tiles sit on top of. Mirrors the app's
    /// `primaryBackground` asset colour, for the same reason.
    static var widgetPrimaryBackground: Color {
        adaptive(
            light: displayP3(0xFA, 0xFA, 0xFA, opacity: 1),
            dark: displayP3(0x11, 0x10, 0x10, opacity: 1)
        )
    }
}

private func srgb(_ red: Double, _ green: Double, _ blue: Double, opacity: Double) -> Color {
    Color(.sRGB, red: red / 255.0, green: green / 255.0, blue: blue / 255.0, opacity: opacity)
}

private func displayP3(_ red: Double, _ green: Double, _ blue: Double, opacity: Double) -> Color {
    Color(.displayP3, red: red / 255.0, green: green / 255.0, blue: blue / 255.0, opacity: opacity)
}

private func adaptive(light: Color, dark: Color) -> Color {
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

#if canImport(UIKit)
public extension UIColor {
    static let haPrimary = UIColor(red: 0x00 / 255.0, green: 0x9A / 255.0, blue: 0xC7 / 255.0, alpha: 1)
}
#endif
