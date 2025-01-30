import Foundation
import GRDB

final class ClientEventTable: DatabaseTableProtocol {
    // In this particular case we will drop it if existent
    func createIfNeeded(database: DatabaseQueue) {
        do {
            /*
             ClientEvent used to be saved in GRDB, but because of a problem of one process holding
             lock on the database and causing crash 0xdead10cc now it is saved as a json file
             More information: https://github.com/groue/GRDB.swift/issues/1626#issuecomment-2623927815
             */
            let shouldDeleteTable = try database.read { db in
                try !db.tableExists(GRDBDatabaseTable.clientEvent.rawValue)
            }
            if shouldDeleteTable {
                try database.write { db in
                    try db.drop(table: GRDBDatabaseTable.clientEvent.rawValue)
                    Current.Log.verbose("Dropped table: \(GRDBDatabaseTable.clientEvent.rawValue) sucessfully")
                }
            }
        } catch {
            let errorMessage = "Failed to read client event GRDB info, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
        }
    }
}
