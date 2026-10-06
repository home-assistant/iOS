import Foundation
import UIKit

/// Parses the colour notations the Home Assistant frontend hands back.
///
/// Anything captured from a live web view has already been through the browser's own resolution, so
/// it arrives as a canonical `rgb()`/`rgba()` string. Hex and the `transparent` keyword are accepted
/// too because theme definitions are also read straight from `color.globals.ts`, which writes both.
public extension UIColor {
    convenience init?(cssColorString string: String) {
        let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.caseInsensitiveCompare("transparent") == .orderedSame {
            self.init(white: 0, alpha: 0)
            return
        }
        if value.hasPrefix("#") {
            guard let parsed = UIColor(rgbaString: value) else { return nil }
            self.init(cgColor: parsed.cgColor)
            return
        }
        guard let components = Self.rgbComponents(from: value) else { return nil }
        self.init(
            red: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        )
    }

    /// Splits an `rgb()`/`rgba()` string into unit components, or `nil` if it is not one.
    ///
    /// Both the legacy comma form (`rgb(1, 2, 3)`) and the modern space form (`rgb(1 2 3 / 0.5)`)
    /// are accepted: WebKit emits the comma form today, but the space form is what the CSS Color 4
    /// serialisation rules move towards, and a theme author can write either.
    private static func rgbComponents(
        from value: String
    ) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        let lowercased = value.lowercased()
        guard lowercased.hasPrefix("rgb"), let open = value.firstIndex(of: "("), value.hasSuffix(")") else {
            return nil
        }
        let inner = value[value.index(after: open) ..< value.index(before: value.endIndex)]
        // Each component carries its own notation — `rgba(0, 0, 0, 50%)` is legal — so whether it was
        // written as a percentage is tracked per component rather than for the string as a whole.
        let components = inner
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .compactMap { part -> (value: CGFloat, isPercentage: Bool)? in
                if part.hasSuffix("%") {
                    return Double(part.dropLast()).map { (CGFloat($0 / 100), true) }
                }
                return Double(part).map { (CGFloat($0), false) }
            }
        guard components.count >= 3 else { return nil }

        func clamp(_ component: CGFloat) -> CGFloat {
            min(1, max(0, component))
        }
        func channel(_ index: Int) -> CGFloat {
            let component = components[index]
            // A percentage was already normalised to 0...1 above; a raw channel number is 0...255.
            return clamp(component.isPercentage ? component.value : component.value / 255)
        }
        return (
            red: channel(0),
            green: channel(1),
            blue: channel(2),
            alpha: components.count > 3 ? clamp(components[3].value) : 1
        )
    }
}
