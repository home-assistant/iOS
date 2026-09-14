@testable import HomeAssistant
import Shared
import Testing

struct AppLabsViewTests {
    @Test func appLabsIsHiddenOutsideTestFlight() {
        let previousIsTestFlight = Current.isTestFlight
        defer { Current.isTestFlight = previousIsTestFlight }

        Current.isTestFlight = false
        #expect(!SettingsItem.appLabs.isVisible)
        #expect(!AppLabsFeature.macNativeSidebar.isEnabled)

        Current.isTestFlight = true
        #expect(SettingsItem.appLabs.isVisible)
    }

    /// The voice tools server lives inside App Labs rather than in the root settings list, so
    /// searching for it — including the protocol Home Assistant calls it — has to surface App Labs.
    @Test func appLabsIsFoundByTheVoiceToolsServer() {
        let previousIsTestFlight = Current.isTestFlight
        defer { Current.isTestFlight = previousIsTestFlight }
        Current.isTestFlight = true

        #expect(SettingsItem.appLabs.matches(searchQuery: "wyoming"))
        #expect(SettingsItem.appLabs.matches(searchQuery: L10n.Settings.VoiceToolsServer.title))
        #expect(SettingsItem.appLabs.matches(searchQuery: L10n.Settings.VoiceToolsServer.Voices.title))
    }
}
