import Shared
import SwiftUI

struct ServerSwitchingSettingsView: View {
    /// Helper variable to force redraw view
    @State private var redrawHelper: UUID = .init()

    var body: some View {
        List {
            Section {
                if Current.servers.all.count > 1 {
                    Toggle(isOn: .init(get: {
                        Current.settingsStore.locationBasedServerSwitching
                    }, set: { newValue in
                        Current.settingsStore.locationBasedServerSwitching = newValue
                        if newValue {
                            // Prompts when undetermined, or routes to system settings when denied.
                            PermissionType.location.request { _, _ in }
                        }
                        redrawView()
                    })) {
                        Text(L10n.Settings.ServerSwitching.ByLocation.title)
                    }
                }
                // Mac has a system-level setting for state restoration
                if !Current.isCatalyst {
                    Toggle(isOn: .init(get: {
                        Current.settingsStore.restoreLastURL
                    }, set: { newValue in
                        Current.settingsStore.restoreLastURL = newValue
                        redrawView()
                    })) {
                        Text(L10n.SettingsDetails.General.Restoration.title)
                    }
                }
            } footer: {
                if Current.servers.all.count > 1 {
                    Text(L10n.Settings.ServerSwitching.ByLocation.footer)
                }
            }
        }
        .id(redrawHelper)
        .navigationTitle(L10n.Settings.ServerSwitching.title)
    }

    private func redrawView() {
        redrawHelper = UUID()
    }
}

#Preview {
    NavigationView {
        ServerSwitchingSettingsView()
    }
    .navigationViewStyle(.stack)
}

extension ServerSwitchingSettingsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.Settings.ServerSwitching.title),
            SettingsSearchEntry(L10n.Settings.ServerSwitching.ByLocation.title),
            SettingsSearchEntry(L10n.SettingsDetails.General.Restoration.title),
        ]
    }
}
