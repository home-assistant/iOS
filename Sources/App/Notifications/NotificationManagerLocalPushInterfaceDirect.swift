import Foundation
import HAKit
import Shared

class NotificationManagerLocalPushInterfaceDirect: NotificationManagerLocalPushInterface, ServerObserver {
    func status(for server: Server) -> NotificationManagerLocalPushStatus {
        if let state = localPushManagers[server.identifier]?.state {
            return .allowed(state)
        } else {
            return .disabled
        }
    }

    private var localPushManagers = [Identifier<Server>: LocalPushManager]()
    weak var localPushDelegate: LocalPushManagerDelegate?

    init(delegate: LocalPushManagerDelegate) {
        self.localPushDelegate = delegate
        updateLocalPushManagers()
        Current.servers.add(observer: self)
    }

    deinit {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func addObserver(
        for server: Server,
        handler: @escaping (NotificationManagerLocalPushStatus) -> Void) -> HACancellable {
        let observer = Observer(identifier: UUID(), server: server, handler: handler)
        observers.append(observer)
        return HABlockCancellable { [weak self] in
            self?.observers.removeAll(where: { $0.identifier == observer.identifier })
        }
    }

    private struct Observer: Equatable {
        let identifier: UUID
        let server: Server
        let handler: (NotificationManagerLocalPushStatus) -> Void

        static func == (lhs: Observer, rhs: Observer) -> Bool {
            lhs.identifier == rhs.identifier
        }
    }

    private var observers = [Observer]()
    private var notificationTokens: [NSObjectProtocol] = []

    private func pushManagerStateDidChange(server: Server) {
        for observer in observers where observer.server == server {
            observer.handler(status(for: server))
        }
    }

    func serversDidChange(_ serverManager: ServerManager) {
        updateLocalPushManagers()
    }

    private func updateLocalPushManagers() {
        let existing = localPushManagers.keys
        let servers = Current.servers.all

        let deleted = Set(servers.map(\.identifier)).subtracting(existing)
        let needed = servers.filter { localPushManagers[$0.identifier] == nil }

        deleted.forEach { localPushManagers[$0] = nil }
        needed.forEach { server in
            localPushManagers[server.identifier] = with(.init(server: server)) { manager in
                notificationTokens.append(
                    NotificationCenter.default.addObserver(
                        forName: LocalPushManager.stateDidChange,
                        object: manager,
                        queue: .main,
                        using: { [weak self] _ in
                            self?.pushManagerStateDidChange(server: server)
                        }
                    )
                )
            }
        }
    }
}
