import Combine
import Foundation
import Shared

final class WatchSettingsViewModel: ObservableObject {
    @Published private(set) var servers: [Server] = []
    @Published private(set) var lastUpdated: Date?

    init() {
        Current.servers.add(observer: self)
        reload()
    }

    private func reload() {
        let all = Current.servers.all
        let updatedAt = WatchUserDefaults.shared.date(for: .serversUpdatedAt)
        DispatchQueue.main.async { [weak self] in
            self?.servers = all
            self?.lastUpdated = updatedAt
        }
    }
}

extension WatchSettingsViewModel: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        reload()
    }
}
