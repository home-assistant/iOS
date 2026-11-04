import Foundation
import GRDB

// `FocusName` itself lives in the `HAModels` package; these are its `Current.database()`-backed
// queries.
public extension FocusName {
    /// Every Focus name the user created, sorted the way the settings screen lists them.
    ///
    /// Throws rather than reporting an empty list, which a caller answering iOS about a name it
    /// already holds must not confuse with the user having deleted it — see the throwing
    /// `FocusNameAppEntityQuery`.
    static func fetchAll() throws -> [FocusName] {
        try Current.database().read { db in
            try FocusName
                .order(Column(DatabaseTables.FocusName.name.rawValue))
                .fetchAll(db)
        }
    }

    /// Throws when the database can't be read, so "this name is gone" stays distinguishable from
    /// "I couldn't look". The Focus Filter turns the first into a deactivation, which wipes the
    /// name the sensors report, so the two must never collapse into each other.
    static func fetch(id: String) throws -> FocusName? {
        try Current.database().read { db in
            try FocusName.fetchOne(db, key: id)
        }
    }

    /// The forgiving read, for the settings screen where an empty list is a display problem rather
    /// than an answer anything acts on.
    static func all() -> [FocusName] {
        do {
            return try fetchAll()
        } catch {
            Current.Log.error("Failed to fetch focus names, error: \(error.localizedDescription)")
            return []
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
