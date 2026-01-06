import Foundation
import GRDB

public extension DatabaseQueue {
    // Following GRDB cocnurrency rules, we have just one database instance
    // https://swiftpackageindex.com/groue/grdb.swift/v6.29.3/documentation/grdb/concurrency#Concurrency-Rules
    static var appDatabase: DatabaseQueue = {
        do {
            let database = try DatabaseQueue(path: databasePath())

            // Create tables if needed
            for table in DatabaseQueue.tables() {
                do {
                    try table.createIfNeeded(database: database)
                } catch {
                    let className = String(describing: type(of: table))
                    let errorMessage = "Failed create GRDB table \(className), error: \(error.localizedDescription)"
                    Current.clientEventStore.addEvent(ClientEvent(text: errorMessage, type: .database))
                }
            }
            DatabaseQueue.deleteOldTables(database: database)

            #if targetEnvironment(simulator)
            print("GRDB App database is stored at \(AppConstants.appGRDBFile.description)")
            #endif
            return database
        } catch {
            let errorMessage = "Failed to initialize GRDB, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
            fatalError(errorMessage)
        }
    }()

    static func databasePath() -> String {
        // Path for tests
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let tempDirectory = NSTemporaryDirectory()
            return (tempDirectory as NSString).appendingPathComponent("test_database.sqlite")
        } else {
            // Path for App use
            return AppConstants.appGRDBFile.path
        }
    }

    internal static func tables() -> [DatabaseTableProtocol] {
        [
            HAppEntityTable(),
            WatchConfigTable(),
            CarPlayConfigTable(),
            AssistPipelinesTable(),
            AppEntityRegistryListForDisplayTable(),
            AppEntityRegistryTable(),
            AppPanelTable(),
            CustomWidgetTable(),
            AppAreaTable(),
            HomeViewConfigurationTable(),
        ]
    }

    internal static func deleteOldTables(database: DatabaseQueue) {
        do {
            /*
             ClientEvent used to be saved in GRDB, but because of a problem of one process holding
             lock on the database and causing crash 0xdead10cc now it is saved as a json file
             More information: https://github.com/groue/GRDB.swift/issues/1626#issuecomment-2623927815
             */
            try database.write { db in
                try db.drop(table: GRDBDatabaseTable.clientEvent.rawValue)
            }
        } catch {
            let errorMessage =
                "Failed or not needed delete client event GRDB info, error: \(error.localizedDescription)"
            Current.Log.verbose(errorMessage)
        }
    }
}

protocol DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) throws
}
