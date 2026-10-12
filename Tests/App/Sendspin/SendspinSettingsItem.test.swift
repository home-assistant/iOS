@testable import HomeAssistant
import Shared
import Testing

struct SendspinSettingsItemTests {
    /// The row has to lead somewhere: without that case the entry appears in settings and opens
    /// nothing.
    @MainActor @Test func theEntryOpensTheSendspinScreen() {
        #expect(!String(describing: SettingsItem.sendspin.destinationView).isEmpty)
    }

    @Test func theEntryIsVisibleEverywhere() {
        #expect(SettingsItem.sendspin.isVisible)
        #expect(SettingsItem.sendspin.subtitle == nil)
        #expect(SettingsItem.sendspin.title == L10n.Settings.Sendspin.title)
    }

    /// People look for this by the protocol's name and by the app it works with.
    @Test func isFoundByTheProtocolAndMusicAssistant() {
        #expect(SettingsItem.sendspin.matches(searchQuery: "sendspin"))
        #expect(SettingsItem.sendspin.matches(searchQuery: "music assistant"))
        #expect(SettingsItem.sendspin.matches(searchQuery: L10n.Settings.Sendspin.PairingToken.title))
        #expect(!SettingsItem.appLabs.matches(searchQuery: "sendspin"))
    }
}
