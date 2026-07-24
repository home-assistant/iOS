import Shared
import SwiftUI

struct ServerSwitchingSettingsView: View {
    @StateObject private var viewModel: ServerSwitchingSettingsViewModel

    /// Helper variable to force redraw view
    @State private var redrawHelper: UUID = .init()

    @MainActor
    init(viewModel: ServerSwitchingSettingsViewModel? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel ?? ServerSwitchingSettingsViewModel())
    }

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
                    if let closestServer = viewModel.closestServerDescription {
                        HStack {
                            Text(L10n.Settings.ServerSwitching.ClosestServer.title)
                            Spacer()
                            Text(closestServer)
                                .foregroundStyle(.secondary)
                        }
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
        .onAppear {
            viewModel.onAppear()
        }
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
    /// Only index rows the screen can actually present: the whole entry is absent on Catalyst,
    /// and the by-location toggle only shows with more than one server.
    static var settingsSearchEntries: [SettingsSearchEntry] {
        guard !Current.isCatalyst else { return [] }
        var entries = [
            SettingsSearchEntry(L10n.Settings.ServerSwitching.title),
            SettingsSearchEntry(L10n.SettingsDetails.General.Restoration.title),
        ]
        if Current.servers.all.count > 1 {
            entries.append(SettingsSearchEntry(L10n.Settings.ServerSwitching.ByLocation.title))
        }
        return entries
    }
}
