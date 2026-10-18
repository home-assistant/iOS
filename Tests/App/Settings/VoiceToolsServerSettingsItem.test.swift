@testable import HomeAssistant
import Shared
import Testing

struct VoiceToolsServerSettingsItemTests {
    /// The row has to lead somewhere: without that case the entry appears in settings and opens
    /// nothing.
    @MainActor @Test func theEntryOpensTheVoiceToolsServerScreen() {
        #expect(!String(describing: SettingsItem.voiceToolsServer.destinationView).isEmpty)
    }

    @Test func theEntryIsVisibleEverywhere() {
        #expect(SettingsItem.voiceToolsServer.isVisible)
        #expect(SettingsItem.voiceToolsServer.subtitle == nil)
        #expect(SettingsItem.voiceToolsServer.title == L10n.Settings.VoiceToolsServer.title)
    }
}
