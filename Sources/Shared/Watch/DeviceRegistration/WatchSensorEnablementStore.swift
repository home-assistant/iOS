import Foundation

/// Persists which of the watch's own sensors the user switched on, for each server separately.
///
/// Enablement is an allowlist per server, as it is on the iPhone: a sensor reports to a server only
/// while its unique ID is in that server's list, and a server the watch learns about later starts
/// with nothing enabled. Installs that predate this stored one list shared by every server; that
/// list is handed to each server the watch already has, once, so nothing the user switched on stops
/// reporting where it used to. See `splitAcrossServersIfNeeded()`.
public final class WatchSensorEnablementStore {
    private enum Key {
        /// The one list every server shared before they were chosen per server. Only the split reads it.
        static let legacyEnabled = WatchUserDefaultsKey.enabledSensorIDs.rawValue
        static let enabledByServer = WatchUserDefaultsKey.enabledSensorIDsByServer.rawValue
        static let splitAcrossServers = WatchUserDefaultsKey.enabledSensorIDsSplitAcrossServers.rawValue
    }

    private let defaults: UserDefaults
    private let servers: () -> [Server]

    /// Serialises the one-time split and every read-modify-write of the allowlists, which the
    /// reporter and the settings screen reach from different threads.
    private let lock = NSLock()

    /// - Parameters:
    ///   - defaults: where the allowlists live; the watch's standard defaults in production.
    ///   - servers: the servers the watch currently has, which is what the split hands the shared
    ///     selection to.
    public init(defaults: UserDefaults, servers: @escaping () -> [Server]) {
        self.defaults = defaults
        self.servers = servers
    }

    // MARK: - Reading and writing

    public func enabledSensorIDs(forServer serverID: Identifier<Server>) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }

        splitAcrossServersIfNeeded()
        return enabledSensorIDsByServer[serverID.rawValue] ?? []
    }

    public func isSensorEnabled(uniqueID: String, forServer serverID: Identifier<Server>) -> Bool {
        enabledSensorIDs(forServer: serverID).contains(uniqueID)
    }

    public func setSensorEnabled(_ enabled: Bool, uniqueID: String, forServer serverID: Identifier<Server>) {
        lock.lock()
        defer { lock.unlock() }

        splitAcrossServersIfNeeded()

        var byServer = enabledSensorIDsByServer
        var ids = byServer[serverID.rawValue] ?? []
        if enabled {
            ids.insert(uniqueID)
        } else {
            ids.remove(uniqueID)
        }
        byServer[serverID.rawValue] = ids
        enabledSensorIDsByServer = byServer
    }

    /// Drops the allowlists of every server other than `serverIDs`, so the watch stops carrying
    /// choices for servers the iPhone no longer has. A server that comes back is registered under
    /// its identifier again and starts opt-in like any other new server, as it does on the iPhone.
    public func forgetServers(otherThan serverIDs: [Identifier<Server>]) {
        lock.lock()
        defer { lock.unlock() }

        let keep = Set(serverIDs.map(\.rawValue))
        let byServer = enabledSensorIDsByServer
        let remaining = byServer.filter { keep.contains($0.key) }
        guard remaining.count != byServer.count else { return }
        enabledSensorIDsByServer = remaining
    }

    // MARK: - Migration

    /// Gives every server the watch already has the one selection they used to share, once.
    ///
    /// Does nothing while the watch has no servers — one that hasn't synced with its iPhone yet, or
    /// a process that reached here before they were restored — and is retried on the next read, so
    /// a selection is never split away to nobody and lost. The shared list is removed once it has
    /// been handed out, and nothing reads it again.
    private func splitAcrossServersIfNeeded() {
        guard !defaults.bool(forKey: Key.splitAcrossServers) else { return }

        let serverIDs = servers().map(\.identifier.rawValue)
        guard !serverIDs.isEmpty else { return }

        let inherited = Set(defaults.stringArray(forKey: Key.legacyEnabled) ?? [])
        var byServer = enabledSensorIDsByServer
        for serverID in serverIDs {
            byServer[serverID] = (byServer[serverID] ?? []).union(inherited)
        }
        enabledSensorIDsByServer = byServer
        defaults.set(true, forKey: Key.splitAcrossServers)
        defaults.removeObject(forKey: Key.legacyEnabled)
    }

    // MARK: - Storage

    private var enabledSensorIDsByServer: [String: Set<String>] {
        get {
            let stored = defaults.object(forKey: Key.enabledByServer) as? [String: [String]] ?? [:]
            return stored.mapValues(Set.init)
        }
        set {
            defaults.set(newValue.mapValues { $0.sorted() }, forKey: Key.enabledByServer)
        }
    }
}
