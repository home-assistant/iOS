import HAKit
import KeychainAccess
import Version
import UserNotifications

public protocol ServerObserver: AnyObject {
    func serversDidChange(_ serverManager: ServerManager)
}

public protocol ServerManager {
    var all: [Server] { get }
    func server(for identifier: Identifier<Server>) -> Server?
    func server(forWebhookID: String) -> Server?
    func server(for intent: SingleServerIntent) -> Server?
    func server(for notification: UNNotificationContent) -> Server?

    func add(identifier: Identifier<Server>, serverInfo: ServerInfo)
    func remove(identifier: Identifier<Server>)
    func removeAll()

    func add(observer: ServerObserver)
    func remove(observer: ServerObserver)
}

private extension Identifier where ObjectType == Server {
    var keychainKey: String { rawValue }
    init(keychainKey: String) { rawValue = keychainKey }
}

private class ServerCache {
    var restrictCaching: Bool = false
    var info: [Identifier<Server>: ServerInfo] = [:]
    var server: [Identifier<Server>: Server] = [:]
    var all: [Server]?
}

public class ServerManagerImpl: ServerManager {
    private var keychain: Keychain
    private var encoder: JSONEncoder
    private var decoder: JSONDecoder

    private var observers = NSHashTable<AnyObject>()

    public func add(observer: ServerObserver) {
        observers.add(observer)
    }

    public func remove(observer: ServerObserver) {
        observers.remove(observer)
    }

    static let service = "io.home-assistant.servers"

    private let cache = ServerCache()

    init() {
        let keychain = Keychain(service: Self.service)
        self.keychain = keychain

        let encoder = JSONEncoder()
        self.encoder = encoder
        let decoder = JSONDecoder()
        self.decoder = decoder
    }

    func setup(environment: AppEnvironment) {
        cache.restrictCaching = environment.isAppExtension

        // load to cache immediately
        _ = all

        do {
            try migrateIfNeeded()
        } catch {
            Current.Log.error("failed to load historic server: \(error)")
        }
    }

    public var all: [Server] {
        if !cache.restrictCaching, let cachedServers = cache.all {
            #warning("multiserver, need to watch for server changes in extensions better")
            return cachedServers
        } else {
            let servers = loadServers()
            cache.all = servers
            return servers
        }
    }

    public func server(for identifier: Identifier<Server>) -> Server? {
        if let fast = cache.server[identifier] {
            return fast
        } else {
            return all.first(where: { $0.identifier == identifier })
        }
    }

    public func server(forWebhookID webhookID: String) -> Server? {
        all.first(where: { $0.info.connection.webhookID == webhookID })
    }

    public func server(for intent: SingleServerIntent) -> Server? {
        if let server = intent.server?.identifier.flatMap({ server(for: .init(rawValue: $0)) }) {
            return server
        } else {
            let all = all
            if all.count == 1, let server = all.first {
                return server
            } else {
                return nil
            }
        }
    }

    public func server(for content: UNNotificationContent) -> Server? {
        if let webhookID = content.userInfo["webhook_id"] as? String,
           let server = server(forWebhookID: webhookID) {
            return server
        } else {
            return all.first
        }
    }

    public func add(identifier: Identifier<Server>, serverInfo: ServerInfo) {
        keychain.set(
            serverInfo: with(serverInfo) {
                $0.sortOrder = all.map(\.info.sortOrder).max().map { $0 + 1000 } ?? 0
            },
            key: identifier.keychainKey,
            encoder: encoder
        )

        cache.all = nil
        notify()
    }

    public func remove(identifier: Identifier<Server>) {
        keychain.deleteServerInfo(key: identifier.keychainKey)

        cache.all = nil
        notify()
    }

    public func removeAll() {
        _ = try? keychain.removeAll()
    }

    private func notify() {
        for observer in observers.allObjects.compactMap({ $0 as? ServerObserver }) {
            observer.serversDidChange(self)
        }
    }

    private func loadServers() -> [Server] {
        keychain.allServerInfo(decoder: decoder).map { key, value in
            let identifier = Identifier<Server>(keychainKey: key)

            if let server = cache.server[identifier] {
                return server
            }

            var fallback = value

            let server = Server(identifier: identifier, getter: { [cache, keychain, decoder] in
                if let info = cache.info[identifier], !cache.restrictCaching {
                    return info
                } else {
                    let info = keychain.getServerInfo(key: identifier.keychainKey, decoder: decoder) ?? fallback
                    cache.info[identifier] = info
                    return info
                }
            }, setter: { [weak self] serverInfo in
                guard let self = self, self.cache.info[identifier] != serverInfo || self.cache.restrictCaching else { return }
                fallback = serverInfo

                self.cache.info[identifier] = serverInfo
                self.keychain.set(serverInfo: serverInfo, key: identifier.keychainKey, encoder: self.encoder)
                self.notify()
            })
            cache.server[identifier] = server
            return server
        }.sorted()
    }

    private func migrateIfNeeded() throws {
        guard all.isEmpty else { return }

        let historicKeychain = Keychain(service: Constants.BundleID)
        let userDefaults = UserDefaults(suiteName: Constants.AppGroupID)!
        if let tokenInfoData = try historicKeychain.getData("tokenInfo"),
           let connectionInfoData = try historicKeychain.getData("connectionInfo"),
           let versionString = userDefaults.string(forKey: "version") {
            let name = userDefaults.string(forKey: "location_name") ?? ServerInfo.defaultName

            var serverInfo = ServerInfo(
                name: name,
                connection: try decoder.decode(ConnectionInfo.self, from: connectionInfoData),
                token: try decoder.decode(TokenInfo.self, from: tokenInfoData),
                version: try Version(hassVersion: versionString)
            )

            if let name = userDefaults.string(forKey: "override_device_name") {
                serverInfo.setSetting(value: name, for: .overrideDeviceName)
            }

            add(identifier: Server.historicId, serverInfo: serverInfo)
            try historicKeychain.removeAll()
        }
    }
}

private extension Keychain {
    func allServerInfo(decoder: JSONDecoder) -> [(String, ServerInfo)] {
        allKeys().compactMap { key in
            getServerInfo(key: key, decoder: decoder).map { (key, $0) }
        }
    }

    func getServerInfo(key: String, decoder: JSONDecoder) -> ServerInfo? {
        do {
            guard let data = try getData(key) else {
                return nil
            }

            let server = try decoder.decode(ServerInfo.self, from: data)
            return server
        } catch {
//            Current.Log.error("failed to load server \(key): \(error)")
            return nil
        }
    }

    func set(serverInfo: ServerInfo, key: String, encoder: JSONEncoder) {
        do {
            try set(encoder.encode(serverInfo), key: key)
        } catch {
//            Current.Log.error("failed to save: \(error)")
        }
    }

    func deleteServerInfo(key: String) {
        do {
            try remove(key)
        } catch {
//            Current.Log.error("failed to remove \(key): \(error)")
        }
    }
}
