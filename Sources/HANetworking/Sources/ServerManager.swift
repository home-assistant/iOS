import HAKit
import KeychainAccess
import UserNotifications

public protocol ServerObserver: AnyObject {
    func serversDidChange(_ serverManager: ServerManager)
}

public protocol ServerManager {
    var all: [Server] { get }
    var isMirrorRestorePending: Bool { get }
    func server(for identifier: Identifier<Server>) -> Server?
    func serverOrFirstIfAvailable(for identifier: Identifier<Server>) -> Server?
    @discardableResult
    func restoreKeychainFromMirrorIfNeeded() -> Bool

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

    // `server(for: ServerIdentifierProviding)` lives in the Shared module
    // (ServerManager+ServerProviding.swift) because that protocol isn't available in this package.

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
    init(keychainKey: String) { self.init(rawValue: keychainKey) }
}

private struct ServerCache {
    var restrictCaching: Bool = false
    var info: [Identifier<Server>: ServerInfo] = [:]
    var server: [Identifier<Server>: Server] = [:]
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

public final class ServerManagerImpl: ServerManager {
    private static let restoredMirroredServersKey = "restoredMirroredServers"

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

    private var deletedServers: Set<Identifier<Server>> {
        get {
            let identifiers = HANetworkingEnvironment.current.prefs.array(forKey: "deletedServers") as? [String] ?? []
            return Set(identifiers.map { Identifier<Server>(rawValue: $0) })
        }
        set {
            HANetworkingEnvironment.current.prefs.set(newValue.map(\.rawValue), forKey: "deletedServers")
        }
    }

    // MARK: Lifecycle

    /// Convenience no-arg initializer used by HACore's `Current.servers`; supplies the default keychain
    /// + GRDB mirror store. The designated initializer takes them explicitly (used by tests to inject fakes).
    public convenience init() {
        self.init(
            keychain: Keychain(service: ServerManagerImpl.service),
            historicKeychain: Keychain(service: HANetworkingEnvironment.current.bundleID),
            mirrorStore: ServerManagerGRDBMirrorStore()
        )
    }

    public init(
        keychain: ServerManagerKeychain,
        historicKeychain: ServerManagerKeychain,
        mirrorStore: ServerManagerMirrorStore
    ) {
        self.keychain = keychain
        self.historicKeychain = historicKeychain
        self.mirrorStore = mirrorStore

        let encoder = JSONEncoder()
        self.encoder = encoder
        let decoder = JSONDecoder()
        self.decoder = decoder
    }

    public func setup() {
        cache.mutate { value in
            value.restrictCaching = HANetworkingEnvironment.current.isAppExtension()
        }

        // load to cache immediately
        _ = all

        do {
            try migrateIfNeeded()
        } catch {
            HANetworkingEnvironment.current.log.error("failed to load historic server: \(error)")
        }

        // Keep a sanitized startup snapshot of non-secret server metadata so the app
        // can still recover server shells if the developer-account migration wipes
        // Keychain data later on.
        syncMirrorStoreFromKeychainIfNeeded()
    }

