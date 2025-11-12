import SwiftUI
import Shared

struct ServersListView: View {
    @StateObject private var observer = ServersObserver()
    @State private var showAddServer = false

    var body: some View {
        ForEach(observer.servers, id: \.identifier) { server in
            NavigationLink(destination: ConnectionSettingsView(server: server)) {
                HomeAssistantAccountRowView(server: server)
            }
        }

        Button {
            showAddServer = true
        } label: {
            Text(L10n.Settings.ConnectionSection.addServer)
        }
        .sheet(isPresented: $showAddServer) {
            OnboardingNavigationView(onboardingStyle: .secondary)
        }
    }
}

// MARK: - Servers List View

private class ServersObserver: ObservableObject, ServerObserver {
    @Published var servers: [Server] = []

    init() {
        self.servers = Current.servers.all
        Current.servers.add(observer: self)
    }

    deinit {
        Current.servers.remove(observer: self)
    }

    func serversDidChange(_ serverManager: ServerManager) {
        DispatchQueue.main.async { [weak self] in
            self?.servers = serverManager.all
        }
    }
}
