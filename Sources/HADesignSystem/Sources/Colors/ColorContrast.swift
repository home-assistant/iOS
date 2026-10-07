#if !os(watchOS)
import SwiftUI
import UIKit

/// The frontend's colour-contrast maths, from `common/color/rgb.ts`.
///
/// Two components need it and must agree: ``HALabel`` picks a legible text colour for a tinted chip
/// with `getContrastedColorHex`, and ``HAQRCode`` uses both that and `getRGBContrastRatio` to keep a
/// themed code scannable. Kept apart from either so it can be tested as the arithmetic it is.
public enum ColorContrast {
    /// The WCAG non-text minimum, and the frontend's `MIN_CONTRAST_RATIO`. Below this a QR code
    /// stops being reliably scannable.
    public static let minimumRatio: Double = 3

    /// WCAG relative luminance — the perceptual brightness of a colour, weighted towards green
    /// because the eye is.
    public static func relativeLuminance(_ color: Color) -> Double? {
        guard let (red, green, blue) = components(of: color) else {
            return nil
        }
        return relativeLuminance(red: red, green: green, blue: blue)
    }

    static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// How far apart two colours read, from 1 (identical) to 21 (black on white).
    public static func ratio(_ first: Color, _ second: Color) -> Double? {
        guard let firstLuminance = relativeLuminance(first),
              let secondLuminance = relativeLuminance(second) else {
            return nil
        }
        return ratio(firstLuminance, secondLuminance)
    }

    static func ratio(_ firstLuminance: Double, _ secondLuminance: Double) -> Double {
        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Black or white, whichever reads better on `background` — the frontend's
    /// `getContrastedColorHex`, which switches at a luminance of 0.5 rather than at the ratio.
    ///
    /// Returns the platform label colour when the colour has no RGB components to read, which a
    /// dynamic or pattern colour may not.
    public static func contrastingForeground(on background: Color) -> Color {
        guard let luminance = relativeLuminance(background) else {
            return Color(uiColor: .label)
        }
        return luminance > 0.5 ? .black : .white
    }

    private static func components(of color: Color) -> (Double, Double, Double)? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        return (Double(red), Double(green), Double(blue))
    }
}
#endif
