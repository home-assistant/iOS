import Foundation
import GRDB

// `HACalendar` itself lives in the `HAModels` package; these are its `Current.database()`-backed
// queries.
public extension HACalendar {
    /// Every calendar stored for a server, in the order the frontend lists them (entity id).
    static func all(serverId: String) -> [HACalendar] {
        do {
            return try Current.database().read { db in
                try HACalendar
                    .filter(Column(DatabaseTables.HACalendar.serverId.rawValue) == serverId)
                    .order(Column(DatabaseTables.HACalendar.sortOrder.rawValue))
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch calendars for server \(serverId), error: \(error)")
            return []
        }
    }

    /// Every stored calendar across every server, ordered by server then by the frontend's order.
    static func all() -> [HACalendar] {
        do {
            return try Current.database().read { db in
                try HACalendar
                    .order(
                        Column(DatabaseTables.HACalendar.serverId.rawValue),
                        Column(DatabaseTables.HACalendar.sortOrder.rawValue)
                    )
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch calendars, error: \(error)")
            return []
        }
    }

    static func get(id: String) -> HACalendar? {
        do {
            return try Current.database().read { db in
                try HACalendar.fetchOne(db, key: id)
            }
        } catch {
            Current.Log.error("Failed to fetch calendar \(id), error: \(error)")
            return nil
        }
    }

    /// Replaces every stored calendar for a server with `calendars`, in one transaction.
    /// Returns `false` when the write failed; a no-op refresh (nothing changed) still returns `true`.
    @discardableResult
    static func replaceAll(_ calendars: [HACalendar], serverId: String) async -> Bool {
        let stored = try? await Current.database().read { db in
            try HACalendar
                .filter(Column(DatabaseTables.HACalendar.serverId.rawValue) == serverId)
                .order(Column(DatabaseTables.HACalendar.sortOrder.rawValue))
                .fetchAll(db)
        }
        if let stored, stored == calendars {
            Current.Log.verbose("Calendars unchanged for server \(serverId), skipping database write")
            return true
        }

        do {
            try await Current.database().write { db in
                try HACalendar
                    .filter(Column(DatabaseTables.HACalendar.serverId.rawValue) == serverId)
                    .deleteAll(db)
                for calendar in calendars {
                    try calendar.insert(db)
                }
            }
            Current.Log.verbose("Successfully saved \(calendars.count) calendars for server \(serverId)")
            return true
        } catch {
            Current.Log.error("Failed to save calendars for server \(serverId), error: \(error)")
            Current.clientEventStore.addEvent(.init(
                text: "Failed to save calendars in database, error on serverId \(serverId)",
                type: .database,
                payload: [
                    "error": error.localizedDescription,
                ]
            ))
            return false
        }
    }
}
