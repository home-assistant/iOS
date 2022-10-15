import HAKit
import KeychainAccess
import Sodium
import UserNotifications
import Version

public protocol ServerObserver: AnyObject {
    func serversDidChange(_ serverManager: ServerManager)
}

public protocol ServerManager {
    var all: [Server] { get }
    func server(for identifier: Identifier<Server>) -> Server?

    @discardableResult
    func add(identifier: Identifier<Server>, serverInfo: ServerInfo) -> Server
    func remove(identifier: Identifier<Server>)
    func removeAll()

    func add(observer: ServerObserver)
    func remove(observer: ServerObserver)

    func restorableState() -> Data
    func restoreState(_ state: Data)
}

public extension ServerManager {
    func server(forWebhookID webhookID: String) -> Server? {
        all.first(where: { $0.info.connection.webhookID == webhookID })
    }

    func server(forServerIdentifier rawIdentifier: String?) -> Server? {
        if let rawIdentifier = rawIdentifier {
            return server(for: .init(rawValue: rawIdentifier))
        } else {
            return nil
        }
    }

    private var fallbackServer: Server? {
        let all = all
        if all.count == 1, let server = all.first {
            return server
        } else {
            return nil
        }
    }

    func server(for providing: ServerIdentifierProviding, fallback: Bool = true) -> Server? {
        if let server = server(forServerIdentifier: providing.serverIdentifier) {
            return server
        } else if fallback {
            return fallbackServer
        } else {
            return nil
        }
    }

    func server(for intent: ServerIntentProviding, fallback: Bool = true) -> Server? {
        if let server = server(forServerIdentifier: intent.server?.identifier) {
            return server
        } else if fallback {
            return fallbackServer
        } else {
            return nil
        }
    }

    func server(for content: UNNotificationContent) -> Server? {
        if let webhookID = content.userInfo["webhook_id"] as? String {
            return server(forWebhookID: webhookID)
        } else {
            // intentionally different, because 'webhook_id' is server version dependent
            // if the value isn't provided, assume the first server
            return all.first
        }
    }
}

internal protocol ServerManagerKeychain {
    func removeAll() throws
    func allKeys() -> [String]
    func getData(_ key: String) throws -> Data?
    func set(_ value: Data, key: String) throws
    func remove(_ key: String) throws
}

private extension Identifier where ObjectType == Server {
    var keychainKey: String { rawValue }
    init(keychainKey: String) { rawValue = keychainKey }
}

private struct ServerCache {
    var restrictCaching: Bool = false
    var deletedServers: Set<Identifier<Server>> {
        get {
            let identifiers = Current.settingsStore.prefs.array(forKey: "deletedServers") as? [String] ?? []
            return Set(identifiers.map { Identifier<Server>(rawValue: $0) })
        }
        set {
            Current.settingsStore.prefs.set(newValue.map(\.rawValue), forKey: "deletedServers")
        }
    }

    var info: [Identifier<Server>: ServerInfo] = [:] {
        didSet {
            precondition(deletedServers.isDisjoint(with: info.keys))
        }
    }

    var server: [Identifier<Server>: Server] = [:] {
        didSet {
            precondition(deletedServers.isDisjoint(with: server.keys))
        }
    }

    var all: [Server]?

    mutating func remove(identifier: Identifier<Server>) {
        info[identifier] = nil
        server[identifier] = nil
        all?.removeAll(where: { $0.identifier == identifier })
    }

    mutating func reset() {
        info = [:]
        server = [:]
        all = nil
    }
}

extension Keychain: ServerManagerKeychain {
    public func set(_ value: Data, key: String) throws {
        try set(value, key: key, ignoringAttributeSynchronizable: true)
    }

    public func getData(_ key: String) throws -> Data? {
        try getData(key, ignoringAttributeSynchronizable: true)
    }

    public func remove(_ key: String) throws {
        try remove(key, ignoringAttributeSynchronizable: true)
    }
}

