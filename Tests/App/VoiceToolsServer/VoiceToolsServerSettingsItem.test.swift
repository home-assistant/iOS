@testable import HomeAssistant
import SwiftUI
import Testing

/// The settings list builds every destination from `SettingsItem`, so the entry has to resolve to
/// the screen rather than to an empty view.
@MainActor
struct VoiceToolsServerSettingsItemTests {
    @Test func theEntryBuildsItsScreen() {
        _ = SettingsItem.voiceToolsServer.destinationView
    }

    @Test func theEntryIsShownAndNamed() {
        #expect(SettingsItem.voiceToolsServer.isVisible)
        #expect(!SettingsItem.voiceToolsServer.title.isEmpty)
        #expect(SettingsItem.voiceToolsServer.materialIcon == .accountVoiceIcon)
    }

    /// Searching for the protocol Home Assistant calls it has to find the screen, since that is the
    /// word a user setting the integration up will have in mind.
    @Test func theEntryIsFoundByItsProtocolName() {
        #expect(SettingsItem.voiceToolsServer.matches(searchQuery: "wyoming"))
        #expect(SettingsItem.voiceToolsServer.matches(searchQuery: "speech"))
    }
}
