import Foundation
import GRDB

// `RemindersSyncHistoryEntry` itself lives in the `HAModels` package; these are its
// `Current.database()`-backed queries.
public extension RemindersSyncHistoryEntry {
    /// Entries capped to keep the history readable and the table small.
    static let maxStoredEntries = 200

    static func all() -> [RemindersSyncHistoryEntry] {
        do {
            return try Current.database().read { db in
                try RemindersSyncHistoryEntry
                    .order(Column(DatabaseTables.RemindersSyncHistoryEntry.date.rawValue).desc)
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch reminders sync history, error: \(error.localizedDescription)")
            return []
        }
    }

    /// Saves the entry and prunes the oldest entries beyond `maxStoredEntries`.
    func save() {
        do {
            try Current.database().write { db in
                try insert(db, onConflict: .replace)
                let dateColumn = Column(DatabaseTables.RemindersSyncHistoryEntry.date.rawValue)
                let keptIds = try RemindersSyncHistoryEntry
                    .select(Column(DatabaseTables.RemindersSyncHistoryEntry.id.rawValue), as: String.self)
                    .order(dateColumn.desc)
                    .limit(Self.maxStoredEntries)
                    .fetchAll(db)
                try RemindersSyncHistoryEntry
                    .filter(!keptIds.contains(Column(DatabaseTables.RemindersSyncHistoryEntry.id.rawValue)))
                    .deleteAll(db)
            }
        } catch {
            Current.Log.error("Failed to save reminders sync history entry, error: \(error.localizedDescription)")
        }
    }

    static func deleteAll() {
        do {
            _ = try Current.database().write { db in
                try RemindersSyncHistoryEntry.deleteAll(db)
            }
        } catch {
            Current.Log.error("Failed to clear reminders sync history, error: \(error.localizedDescription)")
        }
    }
}
