import HAKit
import KeychainAccess
import Version

public protocol ServerObserver: AnyObject {
    func serversDidChange(_ serverManager: ServerManager)
}

public protocol ServerManager {
    var all: [Server] { get }
    func server(for identifier: Identifier<Server>) -> Server?

    func add(identifier: Identifier<Server>, serverInfo: ServerInfo)
    func remove(identifier: Identifier<Server>)

    func add(observer: ServerObserver)
    func remove(observer: ServerObserver)
}

private extension Identifier where ObjectType == Server {
    var keychainKey: String { rawValue }
    init(keychainKey: String) { rawValue = keychainKey }
}

private class ServerCache {
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
        // load to cache immediately
        _ = all

        migrateIfNeeded()
    }

    public var all: [Server] {
        if let cachedServers = cache.all {
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

    public func add(identifier: Identifier<Server>, serverInfo: ServerInfo) {
        cache.all = nil
        keychain.set(serverInfo: serverInfo, key: identifier.keychainKey, encoder: encoder)
        notify()
    }

    public func remove(identifier: Identifier<Server>) {
        cache.all = nil
        keychain.deleteServerInfo(key: identifier.keychainKey)
        notify()
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
                if let info = cache.info[identifier] {
                    return info
                } else {
                    let info = keychain.getServerInfo(key: identifier.keychainKey, decoder: decoder) ?? fallback
                    cache.info[identifier] = info
                    return info
                }
            }, setter: { [weak self] serverInfo in
                guard let self = self else { return }
                fallback = serverInfo
                self.cache.info[identifier] = serverInfo
                self.keychain.set(serverInfo: serverInfo, key: identifier.keychainKey, encoder: self.encoder)
                self.notify()
            })
            cache.server[identifier] = server
            return server
        }
    }

    private func migrateIfNeeded() {
        guard all.isEmpty else { return }

        let historicKeychain = Keychain(service: Constants.BundleID)
        let didMigrateKey = "HADidMigrate"

//        guard historicKeychain[didMigrateKey] != nil else {
//            return
//        }

        do {
            let userDefaults = UserDefaults(suiteName: Constants.AppGroupID)!
            if let tokenInfoData = try historicKeychain.getData("tokenInfo"),
               let connectionInfoData = try historicKeychain.getData("connectionInfo"),
               let versionString = userDefaults.string(forKey: "version")
            {
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
                historicKeychain[didMigrateKey] = "true"
            }
        } catch {
            Current.Log.error("failed to load historic server: \(error)")
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
