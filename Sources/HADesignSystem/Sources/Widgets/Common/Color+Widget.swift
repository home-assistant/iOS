#if !os(watchOS)
import SwiftUI
import UIKit

/// The widget surfaces, mirroring the app's `tileBackground` and `primaryBackground` asset colours.
///
/// Spelled out here rather than read from an asset catalogue: the design system ships as a package
/// with no bundle of its own, and a widget extension has to be able to draw these without the app.
public extension ShapeStyle where Self == Color {
    /// The card a single widget tile sits on.
    static var widgetTileBackground: Color {
        widgetAdaptive(
            light: widgetDisplayP3(0xFF, 0xFF, 0xFF),
            dark: widgetDisplayP3(0x1C, 0x1B, 0x1B)
        )
    }

    /// The surface behind a whole widget, which the tiles sit on top of.
    static var widgetPrimaryBackground: Color {
        widgetAdaptive(
            light: widgetDisplayP3(0xFA, 0xFA, 0xFA),
            dark: widgetDisplayP3(0x11, 0x10, 0x10)
        )
    }
}

private func widgetDisplayP3(_ red: Double, _ green: Double, _ blue: Double) -> Color {
    Color(.displayP3, red: red / 255.0, green: green / 255.0, blue: blue / 255.0, opacity: 1)
}

private func widgetAdaptive(light: Color, dark: Color) -> Color {
    Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
    })
}
#endif
