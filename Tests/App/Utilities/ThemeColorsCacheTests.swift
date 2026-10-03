@testable import HomeAssistant
import Shared
import Testing
import UIKit

/// The colours the frontend reports are cached per appearance and read back for the same one.
@Suite(.serialized)
struct ThemeColorsCacheTests {
    @Test func cachesTheReportedColorsForTheAppearanceTheyCameFrom() {
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let light = UITraitCollection(userInterfaceStyle: .light)
        let previousDark = prefs.object(forKey: "cachedThemeColors-dark")
        let previousLight = prefs.object(forKey: "cachedThemeColors-light")
        defer {
            prefs.set(previousDark, forKey: "cachedThemeColors-dark")
            prefs.set(previousLight, forKey: "cachedThemeColors-light")
        }

        ThemeColors.updateCache(with: ["--primary-color": " #ff0000 "], for: dark)
        ThemeColors.updateCache(with: ["--primary-color": "#00ff00"], for: light)

        #expect(ThemeColors.cachedThemeColors(for: dark)[.primaryColor] == UIColor(hex: "#ff0000"))
        #expect(ThemeColors.cachedThemeColors(for: light)[.primaryColor] == UIColor(hex: "#00ff00"))
    }
}
