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
                    t.column(DatabaseTables.HomeViewConfiguration.showUsagePredictionSection.rawValue, .boolean)
                    t.column(DatabaseTables.HomeViewConfiguration.areasLayout.rawValue, .text)
                    t.column(DatabaseTables.HomeViewConfiguration.showSummaries.rawValue, .boolean)
                }
            }
        } else {
            // In case a column is added or removed from the table, we need to alter the table
            try database.write { db in
                let tableName = GRDBDatabaseTable.homeViewConfiguration.rawValue
                let existingColumns = try db.columns(in: tableName)
                let definedColumns = Set(DatabaseTables.HomeViewConfiguration.allCases.map(\.rawValue))

                // Add new columns that don't exist yet
                for column in DatabaseTables.HomeViewConfiguration.allCases {
                    let shouldCreateColumn = !existingColumns.contains { $0.name == column.rawValue }
                    if shouldCreateColumn {
                        try db.alter(table: tableName) { tableAlteration in
                            tableAlteration.add(column: column.rawValue)
                        }
                    }
                }

                // Remove columns that are no longer defined
                for existingColumn in existingColumns where !definedColumns.contains(existingColumn.name) {
                    try db.alter(table: tableName) { tableAlteration in
                        tableAlteration.drop(column: existingColumn.name)
                    }
                }
            }
        }
    }
}
