import Foundation
import GRDB

// `AllowedTag` itself lives in the `HAModels` package; these are its database-backed helpers.
public extension AllowedTag {
    static func contains(_ tag: String) -> Bool {
        do {
            return try Current.database().read { db in
                try AllowedTag.fetchOne(db, key: tag) != nil
            }
        } catch {
            Current.Log.error("Failed to fetch allowed tag \(tag), error: \(error.localizedDescription)")
            return false
        }
    }

    static func all() -> [AllowedTag] {
        do {
            return try Current.database().read { db in
                try AllowedTag
                    .order(Column(DatabaseTables.AllowedTag.tag.rawValue))
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch allowed tags, error: \(error.localizedDescription)")
            return []
        }
    }

    static func add(_ tag: String) {
        guard !tag.isEmpty else { return }

        do {
            try Current.database().write { db in
                try AllowedTag(tag: tag).insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to save allowed tag \(tag), error: \(error.localizedDescription)")
        }
    }

    static func delete(_ tag: String) {
        do {
            try Current.database().write { db in
                _ = try AllowedTag.deleteOne(db, key: tag)
            }
        } catch {
            Current.Log.error("Failed to delete allowed tag \(tag), error: \(error.localizedDescription)")
        }
    }

    static func clearAll() {
        do {
            try Current.database().write { db in
                _ = try AllowedTag.deleteAll(db)
            }
        } catch {
            Current.Log.error("Failed to clear allowed tags, error: \(error.localizedDescription)")
        }
    }
}
