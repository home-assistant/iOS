import Foundation
import GRDB

// `SiriServerExposure` itself lives in the `HAModels` package; these are its
// `Current.database()`-backed queries.
public extension SiriServerExposure {
    /// The ids of servers the user has opted out of exposing.
    ///
    /// Read synchronously and cached, because the entity queries and the Spotlight indexer consult
    /// it on paths that are not async and run per entity.
    static func hiddenServerIds() -> Set<String> {
        do {
            return try Current.database().read { db in
                let rows = try SiriServerExposure.fetchAll(db)
                return Set(rows.filter { !$0.isExposed }.map(\.serverId))
            }
        } catch {
            // Failing open matches how every server behaved before the setting existed, and a
            // read error should not silently hide someone's entities from Siri.
            Current.Log.error("Failed to read Siri exposure, error: \(error.localizedDescription)")
            return []
        }
    }

    /// Whether the server may offer its entities. A server with no row has never been changed, and
    /// is exposed.
    static func isExposed(serverId: String) -> Bool {
        !hiddenServerIds().contains(serverId)
    }

    static func setExposed(_ isExposed: Bool, serverId: String) {
        do {
            try Current.database().write { db in
                try SiriServerExposure(serverId: serverId, isExposed: isExposed)
                    .insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to save Siri exposure for \(serverId), error: \(error.localizedDescription)")
        }
    }

    /// Drops the row for a server that no longer exists, so a later server reusing the identifier
    /// does not inherit a stale choice.
    static func delete(serverId: String) {
        do {
            _ = try Current.database().write { db in
                try SiriServerExposure.deleteOne(db, key: serverId)
            }
        } catch {
            Current.Log.error("Failed to delete Siri exposure for \(serverId), error: \(error.localizedDescription)")
        }
    }
}
