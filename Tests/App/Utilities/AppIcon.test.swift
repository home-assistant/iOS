@testable import HomeAssistant
@testable import Shared
import Testing

struct AppIconTests {
    @Test func testAllIconsHaveLocalizedTitles() async throws {
        #expect(AppIcon.allCases.count == 25)

        for icon in AppIcon.allCases {
            #expect(icon.title.isEmpty == false, "\(icon.rawValue) should have a localized title")
        }
    }

    @Test func testDarkIconUsesSharedDarkModeAssetForSupportedIcons() async throws {
        #expect(AppIcon.Release.darkIcon == "icon-dark-mode")
        #expect(AppIcon.Beta.darkIcon == "icon-dark-mode")
        #expect(AppIcon.White.darkIcon == "icon-dark-mode")
    }

    @Test func testDarkIconUsesPerIconAssetForNonDefaultDarkModeIcons() async throws {
        #expect(AppIcon.Dev.darkIcon == "icon-dev")
        #expect(AppIcon.FireOrange.darkIcon == "icon-fire-orange")
        #expect(AppIcon.BiPride.darkIcon == "icon-bi_pride")
    }

    @Test func testDebugConfigurationSelectsDevAsDefaultIcon() async throws {
        #expect(Current.appConfiguration == .debug)
        #expect(AppIcon.Dev.isDefault)
        #expect(AppIcon.Dev.iconName == nil)

        #expect(AppIcon.Release.isDefault == false)
        #expect(AppIcon.Release.iconName == AppIcon.Release.rawValue)
    }
}
