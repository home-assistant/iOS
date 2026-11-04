import Foundation
import GRDB

// `RemindersSyncItemLink` itself lives in the `HAModels` package; these are its
// `Current.database()`-backed queries.
public extension RemindersSyncItemLink {
    static func links(configId: String) -> [RemindersSyncItemLink] {
        do {
            return try Current.database().read { db in
                try RemindersSyncItemLink
                    .filter(Column(DatabaseTables.RemindersSyncItemLink.configId.rawValue) == configId)
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch reminders sync links, error: \(error.localizedDescription)")
            return []
        }
    }

    func save() {
        do {
            try Current.database().write { db in
                try insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to save reminders sync link \(id), error: \(error.localizedDescription)")
        }
    }

    static func delete(configId: String, todoItemUid: String) {
        let id = id(configId: configId, todoItemUid: todoItemUid)
        do {
            try Current.database().write { db in
                _ = try RemindersSyncItemLink.deleteOne(db, key: id)
            }
        } catch {
            Current.Log.error("Failed to delete reminders sync link \(id), error: \(error.localizedDescription)")
        }
    }
}
