import SFSafeSymbols
import Shared
import SwiftUI

/// Lets the user stop a server's entities from being offered to Siri.
struct SiriSettingsView: View {
    @StateObject private var viewModel = SiriSettingsViewModel()

    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.Settings.Siri.Servers.header),
            SettingsSearchEntry(L10n.Settings.Siri.Configure.Calendars.header),
            SettingsSearchEntry(L10n.Settings.Siri.Configure.Lists.header),
        ]
    }

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .microphoneMessageIcon,
                title: L10n.Settings.Siri.title,
                subtitle: L10n.Settings.Siri.subtitle
            )
            Section(
                header: Text(L10n.Settings.Siri.Servers.header),
                footer: Text(L10n.Settings.Siri.Servers.footer)
            ) {
                if viewModel.rows.isEmpty {
                    Text(L10n.Settings.Siri.Servers.empty)
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.rows) { row in
                    Toggle(isOn: Binding(
                        get: { row.isExposed },
                        set: { viewModel.setExposed($0, serverId: row.id) }
                    )) {
                        Text(row.name)
                    }
                    if #available(iOS 27.0, *), row.isExposed,
                       let server = Current.servers.server(for: .init(rawValue: row.id)) {
                        NavigationLink(L10n.Settings.Siri.Servers.configure) {
                            SiriServerConfigurationView(server: server)
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.load() }
    }
}

#Preview {
    NavigationView {
        SiriSettingsView()
    }
}
