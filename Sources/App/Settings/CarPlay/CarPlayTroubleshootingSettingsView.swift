import Shared
import SwiftUI

struct CarPlayTroubleshootingSettingsView: View {
    @State private var settings: CarPlayAssistDebugSettings

    init() {
        _settings = State(initialValue: Current.settingsStore.carPlayAssistDebugSettings)
    }

    var body: some View {
        List {
            assistSection
        }
        .navigationTitle(L10n.CarPlay.Labels.Settings.Troubleshooting.Section.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings) { updatedSettings in
            Current.settingsStore.carPlayAssistDebugSettings = updatedSettings
        }
    }

    private var assistSection: some View {
        Section {
            Picker(
                L10n.CarPlay.Labels.Settings.Troubleshooting.Assist.TtsPlayback.title,
                selection: $settings.ttsPlaybackStrategy
            ) {
                ForEach(CarPlayAssistTTSPlaybackStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.title).tag(strategy)
                }
            }
            .lineLimit(1)
        } header: {
            Text(L10n.CarPlay.Labels.Settings.Troubleshooting.Assist.Section.title)
        } footer: {
            Text(L10n.CarPlay.Labels.Settings.Troubleshooting.Assist.TtsPlayback.footer)
        }
    }
}

#Preview {
    NavigationStack {
        CarPlayTroubleshootingSettingsView()
    }
}
