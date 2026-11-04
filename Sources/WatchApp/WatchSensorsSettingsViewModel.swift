import Combine
import Foundation
import Shared

/// The servers the sensors screen offers, kept current while it is open: a sync from the iPhone
/// can add or remove a server at any time, and the screen must not keep listing one that is gone
/// or hide one that has just arrived until it is reopened.
final class WatchSensorsSettingsViewModel: ObservableObject {
    @Published private(set) var servers: [Server] = []

    init() {
        Current.servers.add(observer: self)
        reload()
    }

    deinit {
        Current.servers.remove(observer: self)
    }

    /// Whether the watch still has the server, for a screen opened on it before a sync took it away.
    func hasServer(_ identifier: Identifier<Server>) -> Bool {
        servers.contains { $0.identifier == identifier }
    }

    func reload() {
        let all = Current.servers.all.sorted()
        DispatchQueue.main.async { [weak self] in
            self?.servers = all
        }
    }
}

extension WatchSensorsSettingsViewModel: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        reload()
    }
}