internal final class ServerManagerImpl: ServerManager {
    private var keychain: ServerManagerKeychain
    private var historicKeychain: ServerManagerKeychain
    private var encoder: JSONEncoder
    private var decoder: JSONDecoder

    private var observers = NSHashTable<AnyObject>(options: .weakMemory)

    public func add(observer: ServerObserver) {
        observers.add(observer)
    }

    public func remove(observer: ServerObserver) {
        observers.remove(observer)
    }

    static let service = "io.home-assistant.servers"

    private let cache = HAProtected<ServerCache>(value: .init())

    init(
        keychain: ServerManagerKeychain = Keychain(service: ServerManagerImpl.service),
        historicKeychain: ServerManagerKeychain = Keychain(service: Constants.BundleID)
    ) {
        self.keychain = keychain
        self.historicKeychain = historicKeychain

        let encoder = JSONEncoder()
        self.encoder = encoder
        let decoder = JSONDecoder()
        self.decoder = decoder
    }

    func setup() {
        cache.mutate { value in
            value.restrictCaching = Current.isAppExtension
        }

        // load to cache immediately
        _ = all

        do {
            try migrateIfNeeded()
        } catch {
            Current.Log.error("failed to load historic server: \(error)")
        }
    }

    public var all: [Server] {
        cache.mutate { cache -> [Server] in
            if !cache.restrictCaching, let cachedServers = cache.all {
                return cachedServers
            } else {
                // we sort outside the Server because that will reenter our cache lock
                let all = keychain.allServerInfo(decoder: decoder).sorted(by: { lhs, rhs -> Bool in
                    lhs.1.sortOrder < rhs.1.sortOrder
                }).map { key, value in
                    server(key: key, value: value, currentCache: &cache)
                }
                cache.all = all
                return all
            }
        }
    }

    public func server(for identifier: Identifier<Server>) -> Server? {
        if let fast = cache.read({ $0.server[identifier] }) {
            return fast
        } else {
            return all.first(where: { $0.identifier == identifier })
        }
    }

    @discardableResult
    public func add(identifier: Identifier<Server>, serverInfo: ServerInfo) -> Server {
        let setValue = with(serverInfo) {
            if $0.sortOrder == ServerInfo.defaultSortOrder {
                $0.sortOrder = all.map(\.info.sortOrder).max().map { $0 + 1000 } ?? 0
            }
        }

        let result = cache.mutate { cache -> Server in
            cache.deletedServers.remove(identifier)
            keychain.set(serverInfo: setValue, key: identifier.keychainKey, encoder: encoder)
            cache.info[identifier] = setValue
            cache.all = nil

            return server(key: identifier.keychainKey, value: setValue, currentCache: &cache)
        }

        notify()

        return result
    }

    public func remove(identifier: Identifier<Server>) {
        cache.mutate { cache in
            cache.deletedServers.insert(identifier)
            keychain.deleteServerInfo(key: identifier.keychainKey)
            cache.remove(identifier: identifier)
        }

        notify()
    }

    public func removeAll() {
        cache.mutate { cache in
            cache.deletedServers.formUnion(Set(keychain.allKeys().map { Identifier<Server>(keychainKey: $0) }))
            cache.reset()
            _ = try? keychain.removeAll()
        }

        notify()
    }

    private var suppressNotify = false
    private func notify() {
        guard !suppressNotify else { return }
        DispatchQueue.main.async { [self] in
            for observer in observers.allObjects.compactMap({ $0 as? ServerObserver }) {
                observer.serversDidChange(self)
            }
        }
    }

    private func serverInfoGetter(
        cache: HAProtected<ServerCache>,
        keychain: ServerManagerKeychain,
        identifier: Identifier<Server>,
        decoder: JSONDecoder,
        fallback: ServerInfo
    ) -> () -> ServerInfo {
        {
            cache.mutate { cache -> ServerInfo in
                if !cache.restrictCaching, let info = cache.info[identifier] {
                    return info
                } else {
                    let info = keychain.getServerInfo(key: identifier.keychainKey, decoder: decoder) ?? fallback
                    if !cache.deletedServers.contains(identifier) {
                        cache.info[identifier] = info
                    }
                    return info
                }
            }
        }
    }

