import Foundation
@testable import HomeAssistant
import SharedTesting
import Testing
import UIKit

/// The frontend's theme colors are cached per interface style and parsed when read: CSS `rgb()`
/// strings and hex values both resolve, and missing ones fall back to the app defaults.
///
/// `.sharedState`: the cache lives in the app group preferences.
@Suite(.sharedState)
struct ThemeColorsCacheTests {
    @Test func colorsAreCachedPerInterfaceStyle() {
        let keys = ["cachedThemeColors-light", "cachedThemeColors-dark"]
        let previous = keys.map { prefs.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                prefs.set(value, forKey: key)
            }
        }

        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        for key in keys {
            prefs.removeObject(forKey: key)
        }
        let defaults = ThemeColors.cachedThemeColors(for: light)
        ThemeColors.updateCache(with: [
            ThemeColors.Color.primaryColor.rawValue: " rgb(255, 0, 0) ",
            ThemeColors.Color.appThemeColor.rawValue: "#00FF00",
            ThemeColors.Color.textPrimaryColor.rawValue: 12,
        ], for: light)
        ThemeColors.updateCache(with: [ThemeColors.Color.primaryColor.rawValue: "#0000FF"], for: dark)

        let cachedLight = ThemeColors.cachedThemeColors(for: light)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        cachedLight[.primaryColor].getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(red > 0.9 && green < 0.1 && blue < 0.1)
        cachedLight[.appThemeColor].getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(green > 0.9 && red < 0.1)
        // Not a string, so not cached: the default is used.
        #expect(cachedLight[.textPrimaryColor] == defaults[.textPrimaryColor])

        let cachedDark = ThemeColors.cachedThemeColors(for: dark)
        cachedDark[.primaryColor].getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(blue > 0.9 && red < 0.1)
        #expect(cachedDark[.appHeaderBackgroundColor] == defaults[.appHeaderBackgroundColor])

        // An unspecified style reads the light cache.
        let unspecified = ThemeColors.cachedThemeColors(for: UITraitCollection(userInterfaceStyle: .unspecified))
        unspecified[.primaryColor].getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(red > 0.9)
    }
}
