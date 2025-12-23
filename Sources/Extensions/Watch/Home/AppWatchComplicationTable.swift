import Foundation
import GRDB

final class AppWatchComplicationTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(GRDBDatabaseTable.appWatchComplication.rawValue)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: GRDBDatabaseTable.appWatchComplication.rawValue) { t in
                    t.primaryKey(DatabaseTables.AppWatchComplication.identifier.rawValue, .text).notNull()
                    // Store the entire complication as JSON data
                    t.column(DatabaseTables.AppWatchComplication.complicationData.rawValue, .jsonText).notNull()
                }
            }
        } else {
            // In case a new column is added to the table, we need to alter the table
            try database.write { db in
                for column in DatabaseTables.AppWatchComplication.allCases {
                    let shouldCreateColumn = try !db.columns(in: GRDBDatabaseTable.appWatchComplication.rawValue)
                        .contains { columnInfo in
                            columnInfo.name == column.rawValue
                        }

                    if shouldCreateColumn {
                        try db.alter(table: GRDBDatabaseTable.appWatchComplication.rawValue) { tableAlteration in
                            tableAlteration.add(column: column.rawValue)
                        }
                    }
                }
            }
        }
    }
}
