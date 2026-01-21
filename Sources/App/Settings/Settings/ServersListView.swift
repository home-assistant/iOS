import Shared
import SwiftUI

struct ServersListView: View {
    @StateObject private var observer = ServersObserver()
    @State private var showAddServer = false
    @Environment(\.editMode) private var editMode

    var body: some View {
        ForEach(observer.servers, id: \.identifier) { server in
            NavigationLink(destination: ConnectionSettingsView(server: server)) {
                HomeAssistantAccountRowView(server: server)
            }
            .contextMenu {
                Button {
                    server.refreshAppDatabase(forceUpdate: true)
                } label: {
                    Label(L10n.Settings.ConnectionSection.refreshServer, systemSymbol: .arrowClockwise)
                }
            }
        }
        .onMove { source, destination in
            observer.moveServers(from: source, to: destination)
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
        #if !targetEnvironment(macCatalyst)
        .fullScreenCover(isPresented: $showAddServer) {
            OnboardingNavigationView(onboardingStyle: .secondary)
        }
        #endif
    }
}
