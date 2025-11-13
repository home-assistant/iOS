import Foundation
import Shared

final class ServersObserver: ObservableObject, ServerObserver {
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
            let newSortOrder = index * 1000
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
