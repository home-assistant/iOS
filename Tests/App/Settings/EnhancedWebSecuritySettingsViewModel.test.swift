@testable import HomeAssistant
@testable import Shared
import Testing

// Serialized: the tests mutate process-wide app-group defaults through `Current.settingsStore`.
@Suite(.serialized)
@MainActor
struct EnhancedWebSecuritySettingsViewModelTests {
    @Test func togglingOnStoresTheSetting() {
        withStoredSetting(false) {
            let viewModel = EnhancedWebSecuritySettingsViewModel(isRelevant: true)

            viewModel.enabled.wrappedValue = true

            #expect(viewModel.enabled.wrappedValue)
            #expect(Current.settingsStore.enhancedWebSecurityEnabled)
        }
    }

    @Test func togglingOffStoresTheSetting() {
        withStoredSetting(true) {
            let viewModel = EnhancedWebSecuritySettingsViewModel(isRelevant: true)

            viewModel.enabled.wrappedValue = false

            #expect(!viewModel.enabled.wrappedValue)
            #expect(!Current.settingsStore.enhancedWebSecurityEnabled)
        }
    }

    @Test func startsFromWhatIsStored() {
        withStoredSetting(true) {
            #expect(EnhancedWebSecuritySettingsViewModel(isRelevant: true).isEnabled)
        }
        withStoredSetting(false) {
            #expect(!EnhancedWebSecuritySettingsViewModel(isRelevant: true).isEnabled)
        }
    }

    /// Relevance defaults to what the configured servers say, which is what keeps the row off an
    /// HTTPS-only setup without the view having to ask.
    @Test func relevanceDefaultsToTheConfiguredServers() {
        #expect(
            EnhancedWebSecuritySettingsViewModel().isRelevant == WebKitEnhancedSecurity
                .isRelevantForConfiguredServers()
        )
    }

    private func withStoredSetting(_ value: Bool, _ body: () -> Void) {
        let previous = Current.settingsStore.enhancedWebSecurityEnabled
        defer { Current.settingsStore.enhancedWebSecurityEnabled = previous }
        Current.settingsStore.enhancedWebSecurityEnabled = value
        body()
    }
}
