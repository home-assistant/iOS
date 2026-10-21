import Shared
import SwiftUI

struct ServersListView: View {
    private enum Constants {
        static let previewWidth: CGFloat = 360
    }

    var macSidebarSelection: MacSettingsSidebarSelection?

    @StateObject private var observer = ServersObserver()
    @State private var showAddServer = false
    @State private var serverPendingDeletion: Server?
    @Environment(\.editMode) private var editMode

    var body: some View {
        ForEach(observer.servers, id: \.identifier) { server in
            NavigationLink(destination: ConnectionSettingsView(server: server)) {
                HomeAssistantAccountRowView(server: server, isCompact: Current.isCatalyst)
            }
            .accessibilityIdentifier(AccessibilityIdentifier.settingsServerRow.rawValue)
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
            } preview: {
                ServerDetailsRowView(
                    serverName: server.info.name,
                    userName: "",
                    profilePicture: nil,
                    details: ServerDetailsRowView.details(for: server),
                    isSyncing: false,
                    transitionNamespace: nil,
                    onEdit: { _ in },
                    onSync: {},
                    onTroubleshoot: {},
                    onOpen: nil,
                    showsActions: false
                )
                .frame(width: Constants.previewWidth)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
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

        if !observer.serversSharingAnInstanceID.isEmpty {
            NavigationLink(destination: ServerIdentityExplanationView(
                conflictingServers: observer
                    .serverIdentityConflicts
            )) {
                Label {
                    Text(L10n.Settings.ConnectionSection.sharedInstanceIdWarning)
                } icon: {
                    Image(systemSymbol: .exclamationmarkTriangleFill)
                        .foregroundStyle(.orange)
                }
            }
            .tag(MacSettingsSidebarSelection.serverIdentity)
            .macSettingsSidebarRow(isSelected: macSidebarSelection == .serverIdentity)
        }

        if observer.servers.count > 1 {
            NavigationLink(destination: ServerSwitchingSettingsView()) {
                Label(L10n.Settings.ServerSwitching.AutomaticSwitching.title, systemSymbol: .location)
            }
            .tag(MacSettingsSidebarSelection.serverSwitching)
            .macSettingsSidebarRow(isSelected: macSidebarSelection == .serverSwitching)
        }

        Button {
            #if targetEnvironment(macCatalyst)
            Current.sceneManager.activateAnyScene(for: .onboarding)
            #else
            showAddServer = true
            #endif
        } label: {
            Label(L10n.Settings.ConnectionSection.addServer, systemSymbol: .plus)
        }
        .accessibilityIdentifier(AccessibilityIdentifier.settingsAddServer.rawValue)
        #if !targetEnvironment(macCatalyst)
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
