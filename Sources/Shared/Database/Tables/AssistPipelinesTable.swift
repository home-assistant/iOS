import Foundation
import GRDB

final class AssistPipelinesTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.assistPipelines.rawValue }

    var definedColumns: [String] { DatabaseTables.AssistPipelines.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.AssistPipelines.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.AssistPipelines.preferredPipeline.rawValue, .text).notNull()
                    t.column(DatabaseTables.AssistPipelines.pipelines.rawValue, .jsonText).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
