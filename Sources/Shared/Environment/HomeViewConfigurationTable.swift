import Foundation
import GRDB

final class HomeViewConfigurationTable: DatabaseTableProtocol {
    // Define the expected schema
    private let expectedColumns: [String: String] = [
        DatabaseTables.HomeViewConfiguration.id.rawValue: "text",
        DatabaseTables.HomeViewConfiguration.sectionOrder.rawValue: "jsontext",
        DatabaseTables.HomeViewConfiguration.visibleSectionIds.rawValue: "jsontext",
        DatabaseTables.HomeViewConfiguration.allowMultipleSelection.rawValue: "boolean",
        DatabaseTables.HomeViewConfiguration.entityOrderByRoom.rawValue: "jsontext",
        DatabaseTables.HomeViewConfiguration.hiddenEntityIds.rawValue: "jsontext",
        DatabaseTables.HomeViewConfiguration.showUsagePredictionSection.rawValue: "boolean",
    ]

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
                }
            }
        } else {
            try database.write { db in
                for column in DatabaseTables.HomeViewConfiguration.allCases {
                    let shouldCreateColumn = try !db.columns(in: GRDBDatabaseTable.homeViewConfiguration.rawValue)
                        .contains { columnInfo in
                            columnInfo.name == column.rawValue
                        }

                    if shouldCreateColumn {
                        try db.alter(table: GRDBDatabaseTable.homeViewConfiguration.rawValue) { tableAlteration in
                            tableAlteration.add(column: column.rawValue)
                        }
                    }
                }
            }
        }
    }
}
