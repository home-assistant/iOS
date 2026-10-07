import Foundation

extension ServerInfo {
    static func fake() -> ServerInfo {
        var value = ServerInfo(
            name: "Fake Server",
            connection: .init(
                externalURL: URL(string: "http://homeassistant.local:8123")!,
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "FakeWebhookID",
                webhookSecret: nil,
                internalSSIDs: ["MyWifi"],
                internalHardwareAddresses: nil,
                isLocalPushEnabled: true,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .undefined
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
        )
        _ = value.connection.evaluateActiveURL()
        return value
    }
}

extension Server {
    static func fake(
        identifier: Identifier<Server> = .init(rawValue: UUID().uuidString),
        initial: ServerInfo = .fake(),
        update: (inout ServerInfo) -> Void = { _ in }
    ) -> Server {
        var serverInfo = initial
        update(&serverInfo)
        return Server(identifier: identifier, getter: { serverInfo }, setter: { serverInfo = $0; return true })
    }
}

/// Fake server registry for tests and Xcode previews (set as `Current.servers`), where no real
/// server has been onboarded.
public class FakeServerManager: ServerManager {
    public var all = [Server]()
    public var isMirrorRestorePending = false
    var observers = [WeakWrapper]()

    public init(initial: Int = 0) {
        for _ in 0 ..< initial {
            _ = addFake()
        }
    }

    public func server(for identifier: Identifier<Server>) -> Server? {
        all.first(where: { $0.identifier == identifier })
    }

    public func restoreKeychainFromMirrorIfNeeded() -> Bool {
        false
    }

    @discardableResult
    public func addFake() -> Server {
        let server = Server.fake()
        return add(identifier: server.identifier, serverInfo: server.info)
    }

    @discardableResult
    public func add(identifier: Identifier<Server>, serverInfo: ServerInfo) -> Server {
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

    public func remove(identifier: Identifier<Server>) {
        all.removeAll(where: { $0.identifier == identifier })
    }

    public func removeAll() {
        all.removeAll()
    }

    func notify() {
        for wrapper in observers {
            wrapper.observer?.serversDidChange(self)
        }
    }

    struct WeakWrapper {
        weak var observer: ServerObserver?
    }

    public func add(observer: ServerObserver) {
        if !observers.contains(where: { $0.observer === observer }) {
            observers.append(.init(observer: observer))
        }
    }

    public func remove(observer: ServerObserver) {
        observers.removeAll(where: { $0.observer === observer })
    }

    public func restoreState(_ state: Data) {}

    public func restorableState() -> Data {
        Data()
    }
}
