import Foundation
import GRDB

final class HomeViewConfigurationTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.homeViewConfiguration.rawValue }

    var definedColumns: [String] { DatabaseTables.HomeViewConfiguration.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }

        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
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
            try migrateColumns(database: database)
        }
    }
}
