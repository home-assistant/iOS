import Foundation
import GRDB

public struct AllowedTag: Codable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = GRDBDatabaseTable.allowedTags.rawValue

    public var tag: String

    public init(tag: String) {
        self.tag = tag
    }

    public static func contains(_ tag: String) -> Bool {
        do {
            return try Current.database().read { db in
                try AllowedTag.fetchOne(db, key: tag) != nil
            }
        } catch {
            Current.Log.error("Failed to fetch allowed tag \(tag), error: \(error.localizedDescription)")
            return false
        }
    }

    public static func add(_ tag: String) {
        guard !tag.isEmpty else { return }

        do {
            try Current.database().write { db in
                try AllowedTag(tag: tag).insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to save allowed tag \(tag), error: \(error.localizedDescription)")
        }
    }

    public static func clearAll() {
        do {
            try Current.database().write { db in
                _ = try AllowedTag.deleteAll(db)
            }
        } catch {
            Current.Log.error("Failed to clear allowed tags, error: \(error.localizedDescription)")
        }
    }
}
