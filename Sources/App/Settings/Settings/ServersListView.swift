import Shared
import SwiftUI

struct ServersListView: View {
    var macSidebarSelection: MacSettingsSidebarSelection?

    @StateObject private var observer = ServersObserver()
    @State private var showAddServer = false
    @State private var serverPendingDeletion: Server?
    #if !os(macOS)
    @Environment(\.editMode) private var editMode
    #endif

    var body: some View {
        ForEach(observer.servers, id: \.identifier) { server in
            MacSettingsSidebarLink(destination: ConnectionSettingsView(server: server)) {
                HomeAssistantAccountRowView(server: server, isCompact: Current.isCatalyst)
            }
            .tag(MacSettingsSidebarSelection.server(server.identifier))
            .macSettingsSidebarRow(isSelected: macSidebarSelection == .server(server.identifier))
            .contextMenu {
                Button {
                    server.refreshAppDatabase(forceUpdate: true, showProgress: true)
                } label: {
                    Label(L10n.Settings.ConnectionSection.refreshServer, systemSymbol: .arrowClockwise)
                }
                if observer.servers.first?.identifier != server.identifier {
                    Button {
                        observer.makeDefault(server)
                    } label: {
                        Label(L10n.Settings.ConnectionSection.makeDefault, systemSymbol: .star)
                    }
                }
                Button(role: .destructive) {
                    serverPendingDeletion = server
                } label: {
                    Label(L10n.Settings.ConnectionSection.DeleteServer.title, systemSymbol: .trash)
                }
            }
            .confirmationDialog(
                L10n.Settings.ConnectionSection.DeleteServer.title,
                isPresented: Binding(
                    get: { serverPendingDeletion?.identifier == server.identifier },
                    set: { if !$0 { serverPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L10n.Settings.ConnectionSection.DeleteServer.title, role: .destructive) {
                    Task { await server.deleteFromApp() }
                }
                Button(L10n.cancelLabel, role: .cancel) {}
            } message: {
                Text(L10n.Settings.ConnectionSection.DeleteServer.message)
            }
        }
        .onMove { source, destination in
            observer.moveServers(from: source, to: destination)
        }

        MacSettingsSidebarLink(destination: ServerSwitchingSettingsView()) {
            Label(L10n.Settings.ServerSwitching.title, systemSymbol: .arrowLeftArrowRight)
        }
        .tag(MacSettingsSidebarSelection.serverSwitching)
        .macSettingsSidebarRow(isSelected: macSidebarSelection == .serverSwitching)

        Button {
            #if targetEnvironment(macCatalyst) || os(macOS)
            Current.sceneManager.activateAnyScene(for: .onboarding)
            #else
            showAddServer = true
            #endif
        } label: {
            Label(L10n.Settings.ConnectionSection.addServer, systemSymbol: .plus)
        }
        #if os(macOS)
        // A bordered button would read as a control dropped into the sidebar instead of one of its rows.
        .buttonStyle(.plain)
        #elseif !targetEnvironment(macCatalyst)
        .fullScreenCover(isPresented: $showAddServer) {
            OnboardingNavigationView(onboardingStyle: .secondary)
        }
        #endif
        .macSettingsSidebarRow()
    }
}

extension ServersListView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.Settings.ConnectionSection.addServer),
            SettingsSearchEntry(L10n.Settings.ConnectionSection.refreshServer),
        ]
    }
}
