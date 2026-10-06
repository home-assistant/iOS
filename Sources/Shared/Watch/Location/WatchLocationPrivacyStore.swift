import Foundation

/// Persists what each server receives of the watch's own location: the exact fix, only the zone
/// the watch is in, or nothing.
///
/// The choice is the watch's, not the iPhone's. The watch reports as a `mobile_app` device of its
/// own, and its server configuration is overwritten by every sync from the iPhone, so the choice
/// can't live in `ServerInfo` the way the iPhone's `locationPrivacy` does. Like the watch's sensors,
/// it is opt-in and per server: a server with no stored choice receives nothing, and a server the
/// watch learns about later starts that way too.
public final class WatchLocationPrivacyStore {
    enum Key {
        /// Server identifier to `ServerLocationPrivacy` raw value. Absent means `.never`.
        static let privacyByServer = "locationPrivacyByServer"
    }

    private let defaults: UserDefaults

    /// Serialises every read-modify-write, which the reporter, the zone monitor and the settings
    /// screen reach from different threads.
    private let lock = NSLock()

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func locationPrivacy(forServer serverID: Identifier<Server>) -> ServerLocationPrivacy {
        lock.lock()
        defer { lock.unlock() }

        return privacyByServer[serverID.rawValue].flatMap(ServerLocationPrivacy.init(rawValue:)) ?? .never
    }

    public func setLocationPrivacy(_ privacy: ServerLocationPrivacy, forServer serverID: Identifier<Server>) {
        lock.lock()
        defer { lock.unlock() }

        var byServer = privacyByServer
        if privacy == .never {
            byServer.removeValue(forKey: serverID.rawValue)
        } else {
            byServer[serverID.rawValue] = privacy.rawValue
        }
        privacyByServer = byServer
    }

    /// Drops the choices of every server a sync from the iPhone left out, so a server that comes
    /// back later starts opt-in like any other new server.
    public func applySyncedServers(_ serverIDs: [Identifier<Server>]) {
        lock.lock()
        defer { lock.unlock() }

        let keep = Set(serverIDs.map(\.rawValue))
        let byServer = privacyByServer
        let remaining = byServer.filter { keep.contains($0.key) }
        guard remaining.count != byServer.count else { return }
        privacyByServer = remaining
    }

    private var privacyByServer: [String: String] {
        get { defaults.dictionary(forKey: Key.privacyByServer) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: Key.privacyByServer) }
    }
}
