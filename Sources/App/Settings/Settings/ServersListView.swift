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
        }
        .onMove { source, destination in
            observer.moveServers(from: source, to: destination)
        }

        Button {
            showAddServer = true
        } label: {
            Label(L10n.Settings.ConnectionSection.addServer, systemSymbol: .plus)
        }
        .fullScreenCover(isPresented: $showAddServer) {
            OnboardingNavigationView(onboardingStyle: .secondary)
        }
    }
}
