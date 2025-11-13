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

// MARK: - Servers List View

private class ServersObserver: ObservableObject, ServerObserver {
    private let sortOrderIncrement = 1000

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

    func moveServers(from source: IndexSet, to destination: Int) {
        var updatedServers = servers
        updatedServers.move(fromOffsets: source, toOffset: destination)

        // Update sort order for all servers based on their new positions
        for (index, server) in updatedServers.enumerated() {
            let newSortOrder = index * sortOrderIncrement
            if server.info.sortOrder != newSortOrder {
                server.update { info in
                    info.sortOrder = newSortOrder
                }
            }
        }

        // Update local array immediately for responsive UI
        servers = updatedServers
    }
}
