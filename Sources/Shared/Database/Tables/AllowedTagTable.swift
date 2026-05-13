import Foundation
import GRDB

final class AllowedTagTable: DatabaseTableProtocol {
    private let legacyAllowedTagsKey = "allowedTags"

    var tableName: String { GRDBDatabaseTable.allowedTags.rawValue }

    var definedColumns: [String] { DatabaseTables.AllowedTag.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.AllowedTag.tag.rawValue, .text).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }

        try migrateLegacyUserDefaultsTags(database: database)
    }

    private func migrateLegacyUserDefaultsTags(database: DatabaseQueue) throws {
        let legacyTags = Set(Current.settingsStore.prefs.stringArray(forKey: legacyAllowedTagsKey) ?? [])
        guard !legacyTags.isEmpty else { return }

        try database.write { db in
            for tag in legacyTags where !tag.isEmpty {
                try AllowedTag(tag: tag).insert(db, onConflict: .replace)
            }
        }
        Current.settingsStore.prefs.removeObject(forKey: legacyAllowedTagsKey)
    }
}
