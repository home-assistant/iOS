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
        .modify { view in
            if #available(iOS 17.0, *) {
                view.contentMargins(.top, DesignSystem.Spaces.half)
            } else {
                view
            }
        }
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
