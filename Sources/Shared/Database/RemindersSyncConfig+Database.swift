import Foundation
import GRDB

// `RemindersSyncConfig` itself lives in the `HAModels` package; these are its
// `Current.database()`-backed queries.
public extension RemindersSyncConfig {
    static func all() -> [RemindersSyncConfig] {
        do {
            return try Current.database().read { db in
                try RemindersSyncConfig
                    .order(Column(DatabaseTables.RemindersSyncConfig.todoEntityName.rawValue))
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch reminders sync configs, error: \(error.localizedDescription)")
            return []
        }
    }

    func save() {
        do {
            try Current.database().write { db in
                try insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to save reminders sync config \(id), error: \(error.localizedDescription)")
        }
    }

    /// Deletes the config together with its item links.
    func delete() {
        do {
            try Current.database().write { db in
                _ = try RemindersSyncItemLink
                    .filter(Column(DatabaseTables.RemindersSyncItemLink.configId.rawValue) == id)
                    .deleteAll(db)
                _ = try RemindersSyncConfig.deleteOne(db, key: id)
            }
        } catch {
            Current.Log.error("Failed to delete reminders sync config \(id), error: \(error.localizedDescription)")
        }
    }
}
