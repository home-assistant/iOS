import Shared
import SwiftUI

struct CarPlayAdvancedSettingsView: View {
    @State private var settings: CarPlayAssistDebugSettings

    init() {
        _settings = State(initialValue: Current.settingsStore.carPlayAssistDebugSettings)
    }

    var body: some View {
        List {
            assistSection
        }
        .navigationTitle(L10n.CarPlay.Labels.Settings.Advanced.Section.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings) { updatedSettings in
            Current.settingsStore.carPlayAssistDebugSettings = updatedSettings
        }
    }

    private var assistSection: some View {
        Section {
            Picker(
                L10n.CarPlay.Labels.Settings.Advanced.Assist.TtsPlayback.title,
                selection: $settings.ttsPlaybackStrategy
            ) {
                ForEach(CarPlayAssistTTSPlaybackStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.title).tag(strategy)
                }
            }
            .lineLimit(1)
        } header: {
            Text(L10n.CarPlay.Labels.Settings.Advanced.Assist.Section.title)
        } footer: {
            Text(L10n.CarPlay.Labels.Settings.Advanced.Assist.TtsPlayback.footer)
        }
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        NavigationStack {
            CarPlayAdvancedSettingsView()
        }
    } else {
        NavigationView {
            CarPlayAdvancedSettingsView()
        }
    }
}
