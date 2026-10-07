import Foundation
import SwiftUI
import UIKit

public extension FrontendColors {
    /// The resolved color for the light (default) theme, if the CSS value can be parsed.
    var lightColor: Color? {
        Self.color(from: lightValue, scheme: .light)
    }

    /// The resolved color for the dark theme, falling back to the light value
    /// when there is no dark override.
    var darkColor: Color? {
        Self.color(from: darkValue ?? lightValue, scheme: .dark)
    }

    /// A color that adapts to the current interface style.
    ///
    /// Values that reference custom properties defined outside of
    /// `color.globals.ts` (for example the `--ha-color-*` core palette) cannot
    /// be resolved and fall back to `.clear`.
    var color: Color {
        Self.adaptiveColor(light: lightColor, dark: darkColor)
    }
}

private extension FrontendColors {
    static func color(from raw: String?, scheme: ColorScheme, visited: Set<FrontendColors> = []) -> Color? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        if raw == "transparent" {
            return .clear
        }
        if raw.hasPrefix("#") {
            return UIColor(rgbaString: raw).map { Color($0) }
        }
        if let color = rgbColor(from: raw) {
            return color
        }
        if raw.lowercased().hasPrefix("var(") {
            return resolveReference(raw, scheme: scheme, visited: visited)
        }
        return nil
    }

    static func resolveReference(
        _ raw: String,
        scheme: ColorScheme,
        visited: Set<FrontendColors>
    ) -> Color? {
        guard let open = raw.firstIndex(of: "("), raw.hasSuffix(")") else {
            return nil
        }
        let inner = raw[raw.index(after: open) ..< raw.index(before: raw.endIndex)]
        let arguments = splitTopLevel(String(inner))
        guard let name = arguments.first?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
            return nil
        }
        let fallback = arguments.count > 1
            ? arguments.dropFirst().joined(separator: ",").trimmingCharacters(in: .whitespaces)
            : nil

        if let referenced = FrontendColors(rawValue: name), !visited.contains(referenced) {
            let referencedRaw = scheme == .dark
                ? (referenced.darkValue ?? referenced.lightValue)
                : referenced.lightValue
            if let resolved = color(from: referencedRaw, scheme: scheme, visited: visited.union([referenced])) {
                return resolved
            }
        }
        if let fallback {
            return color(from: fallback, scheme: scheme, visited: visited)
        }
        return nil
    }

    static func rgbColor(from value: String) -> Color? {
        guard let regex = rgbFunctionRegex else {
            return nil
        }
        let range = NSRange(value.startIndex ..< value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range) else {
            return nil
        }
        func component(at index: Int) -> Double? {
            guard let range = Range(match.range(at: index), in: value) else {
                return nil
            }
            return Double(value[range])
        }
        guard let red = component(at: 1), let green = component(at: 2), let blue = component(at: 3) else {
            return nil
        }
        let alpha = component(at: 4) ?? 1
        return Color(
            .sRGB,
            red: red / 255,
            green: green / 255,
            blue: blue / 255,
            opacity: min(max(alpha, 0), 1)
        )
    }

    static func splitTopLevel(_ string: String) -> [String] {
        var result: [String] = []
        var depth = 0
        var current = ""
        for character in string {
            switch character {
            case "(":
                depth += 1
                current.append(character)
            case ")":
                depth -= 1
                current.append(character)
            case "," where depth == 0:
                result.append(current)
                current = ""
            default:
                current.append(character)
            }
        }
        result.append(current)
        return result
    }

    static func adaptiveColor(light: Color?, dark: Color?) -> Color {
        #if os(watchOS)
        return dark ?? light ?? .clear
        #else
        let lightColor = light ?? dark ?? .clear
        let darkColor = dark ?? light ?? .clear
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(darkColor) : UIColor(lightColor)
        })
        #endif
    }

    static let rgbFunctionRegex = try? NSRegularExpression(
        pattern: #"^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([0-9.]+)\s*)?\)$"#,
        options: [.caseInsensitive]
    )
}
