import Foundation

internal extension Server {
    static func fake(
        identifier: Identifier<Server> = .init(rawValue: UUID().uuidString),
        initial: ServerInfo = .init(
            name: "Fake Server",
            connection: .init(
                externalURL: nil,
                internalURL: URL(string: "http://homeassistant.local:8123")!,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "FakeWebhookID",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: true
            ),
            token: .init(
                accessToken: "FakeAccessToken",
                refreshToken: "FakeRefreshToken",
                expiration: Current.date().addingTimeInterval(3600)
            ),
            version: .init(
                major: 2021,
                minor: 1,
                patch: 0,
                prerelease: nil,
                build: nil
            )
        ),
        update: (inout ServerInfo) -> Void = { _ in }
    ) -> Server {
        var serverInfo = initial
        update(&serverInfo)
        return Server(identifier: identifier, getter: { serverInfo }, setter: { serverInfo = $0 })
    }
}

internal class FakeServerManager: ServerManager {
    var all = [Server]()
    var observers = [ServerObserver]()

    init(initial: Int = 0) {
        for _ in 0 ..< initial {
            _ = addFake()
        }
    }

    func server(for identifier: Identifier<Server>) -> Server? {
        all.first(where: { $0.identifier == identifier })
    }

    func addFake() -> Server {
        let server = Server.fake()
        return add(identifier: server.identifier, serverInfo: server.info)
    }

    func add(identifier: Identifier<Server>, serverInfo: ServerInfo) -> Server {
        if let existing = all.first(where: { $0.identifier == identifier }) {
            existing.update { current in
                current = serverInfo
            }
            return existing
        } else {
            let server = Server.fake(identifier: identifier, initial: serverInfo)
            all.append(server)
            return server
        }
    }

    func remove(identifier: Identifier<Server>) {
        all.removeAll(where: { $0.identifier == identifier })
    }

    func removeAll() {
        all.removeAll()
    }

    func add(observer: ServerObserver) {
        observers.append(observer)
    }

    func remove(observer: ServerObserver) {
        observers.removeAll(where: { $0 === observer })
    }
}