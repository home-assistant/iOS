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

    // MARK: - Status

    //
    // The frontend's four status colours, `--info-color` / `--warning-color` / `--error-color` /
    // `--success-color` from `color.globals.ts`. They are spelled out here, like `haWarning` above,
    // rather than read from ``FrontendColors`` so this file stays free of the UIKit-only CSS
    // resolver and keeps building for watchOS. None of the four has a dark override in the
    // frontend, so each is a single value.
    //
    // Note these are *not* `haWarning`, which is the louder fill `ha-button variant="warning"` uses.

    /// The frontend's `--info-color`, for informational alerts and badges.
    static var haInfoColor: Color { srgb(0x03, 0x9B, 0xE5, opacity: 1) }

    /// The frontend's `--warning-color`, for states the user should look at but that are not failures.
    static var haWarningColor: Color { srgb(0xFF, 0xA6, 0x00, opacity: 1) }

    /// The frontend's `--error-color`, for failures.
    static var haErrorColor: Color { srgb(0xDB, 0x44, 0x37, opacity: 1) }

    /// The frontend's `--success-color`, for completed or healthy states.
    static var haSuccessColor: Color { srgb(0x43, 0xA0, 0x47, opacity: 1) }

    // MARK: - Lines and quiet fills

    /// The frontend's `--divider-color`, also its `--outline-color`: the hairline between rows and
    /// around outlined controls.
    static var haDivider: Color {
        adaptive(
            light: srgb(0, 0, 0, opacity: 0.12),
            dark: srgb(0xE1, 0xE1, 0xE1, opacity: 0.12)
        )
    }

    /// The frontend's `--ha-color-fill-neutral-quiet-resting` (`neutral-95` on light, `neutral-05`
    /// on dark): the unobtrusive fill behind a section header.
    static var haNeutralQuietFill: Color {
        adaptive(
            light: srgb(0xF3, 0xF3, 0xF3, opacity: 1),
            dark: srgb(0x14, 0x14, 0x14, opacity: 1)
        )
    }

    /// The frontend's `--secondary-background-color`: the recessed track a bar or slider fills.
    static var haSecondaryBackground: Color {
        adaptive(
            light: srgb(0xE5, 0xE5, 0xE5, opacity: 1),
            dark: srgb(0x28, 0x28, 0x28, opacity: 1)
        )
    }

    /// The frontend's `--card-background-color`: the surface a card or badge sits on.
    static var haCardBackground: Color {
        adaptive(
            light: srgb(0xFF, 0xFF, 0xFF, opacity: 1),
            dark: srgb(0x1C, 0x1C, 0x1C, opacity: 1)
        )
    }

    /// The frontend's `--ha-button-primary-light-color` (`#4082a040`): a translucent primary tint for
    /// hover states. The frontend declares it once, in its dark theme block, so it is the same in
    /// both appearances here too.
    static var haPrimaryLightFill: Color { srgb(0x40, 0x82, 0xA0, opacity: 0x40 / 255) }

    /// The frontend's `--disabled-color`: the unfilled part of a control's track, and the fill of a
    /// control that is off. The `ha-control-*` components draw it at 20%.
    static var haDisabled: Color {
        adaptive(
            light: srgb(0xBD, 0xBD, 0xBD, opacity: 1),
            dark: srgb(0x46, 0x46, 0x46, opacity: 1)
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