    private func serverInfoSetter(
        cache: HAProtected<ServerCache>,
        keychain: ServerManagerKeychain,
        identifier: Identifier<Server>,
        encoder: JSONEncoder,
        notify: @escaping () -> Void
    ) -> (ServerInfo) -> Bool {
        { baseServerInfo in
            var serverInfo = baseServerInfo

            // update active URL so we can update just once if it's different than the save is doing
            // intentionally not in the lock
            _ = serverInfo.connection.activeURL()

            return cache.mutate { cache in
                guard !cache.deletedServers.contains(identifier) else {
                    Current.Log.verbose("ignoring update to deleted server \(identifier)")
                    return false
                }

                let old = cache.info[identifier]

                guard old != serverInfo || cache.restrictCaching else {
                    return false
                }

                keychain.set(serverInfo: serverInfo, key: identifier.keychainKey, encoder: self.encoder)
                cache.info[identifier] = serverInfo

                if old?.sortOrder != serverInfo.sortOrder {
                    cache.all = nil
                }

                notify()
                return true
            }
        }
    }

    private func server(key: String, value: ServerInfo, currentCache: inout ServerCache) -> Server {
        let identifier = Identifier<Server>(keychainKey: key)

        if let server = currentCache.server[identifier] {
            return server
        }

        let server = Server(
            identifier: identifier,
            getter: serverInfoGetter(
                cache: cache,
                keychain: keychain,
                identifier: identifier,
                decoder: decoder,
                fallback: value
            ), setter: serverInfoSetter(
                cache: cache,
                keychain: keychain,
                identifier: identifier,
                encoder: encoder,
                notify: { [weak self] in self?.notify() }
            )
        )
        currentCache.server[identifier] = server
        return server
    }

    private func migrateIfNeeded() throws {
        guard all.isEmpty else { return }

        let userDefaults = Current.settingsStore.prefs
        if let tokenInfoData = try historicKeychain.getData("tokenInfo"),
           let connectionInfoData = try historicKeychain.getData("connectionInfo") {
            Current.Log.info("migrating historic server")

            // UserDefaults may be missing due to delete/reinstall, so fill in values for those if needed
            let versionString = userDefaults.string(forKey: "version") ?? "2021.1"
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
        } else {
            Current.Log.info("no historic server found to import")
        }
    }

    public func restorableState() -> Data {
        var state = [String: ServerInfo]()

        for (id, info) in keychain.allServerInfo(decoder: decoder) {
            state[id] = info
        }

        do {
            return try encoder.encode(state)
        } catch {
            Current.Log.error(error)
            return Data()
        }
    }

    public func restoreState(_ state: Data) {
        suppressNotify = true

        do {
            let state = try decoder.decode([String: ServerInfo].self, from: state)

            // delete servers that aren't present
            for key in keychain.allKeys() where state[key] == nil {
                remove(identifier: .init(keychainKey: key))
            }

            // set the values for the still-existing or new servers
            for (key, serverInfo) in state {
                let identifier = Identifier<Server>(rawValue: key)
                if let existing = cache.read({ $0.server[identifier] }) {
                    existing.info = serverInfo
                } else {
                    add(identifier: identifier, serverInfo: serverInfo)
                }
            }
        } catch {
            Current.Log.error(error)
        }

        suppressNotify = false
        notify()
    }
}

private extension ServerManagerKeychain {
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

            return try decoder.decode(ServerInfo.self, from: data)
        } catch {
            Current.Log.error("failed to get server info for \(key): \(error)")
            return nil
        }
    }

    func set(serverInfo: ServerInfo, key: String, encoder: JSONEncoder) {
        do {
            try set(encoder.encode(serverInfo), key: key)
        } catch {
            Current.Log.error("failed to set server info for \(key): \(error)")
        }
    }

    func deleteServerInfo(key: String) {
        do {
            try remove(key)
        } catch {
            Current.Log.error("failed to get delete \(key): \(error)")
        }
    }
}
