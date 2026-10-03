import Foundation
import Shared
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public struct ThemeColors: Codable {
    public enum Color: String, CaseIterable {
        // these are in WebSocketBridge.js in this repo (we inject it)
        case appHeaderBackgroundColor = "--app-header-background-color"
        case appThemeColor = "--app-theme-color"
        case primaryBackgroundColor = "--primary-background-color"
        case textPrimaryColor = "--text-primary-color"
        case primaryColor = "--primary-color"
    }

    // we defer the hex parsing in case we have a clientside bug that can improve it later, so we don't need
    // to write a migration when the parsing logic improves
    private let values: [Color.RawValue: String]

    subscript(_ color: Color) -> UIColor {
        if let value = values[color.rawValue] {
            return UIColor(rgbString: value) ?? UIColor(hex: value)
        } else {
            return color.default
        }
    }

    enum InterfaceStyle {
        case light
        case dark

        var userDefaultsKey: String {
            switch self {
            case .light: return "cachedThemeColors-light"
            case .dark: return "cachedThemeColors-dark"
            }
        }

        #if os(macOS)
        init(appearance: NSAppearance) {
            self = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
        }
        #else
        init(traitCollection: UITraitCollection) {
            switch traitCollection.userInterfaceStyle {
            case .dark: self = .dark
            case .light: self = .light
            default: self = .light
            }
        }
        #endif
    }

    #if os(macOS)
    static func cachedThemeColors(for appearance: NSAppearance) -> ThemeColors {
        cachedThemeColors(for: InterfaceStyle(appearance: appearance))
    }

    static func updateCache(with messageBody: [String: Any], for appearance: NSAppearance) {
        updateCache(with: messageBody, for: InterfaceStyle(appearance: appearance))
    }
    #else
    static func cachedThemeColors(for traitCollection: UITraitCollection) -> ThemeColors {
        cachedThemeColors(for: InterfaceStyle(traitCollection: traitCollection))
    }

    static func updateCache(
        with messageBody: [String: Any],
        for traitCollection: UITraitCollection
    ) {
        updateCache(with: messageBody, for: InterfaceStyle(traitCollection: traitCollection))
    }
    #endif

    private static func cachedThemeColors(for style: InterfaceStyle) -> ThemeColors {
        let cached = prefs.object(forKey: style.userDefaultsKey) as? [Color.RawValue: String] ?? [:]
        Current.Log.verbose("loaded cached colors \(cached)")
        return ThemeColors(values: cached)
    }

    private static func updateCache(with messageBody: [String: Any], for style: InterfaceStyle) {
        func rawValue(for key: Color) -> String? {
            messageBody[key.rawValue]
                .flatMap { $0 as? String }?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var dictionary: [Color.RawValue: String] = [:]
        for color in Color.allCases {
            dictionary[color.rawValue] = rawValue(for: color)
        }
        Current.Log.verbose("caching color values \(dictionary)")
        prefs.set(dictionary, forKey: style.userDefaultsKey)
    }
}

private extension ThemeColors.Color {
    var `default`: UIColor {
        switch self {
        case .appHeaderBackgroundColor: return UIColor(red: 0.01, green: 0.66, blue: 0.96, alpha: 1.0)
        case .primaryBackgroundColor: return UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
        case .primaryColor: return UIColor.white
        case .textPrimaryColor: return UIColor.white
        case .appThemeColor: return UIColor(red: 0.01, green: 0.66, blue: 0.96, alpha: 1.0)
        }
    }
}
