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

    /// The servers that report one instance ID between two or more of them, which is what a server
    /// set up from another one's backup looks like, grouped by that ID in list order. Empties on its
    /// own once one of them reports a new ID, since every `get_config` refreshes it.
    var serversSharingAnInstanceID: [[Server]] {
        Self.groupsSharingAnInstanceID(servers)
    }

    /// `serversSharingAnInstanceID` as the explanation screen lists them.
    var serverIdentityConflicts: [[ServerIdentityConflictingServer]] {
        serversSharingAnInstanceID.map { group in
            group.map { ServerIdentityConflictingServer(info: $0.info) }
        }
    }

    static func groupsSharingAnInstanceID(_ servers: [Server]) -> [[Server]] {
        var groups: [String: [Server]] = [:]
        var order: [String] = []
        for server in servers {
            guard let instanceID = server.info.instanceID, !instanceID.isEmpty else { continue }
            if groups[instanceID] == nil {
                order.append(instanceID)
            }
            groups[instanceID, default: []].append(server)
        }
        return order.compactMap { groups[$0] }.filter { $0.count > 1 }
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
            let newSortOrder = index
            if server.info.sortOrder != newSortOrder {
                server.update { info in
                    info.sortOrder = newSortOrder
                }
            }
        }

        // Update local array immediately for responsive UI
        servers = updatedServers
    }

    func makeDefault(_ server: Server) {
        guard let index = servers.firstIndex(where: { $0.identifier == server.identifier }), index != 0 else {
            return
        }
        moveServers(from: IndexSet(integer: index), to: 0)
    }
}
