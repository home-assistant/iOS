@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Renders the CarPlay troubleshooting screen for each Assist playback strategy it can start from.
@Suite(.sharedState)
@MainActor
struct CarPlayTroubleshootingSettingsViewTests {
    @Test(arguments: CarPlayAssistTTSPlaybackStrategy.allCases)
    func rendersTheCurrentPlaybackStrategy(strategy: CarPlayAssistTTSPlaybackStrategy) {
        let settings = PrivateSettingsStore()
        defer { settings.restore() }
        var debugSettings = Current.settingsStore.carPlayAssistDebugSettings
        debugSettings.ttsPlaybackStrategy = strategy
        Current.settingsStore.carPlayAssistDebugSettings = debugSettings

        let host = CarPlaySwiftUIHost(NavigationStack { CarPlayTroubleshootingSettingsView() })
        defer { host.close() }

        #expect(Current.settingsStore.carPlayAssistDebugSettings.ttsPlaybackStrategy == strategy)
    }
}
