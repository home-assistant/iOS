import Foundation
import PromiseKit
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

    @MainActor
    func deleteServer(_ server: Server) async {
        let revocations = [Current.api(for: server)?.tokenManager.revokeToken()].compactMap { $0 }
        await race(
            when(resolved: revocations).asVoid(),
            after(seconds: 10.0)
        ).async()

        Current.api(for: server)?.connection.disconnect()
        Current.servers.remove(identifier: server.identifier)
        Current.resetAPICache(for: [server.identifier])
        Current.onboardingObservation.needed(.logout)
    }
}
