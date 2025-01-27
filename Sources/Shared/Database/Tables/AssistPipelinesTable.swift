import Foundation
import GRDB

final class AssistPipelinesTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) {
        do {
            let shouldCreateTable = try database.read { db in
                try !db.tableExists(GRDBDatabaseTable.assistPipelines.rawValue)
            }
            if shouldCreateTable {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.assistPipelines.rawValue) { t in
                        t.primaryKey(DatabaseTables.AssistPipelines.serverId.rawValue, .text).notNull()
                        t.column(DatabaseTables.AssistPipelines.preferredPipeline.rawValue, .text).notNull()
                        t.column(DatabaseTables.AssistPipelines.pipelines.rawValue, .jsonText).notNull()
                    }
                }
            }
        } catch {
            let errorMessage = "Failed create GRDB table, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
        }
    }
}
