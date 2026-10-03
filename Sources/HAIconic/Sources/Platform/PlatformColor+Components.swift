#if os(macOS)
import AppKit
#else
import UIKit
#endif

public extension UIColor {
    /// The color's sRGB components, resolved against the current appearance. Nil for a color that has none
    /// to read, such as a pattern color.
    var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        #if os(macOS)
        guard let color = resolvedSRGB else { return nil }
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
        #else
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return (red, green, blue, alpha)
        #endif
    }

    #if !os(watchOS)
    /// A color that follows the light or dark appearance of wherever it is drawn.
    static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        #if os(macOS)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
        #else
        return UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
        #endif
    }
    #endif
}
