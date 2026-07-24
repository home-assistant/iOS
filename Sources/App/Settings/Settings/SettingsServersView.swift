import Shared
import SwiftUI

struct SettingsServersView: View {
    var body: some View {
        List {
            Section(
                header: Text(L10n.Settings.ConnectionSection.serversHeader),
                footer: Text(L10n.Settings.ConnectionSection.serversReorderFooter)
            ) {
                ServersListView()
            }
        }
        .navigationTitle(L10n.Settings.ConnectionSection.servers)
    }
}

#Preview {
    NavigationView {
        SettingsServersView()
    }
    .navigationViewStyle(.stack)
}

extension SettingsServersView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        ServersListView.settingsSearchEntries + ServerSwitchingSettingsView.settingsSearchEntries
    }
}
