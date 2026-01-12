import Foundation
import GRDB

final class HomeViewConfigurationTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(GRDBDatabaseTable.homeViewConfiguration.rawValue)
        }

        if shouldCreateTable {
            try database.write { db in
                try db.create(table: GRDBDatabaseTable.homeViewConfiguration.rawValue) { t in
                    t.primaryKey(DatabaseTables.HomeViewConfiguration.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.HomeViewConfiguration.sectionOrder.rawValue, .jsonText)
                    t.column(DatabaseTables.HomeViewConfiguration.visibleSectionIds.rawValue, .jsonText)
                    t.column(DatabaseTables.HomeViewConfiguration.allowMultipleSelection.rawValue, .boolean)
                    t.column(DatabaseTables.HomeViewConfiguration.entityOrderByRoom.rawValue, .jsonText)
                    t.column(DatabaseTables.HomeViewConfiguration.hiddenEntityIds.rawValue, .jsonText)
                    t.column(DatabaseTables.HomeViewConfiguration.selectedBackgroundId.rawValue, .text)
                }
            }
        } else {
            // Migrate existing table to add selectedBackgroundId column if it doesn't exist
            try database.write { db in
                let columnExists = try db.columns(in: GRDBDatabaseTable.homeViewConfiguration.rawValue)
                    .contains { columnInfo in
                        columnInfo.name == DatabaseTables.HomeViewConfiguration.selectedBackgroundId.rawValue
                    }

                if !columnExists {
                    try db.alter(table: GRDBDatabaseTable.homeViewConfiguration.rawValue) { tableAlteration in
                        tableAlteration.add(
                            column: DatabaseTables.HomeViewConfiguration.selectedBackgroundId.rawValue,
                            .text
                        )
                    }
                }
            }
        }
    }
}
