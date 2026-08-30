import Foundation
import GRDB

// `HACalendarEventRecord` itself lives in the `HAModels` package; these are its
// `Current.database()`-backed queries.
public extension HACalendarEventRecord {
    /// Cached events for a calendar overlapping `[start, end)`, oldest first.
    static func events(
        serverId: String,
        calendarEntityId: String,
        start: Date,
        end: Date
    ) async -> [HACalendarEventRecord] {
        do {
            return try await Current.database().read { db in
                try HACalendarEventRecord
                    .filter(Column(DatabaseTables.HACalendarEvent.serverId.rawValue) == serverId)
                    .filter(Column(DatabaseTables.HACalendarEvent.calendarEntityId.rawValue) == calendarEntityId)
                    .filter(Column(DatabaseTables.HACalendarEvent.start.rawValue) < end)
                    .filter(Column(DatabaseTables.HACalendarEvent.end.rawValue) > start)
                    .order(Column(DatabaseTables.HACalendarEvent.start.rawValue))
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to read cached events for \(calendarEntityId), error: \(error)")
            return []
        }
    }

    /// Replaces the cached events for a calendar's `[start, end)` window with `events`.
    ///
    /// Rows are keyed deterministically, so the insert is idempotent; the window delete is what
    /// removes events that have since been deleted server-side. Cached events that ended long ago
    /// are dropped in the same transaction so the table can't grow without bound.
    static func replace(
        _ events: [HACalendarEventRecord],
        serverId: String,
        calendarEntityId: String,
        start: Date,
        end: Date
    ) async {
        let staleBefore = Current.date().addingTimeInterval(-Self.retention)
        do {
            try await Current.database().write { db in
                let calendarRows = HACalendarEventRecord
                    .filter(Column(DatabaseTables.HACalendarEvent.serverId.rawValue) == serverId)
                    .filter(Column(DatabaseTables.HACalendarEvent.calendarEntityId.rawValue) == calendarEntityId)

                try calendarRows
                    .filter(Column(DatabaseTables.HACalendarEvent.start.rawValue) >= start)
                    .filter(Column(DatabaseTables.HACalendarEvent.start.rawValue) < end)
                    .deleteAll(db)
                try calendarRows
                    .filter(Column(DatabaseTables.HACalendarEvent.end.rawValue) < staleBefore)
                    .deleteAll(db)

                for event in events {
                    try event.insert(db, onConflict: .replace)
                }
            }
        } catch {
            Current.Log.error("Failed to cache events for \(calendarEntityId), error: \(error)")
        }
    }

    /// How long a cached event is kept after it ends.
    private static var retention: TimeInterval { 30 * 24 * 60 * 60 }
}
