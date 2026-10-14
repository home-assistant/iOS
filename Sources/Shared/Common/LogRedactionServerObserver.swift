import Foundation
import HANetworking

final class LogRedactionServerObserver: ServerObserver {
    static let shared = LogRedactionServerObserver()

    func start(observing serverManager: ServerManager, isEnabled: Bool = LogRedaction.isEnabled) {
        guard isEnabled else { return }
        serverManager.add(observer: self)
        serversDidChange(serverManager)
    }

    func serversDidChange(_ serverManager: ServerManager) {
        LogRedaction.updateExternalHosts(
            serverManager.all.compactMap { $0.info.connection.address(for: .external)?.host }
        )
    }
}
