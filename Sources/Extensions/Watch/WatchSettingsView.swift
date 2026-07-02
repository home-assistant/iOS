import SFSafeSymbols
import Shared
import SwiftUI

/// Watch settings. Lists servers synchronized from the paired iPhone and shows connectivity details
/// (including mTLS client-certificate status). It also provides watch-local preferences like where
/// actions run (iPhone vs Watch) and per-server URL overrides; server configuration itself remains
/// managed on the iPhone.
struct WatchSettingsView: View {
    @StateObject private var viewModel = WatchSettingsViewModel()
    @State private var performActionTarget = WatchUserDefaults.shared.performActionTarget

    var body: some View {
        NavigationView {
            List {
                serversSection
                configurationSection
                performActionSection
            }
            .navigationTitle(Text(verbatim: L10n.Watch.Settings.title))
        }
    }

    private var configurationSection: some View {
        Section {
            NavigationLink {
                WatchConfigAssistView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                        Text(verbatim: L10n.Watch.Config.Assist.title)
                        Text(verbatim: viewModel.assistPipelineTitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemSymbol: .waveformCircleFill)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchConfigDidChange)) { _ in
                viewModel.reload()
            }
        }
    }

    private var performActionSection: some View {
        Section {
            Picker(L10n.Watch.Settings.PerformAction.title, selection: $performActionTarget) {
                Text(verbatim: L10n.Watch.Settings.auto).tag(WatchActionTarget.auto)
                Text(verbatim: L10n.Watch.Settings.PerformAction.iphone).tag(WatchActionTarget.iPhone)
                Text(verbatim: L10n.Watch.Settings.PerformAction.appleWatch).tag(WatchActionTarget.appleWatch)
            }
            .onChange(of: performActionTarget) { newValue in
                WatchUserDefaults.shared.performActionTarget = newValue
            }
        } footer: {
            Text(verbatim: L10n.Watch.Settings.PerformAction.footer)
        }
    }

    @ViewBuilder
    private var serversSection: some View {
        Section {
            if viewModel.servers.isEmpty {
                Text(verbatim: L10n.Watch.Settings.noServers)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.servers, id: \.identifier.rawValue) { server in
                    NavigationLink {
                        WatchServerDetailView(server: server)
                    } label: {
                        Label {
                            Text(verbatim: server.info.name)
                        } icon: {
                            Image(systemSymbol: .network)
                        }
                    }
                }
            }
        } header: {
            Text(verbatim: L10n.Watch.Settings.Servers.header)
        } footer: {
            // When the synchronized data is from — refreshed via the Home screen's reload button.
            if let lastUpdated = viewModel.lastUpdated {
                Text(verbatim: L10n.Watch.Settings.lastUpdated(
                    lastUpdated.formatted(date: .abbreviated, time: .shortened)
                ))
            }
        }
    }
}
