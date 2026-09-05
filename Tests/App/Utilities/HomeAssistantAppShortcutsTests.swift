import AppIntents
@testable import HomeAssistant
import Testing

struct HomeAssistantAppShortcutsTests {
    /// Apple caps an app at ten, and `appintentsmetadataprocessor` fails the build on the eleventh.
    @Test func staysWithinTheShortcutLimit() {
        guard #available(iOS 17.0, *) else { return }
        #expect(HomeAssistantAppShortcuts.appShortcuts.count == 10)
    }

    @Test func tileColorIsSet() {
        guard #available(iOS 17.0, *) else { return }
        #expect(HomeAssistantAppShortcuts.shortcutTileColor == .lightBlue)
    }
}