    public var all: [Server] {
        let deletedServers = deletedServers
        let snapshot = cache.read { cache in
            (
                restrictCaching: cache.restrictCaching,
                cachedServers: cache.all
            )
        }

        if !snapshot.restrictCaching, let cachedServers = snapshot.cachedServers {
            return cachedServers
        }

        // Read from Keychain and GRDB outside the cache lock so persistence I/O
        // does not block unrelated server-manager operations.
        let persistedServers = mergedServerInfo(deletedServers: deletedServers)
            .sorted(by: { lhs, rhs -> Bool in
                lhs.1.sortOrder < rhs.1.sortOrder
            })

        let deletedServersUnchanged = self.deletedServers == deletedServers
        if let cachedOrFreshServers = cache.mutate(using: { cache -> [Server]? in
            if !cache.restrictCaching, let cachedServers = cache.all {
                return cachedServers
            }

            guard deletedServersUnchanged else {
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
        let latestDeletedServers = self.deletedServers
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

        var deletedServers = deletedServers
        if deletedServers.remove(identifier) != nil {
            self.deletedServers = deletedServers
        }

        let result = cache.mutate { cache -> Server in
            keychain.set(serverInfo: setValue, key: identifier.keychainKey, encoder: encoder)
            cache.info[identifier] = setValue
            cache.all = nil

            return server(key: identifier.keychainKey, value: setValue, currentCache: &cache)
        }

        mirrorStore.set(setValue, key: identifier.keychainKey)
        var restoredMirroredServers = restoredMirroredServers
        if restoredMirroredServers.remove(identifier.keychainKey) != nil {
            self.restoredMirroredServers = restoredMirroredServers
        }

        notify()

        return result
    }

    public func remove(identifier: Identifier<Server>) {
        var deletedServers = deletedServers
        deletedServers.insert(identifier)
        self.deletedServers = deletedServers

        cache.mutate { cache in
            keychain.deleteServerInfo(key: identifier.keychainKey)
            cache.remove(identifier: identifier)
        }

        mirrorStore.remove(identifier.keychainKey)
        var restoredMirroredServers = restoredMirroredServers
        if restoredMirroredServers.remove(identifier.keychainKey) != nil {
            self.restoredMirroredServers = restoredMirroredServers
        }

        notify()
    }

    public func removeAll() {
        let allKeys = Set(keychain.allKeys() + mirrorStore.allKeys())
        var deletedServers = deletedServers
        deletedServers.formUnion(Set(allKeys.map { Identifier<Server>(keychainKey: $0) }))
        self.deletedServers = deletedServers

        cache.mutate { cache in
            cache.reset()
            _ = try? keychain.removeAll()
        }

        mirrorStore.removeAll()
        restoredMirroredServers = []

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
            if let cached = cache.read({ cache -> ServerInfo? in
                cache.restrictCaching ? nil : cache.info[identifier]
            }) {
                return cached
            }

            let deletedServers = self.deletedServers
            return cache.mutate { cache -> ServerInfo in
                if !cache.restrictCaching, let info = cache.info[identifier] {
                    return info
                } else {
                    // Prefer live Keychain data, but fall back to the last startup
                    // snapshot in GRDB when the Keychain entry is gone.
                    let keychainInfo = keychain.getServerInfo(key: identifier.keychainKey, decoder: decoder)
                    let mirroredInfo = keychainInfo == nil ? self.mirrorStore
                        .getServerInfo(identifier.keychainKey) : nil
                    let shouldUseMirrorFallback = !(keychain.allKeys().isEmpty && mirroredInfo != nil)
                    let info = keychainInfo
                        ?? (shouldUseMirrorFallback ? mirroredInfo : nil)
                        ?? fallback
                    if !deletedServers.contains(identifier) {
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
        { [weak self] baseServerInfo in
            var serverInfo = baseServerInfo

            // update active URL so we can update just once if it's different than the save is doing
            // intentionally not in the lock
            _ = serverInfo.connection.evaluateActiveURL()

            let deletedServers = self?.deletedServers ?? []
            return cache.mutate { cache in
                guard !deletedServers.contains(identifier) else {
                    HANetworkingEnvironment.current.log.verbose("ignoring update to deleted server \(identifier)")
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
        let keychainValues = Dictionary(uniqueKeysWithValues: keychain.allServerInfo(decoder: decoder))
        guard !keychainValues.isEmpty else {
            return []
        }

        // When both stores have a copy, prefer Keychain because it still contains the
        // full record. The mirror is only a best-effort recovery snapshot.
        let mirrorValues = Dictionary(uniqueKeysWithValues: mirrorStore.allServerInfo())
        return mirrorValues
            .merging(keychainValues, uniquingKeysWith: { _, keychainInfo in keychainInfo })
            .filter { key, _ in
                !deletedServers.contains(.init(keychainKey: key))
            }
            .map { ($0.key, $0.value) }
    }

    private func syncMirrorStoreFromKeychainIfNeeded() {
        pruneDeletedMirroredServers()

        // Preserve the mirror while the recovery UI is deciding whether to restore
        // mirrored servers back into Keychain, and never let an empty Keychain wipe
        // the last preserved snapshot.
        if keychain.allKeys().isEmpty || isMirrorRestorePending {
            return
        }

        syncMirrorStoreFromKeychain()
    }

    private func syncMirrorStoreFromKeychain() {
        // The mirror is a best-effort startup snapshot, not a second source of truth.
        // Rebuild it from the current Keychain contents whenever the app opens.
        mirrorStore.removeAll()
        for (key, value) in keychain.allServerInfo(decoder: decoder) {
            mirrorStore.set(value, key: key)
        }
        pruneRestoredMirroredServers(validKeys: Set(mirrorStore.allKeys()))
    }

    private var restoredMirroredServers: Set<String> {
        get {
            let values = HANetworkingEnvironment.current.prefs
                .array(forKey: Self.restoredMirroredServersKey) as? [String] ?? []
            return Set(values)
        }
        set {
            HANetworkingEnvironment.current.prefs.set(Array(newValue).sorted(), forKey: Self.restoredMirroredServersKey)
        }
    }

    private func pruneRestoredMirroredServers(validKeys: Set<String>) {
        let pruned = restoredMirroredServers.intersection(validKeys)
        guard pruned != restoredMirroredServers else { return }
        restoredMirroredServers = pruned
    }

    private func pruneDeletedMirroredServers() {
        let deletedKeys = Set(deletedServers.map(\.keychainKey))
        guard !deletedKeys.isEmpty else { return }

        let mirrorKeys = Set(mirrorStore.allKeys())
        let keysToRemove = mirrorKeys.intersection(deletedKeys)
        guard !keysToRemove.isEmpty else { return }

        for key in keysToRemove {
            mirrorStore.remove(key)
        }

        pruneRestoredMirroredServers(validKeys: mirrorKeys.subtracting(keysToRemove))
    }

    private func restorableMirroredServers(excludingPreviouslyRestored: Bool = false) -> [(String, ServerInfo)] {
        let deletedServers = deletedServers
        let restoredMirroredServers = excludingPreviouslyRestored ? restoredMirroredServers : []
        return mirrorStore.allServerInfo().filter { key, _ in
            !deletedServers.contains(.init(keychainKey: key)) && !restoredMirroredServers.contains(key)
        }
    }

    public var isMirrorRestorePending: Bool {
        keychain.allKeys().isEmpty && !restorableMirroredServers(excludingPreviouslyRestored: true).isEmpty
    }

    @discardableResult
    public func restoreKeychainFromMirrorIfNeeded() -> Bool {
        guard keychain.allKeys().isEmpty else { return false }

        let mirroredServers = restorableMirroredServers(excludingPreviouslyRestored: true)
        guard !mirroredServers.isEmpty else { return false }

        // Rehydrate the Keychain with the sanitized mirror so startup sees the same
        // server list and WebView can continue through the empty-token reauth flow.
        for (key, value) in mirroredServers {
            keychain.set(serverInfo: value, key: key, encoder: encoder)
        }
        var restoredMirroredServers = restoredMirroredServers
        restoredMirroredServers.formUnion(mirroredServers.map(\.0))
        self.restoredMirroredServers = restoredMirroredServers

        cache.mutate { cache in
            cache.reset()
        }

        notify()
        return true
    }

    // MARK: Migration

    private func migrateIfNeeded() throws {
        guard all.isEmpty else { return }

        let userDefaults = HANetworkingEnvironment.current.prefs
        if let tokenInfoData = try historicKeychain.getData("tokenInfo"),
           let connectionInfoData = try historicKeychain.getData("connectionInfo") {
            HANetworkingEnvironment.current.log.info("migrating historic server")

            // UserDefaults may be missing due to delete/reinstall, so fill in values for those if needed
            let versionString = userDefaults.string(forKey: "version") ?? "2021.1"
            let name = userDefaults.string(forKey: "location_name") ?? HANetworkingEnvironment.current.defaultServerName

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
            HANetworkingEnvironment.current.log.info("no historic server found to import")
        }
    }

    // MARK: State Restoration

    public func restorableState() -> Data {
        var state = [String: ServerInfo]()

        for (id, info) in mergedServerInfo(deletedServers: deletedServers) {
            state[id] = info
        }

        do {
            return try encoder.encode(state)
        } catch {
            HANetworkingEnvironment.current.log.error(error)
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
                    var incoming = serverInfo
                    // Don't let a restored snapshot downgrade a token this instance already refreshed to a
                    // later expiry — e.g. the watch refreshing independently of the phone that produced this
                    // snapshot. Keeping the fresher token avoids sending a stale one the server rejects.
                    let current = existing.info.token
                    if current.expiration > incoming.token.expiration {
                        incoming.token = current
                    }
                    existing.info = incoming
                } else {
                    add(identifier: identifier, serverInfo: serverInfo)
                }
            }
        } catch {
            HANetworkingEnvironment.current.log.error(error)
        }

        suppressNotify = false
        notify()
    }
}
