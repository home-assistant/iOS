import Foundation
import GRDB
import HAKit

/// Keeps the watch's copy of each server's zones, which zone-only location reports are worked out
/// against.
///
/// The iPhone learns its zones over the WebSocket; the watch has no reliable WebSocket, and the
/// phone doesn't mirror zones to it, so the watch fetches them itself over REST into its own
/// `AppZone` table. Zones rarely change, so a server's are fetched again only once they are
/// `maximumAge` old, or when a caller asks for it.
///
/// Compiled on every platform so the parsing and storage stay covered by unit tests.
public enum WatchZoneSync {
    /// How long a server's zones are trusted before they're fetched again.
    public static let maximumAge: TimeInterval = 6 * 60 * 60

    /// Fetches a server's `GET /api/states` body.
    public typealias Fetch = (Server, TimeInterval) async throws -> Any

    /// The real transport: the server's REST API.
    public static func fetchStates(server: Server, timeout: TimeInterval) async throws -> Any {
        try await HomeAssistantRESTClient.sendForJSON(server: server, path: ["states"], timeout: timeout)
    }

    /// Refreshes `server`'s zones when they're older than `maximumAge`, or always with `force`.
    /// Returns whether the stored zones changed.
    @discardableResult
    public static func refreshIfNeeded(
        server: Server,
        force: Bool = false,
        timeout: TimeInterval = HomeAssistantRESTClient.defaultTimeout,
        defaults: UserDefaults = .standard,
        fetch: Fetch = WatchZoneSync.fetchStates
    ) async throws -> Bool {
        let key = lastRefreshKey(for: server.identifier)
        if !force, let last = defaults.object(forKey: key) as? Date,
           Current.date().timeIntervalSince(last) < maximumAge {
            return false
        }

        let json = try await fetch(server, timeout)
        let zones = zones(fromRESTStates: json, server: server)
        let changed = try replaceZones(zones, for: server.identifier)
        defaults.set(Current.date(), forKey: key)
        Current.Log.info("refreshed \(zones.count) zones for \(server.info.name) on the watch (changed: \(changed))")
        return changed
    }

    /// The zones in a `GET /api/states` body, mapped the same way the iPhone maps the zones it gets
    /// over the WebSocket.
    public static func zones(fromRESTStates json: Any, server: Server) -> [AppZone] {
        AppIntentServerAPI.entities(fromRESTStates: json, domain: .zone).compactMap { entity in
            var zone = AppZone(primaryKey: "", serverIdentifier: server.identifier.rawValue)
            return zone.update(with: entity, server: server) ? zone : nil
        }
    }

    /// Replaces every stored zone of one server with `zones`, leaving other servers' alone.
    /// Returns whether anything changed.
    @discardableResult
    public static func replaceZones(_ zones: [AppZone], for serverID: Identifier<Server>) throws -> Bool {
        try Current.database().write { db -> Bool in
            let serverColumn = Column(DatabaseTables.AppZone.serverIdentifier.rawValue)
            let existing = try AppZone.filter(serverColumn == serverID.rawValue).fetchAll(db)
            guard Set(existing) != Set(zones) else { return false }

            try AppZone.filter(serverColumn == serverID.rawValue).deleteAll(db)
            for zone in zones {
                try zone.insert(db, onConflict: .replace)
            }
            return true
        }
    }

    /// Forgets a server's zones, for a server whose location the user stopped sharing.
    public static func removeZones(for serverID: Identifier<Server>, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: lastRefreshKey(for: serverID))
        do {
            try replaceZones([], for: serverID)
        } catch {
            Current.Log.error("failed removing zones for \(serverID.rawValue) on the watch: \(error)")
        }
    }

    /// Forgets the zones of every server not in `serverIDs`: those a sync from the iPhone removed,
    /// and those no longer sending zone-only reports.
    public static func removeZones(exceptFor serverIDs: Set<Identifier<Server>>, defaults: UserDefaults = .standard) {
        let stored = Set(AppZone.all().map { Identifier<Server>(rawValue: $0.serverIdentifier) })
        for serverID in stored.subtracting(serverIDs) {
            removeZones(for: serverID, defaults: defaults)
        }
    }

    private static func lastRefreshKey(for serverID: Identifier<Server>) -> String {
        "watchZonesRefreshedAt.\(serverID.rawValue)"
    }
}
