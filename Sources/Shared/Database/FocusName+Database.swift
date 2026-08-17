import Foundation
import GRDB

// `FocusName` itself lives in the `HAModels` package; these are its `Current.database()`-backed
// queries.
public extension FocusName {
    /// Every Focus name the user created, sorted the way the settings screen lists them.
    static func all() -> [FocusName] {
        do {
            return try Current.database().read { db in
                try FocusName
                    .order(Column(DatabaseTables.FocusName.name.rawValue))
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch focus names, error: \(error.localizedDescription)")
            return []
        }
    }

    static func get(id: String) -> FocusName? {
        do {
            return try Current.database().read { db in
                try FocusName.fetchOne(db, key: id)
            }
        } catch {
            Current.Log.error("Failed to fetch focus name \(id), error: \(error.localizedDescription)")
            return nil
        }
    }

    func save() {
        do {
            try Current.database().write { db in
                try insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to save focus name \(id), error: \(error.localizedDescription)")
        }
    }

    func delete() {
        do {
            try Current.database().write { db in
                _ = try FocusName.deleteOne(db, key: id)
            }
        } catch {
            Current.Log.error("Failed to delete focus name \(id), error: \(error.localizedDescription)")
        }
    }
}
