import HAKit
import KeychainAccess
import UserNotifications
import Version

public protocol ServerObserver: AnyObject {
    func serversDidChange(_ serverManager: ServerManager)
}

public protocol ServerManager {
    var all: [Server] { get }
    func server(for identifier: Identifier<Server>) -> Server?
    func serverOrFirstIfAvailable(for identifier: Identifier<Server>) -> Server?

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
        if let rawIdentifier {
            return server(for: .init(rawValue: rawIdentifier))
        } else {
            return nil
        }
    }

    func serverOrFirstIfAvailable(for identifier: Identifier<Server>) -> Server? {
        server(forServerIdentifier: identifier.rawValue) ?? all.first
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

// MARK: - Cache Helpers

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
            if !deletedServers.isDisjoint(with: info.keys) {
                Current.Log
                    .error(
                        "Stale server(s) in info cache overlapping with deleted servers, info keys: \(info.keys), deleted servers: \(deletedServers)"
                    )
            }
        }
    }

    var server: [Identifier<Server>: Server] = [:] {
        didSet {
            if !deletedServers.isDisjoint(with: server.keys) {
                Current.Log
                    .error(
                        "There are server(s) in cache that are deleted also in deleted servers set, servers: \(server.keys), deleted servers: \(deletedServers)"
                    )
            }
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

// MARK: - Server Manager

final class ServerManagerImpl: ServerManager {
    private var keychain: ServerManagerKeychain
    private var historicKeychain: ServerManagerKeychain
    private var mirrorStore: ServerManagerMirrorStore
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

    // MARK: Lifecycle

    init(
        keychain: ServerManagerKeychain = Keychain(service: ServerManagerImpl.service),
        historicKeychain: ServerManagerKeychain = Keychain(service: AppConstants.BundleID),
        mirrorStore: ServerManagerMirrorStore = ServerManagerGRDBMirrorStore()
    ) {
        self.keychain = keychain
        self.historicKeychain = historicKeychain
        self.mirrorStore = mirrorStore

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

        // Keep a sanitized startup snapshot of non-secret server metadata so the app
        // can still recover server shells if the developer-account migration wipes
        // Keychain data later on.
        syncMirrorStoreFromKeychain()
    }

    public var all: [Server] {
        let snapshot = cache.read { cache in
            (
                restrictCaching: cache.restrictCaching,
                deletedServers: cache.deletedServers,
                cachedServers: cache.all
            )
        }

        if !snapshot.restrictCaching, let cachedServers = snapshot.cachedServers {
            return cachedServers
        }

        // Read from Keychain and GRDB outside the cache lock so persistence I/O
        // does not block unrelated server-manager operations.
        let persistedServers = mergedServerInfo(deletedServers: snapshot.deletedServers)
            .sorted(by: { lhs, rhs -> Bool in
                lhs.1.sortOrder < rhs.1.sortOrder
            })

        if let cachedOrFreshServers = cache.mutate(using: { cache -> [Server]? in
            if !cache.restrictCaching, let cachedServers = cache.all {
                return cachedServers
            }

            guard cache.deletedServers == snapshot.deletedServers else {
                return nil
            }

            let all = persistedServers.map { key, value in
                server(key: key, value: value, currentCache: &cache)
            }
            cache.all = all
            return all
        }) {
            return cachedOrFreshServers
        }

        // Avoid retrying forever when another thread keeps mutating the server set.
        // In that case we return a best-effort fresh view and let a later access cache it.
        let latestDeletedServers = cache.read(\.deletedServers)
        let latestPersistedServers = mergedServerInfo(deletedServers: latestDeletedServers)
            .sorted(by: { lhs, rhs -> Bool in
                lhs.1.sortOrder < rhs.1.sortOrder
            })

        return cache.mutate { cache in
            latestPersistedServers.map { key, value in
                server(key: key, value: value, currentCache: &cache)
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

    // MARK: Mutations

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
            let allKeys = Set(keychain.allKeys() + mirrorStore.allKeys())
            cache.deletedServers.formUnion(Set(allKeys.map { Identifier<Server>(keychainKey: $0) }))
            cache.reset()
            _ = try? keychain.removeAll()
        }

        notify()
    }

    // MARK: Cache and Observation

    private var suppressNotify = false
    private func notify() {
        guard !suppressNotify else { return }
        DispatchQueue.main.async { [self] in
            for observer in observers.allObjects.compactMap({ $0 as? ServerObserver }) {
                observer.serversDidChange(self)
            }
        }
    }

    // MARK: Server Accessors

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
                    // Prefer live Keychain data, but fall back to the last startup
                    // snapshot in GRDB when the Keychain entry is gone.
                    let info = keychain.getServerInfo(key: identifier.keychainKey, decoder: decoder)
                        ?? self.mirrorStore.getServerInfo(identifier.keychainKey)
                        ?? fallback
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

                keychain.set(serverInfo: serverInfo, key: identifier.keychainKey, encoder: encoder)
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

    // MARK: Mirror Reconciliation

    private func mergedServerInfo(deletedServers: Set<Identifier<Server>>) -> [(String, ServerInfo)] {
        // When both stores have a copy, prefer Keychain because it still contains the
        // full record. The mirror is only a best-effort recovery snapshot.
        let keychainValues = Dictionary(uniqueKeysWithValues: keychain.allServerInfo(decoder: decoder))
        let mirrorValues = Dictionary(uniqueKeysWithValues: mirrorStore.allServerInfo())
        return mirrorValues
            .merging(keychainValues, uniquingKeysWith: { _, keychainInfo in keychainInfo })
            .filter { key, _ in
                !deletedServers.contains(.init(keychainKey: key))
            }
            .map { ($0.key, $0.value) }
    }

    private func syncMirrorStoreFromKeychain() {
        // The mirror is a best-effort startup snapshot, not a second source of truth.
        // Rebuild it from the current Keychain contents whenever the app opens.
        mirrorStore.removeAll()
        for (key, value) in keychain.allServerInfo(decoder: decoder) {
            mirrorStore.set(value, key: key)
        }
    }

    // MARK: Migration

    private func migrateIfNeeded() throws {
        guard all.isEmpty else { return }

        let userDefaults = Current.settingsStore.prefs
        if let tokenInfoData = try historicKeychain.getData("tokenInfo"),
           let connectionInfoData = try historicKeychain.getData("connectionInfo") {
            Current.Log.info("migrating historic server")

            // UserDefaults may be missing due to delete/reinstall, so fill in values for those if needed
            let versionString = userDefaults.string(forKey: "version") ?? "2021.1"
            let name = userDefaults.string(forKey: "location_name") ?? ServerInfo.defaultName

            var serverInfo = try ServerInfo(
                name: name,
                connection: decoder.decode(ConnectionInfo.self, from: connectionInfoData),
                token: decoder.decode(TokenInfo.self, from: tokenInfoData),
                version: Version(hassVersion: versionString)
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

    // MARK: State Restoration

    public func restorableState() -> Data {
        var state = [String: ServerInfo]()

        for (id, info) in mergedServerInfo(deletedServers: cache.read({ $0.deletedServers })) {
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
            for key in Set(keychain.allKeys() + mirrorStore.allKeys()) where state[key] == nil {
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
