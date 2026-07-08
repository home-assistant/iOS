import Foundation
import GRDB

public extension DatabaseQueue {
    // Following GRDB cocnurrency rules, we have just one database instance
    // https://swiftpackageindex.com/groue/grdb.swift/v6.29.3/documentation/grdb/concurrency#Concurrency-Rules
    static var appDatabase: DatabaseQueue = {
        var configuration = Configuration()
        configuration.observesSuspensionNotifications = true

        let database: DatabaseQueue
        do {
            database = try DatabaseQueue(path: databasePath(), configuration: configuration)
            #if targetEnvironment(simulator)
            print("GRDB App database is stored at \(AppConstants.appGRDBFile.description)")
            #endif
        } catch {
            Current.Log.error("Failed to initialize GRDB, error: \(error.localizedDescription)")
            // Fallback to in-memory database so extensions don't crash
            do {
                database = try DatabaseQueue(configuration: configuration)
                Current.Log.error("Using in-memory GRDB database as fallback")
            } catch {
                fatalError("Failed to create even an in-memory GRDB database: \(error.localizedDescription)")
            }
        }

        setupSchema(database: database)
        return database
    }()

    private static func setupSchema(database: DatabaseQueue) {
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
    }

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
            MacToolbarConfigTable(),
            AppIconShortcutConfigTable(),
            AssistPipelinesTable(),
            ServerInfoMirrorTable(),
            DisplayEntityRegistryTable(),
            AppDeviceRegistryTable(),
            AppPanelTable(),
            CustomWidgetTable(),
            AppAreaTable(),
            HomeViewConfigurationTable(),
            AssistConfigurationTable(),
            AllowedTagTable(),
            KioskSettingsTable(),
            NotificationSnoozeActionTable(),
        ]
    }

    internal static func deleteOldTables(database: DatabaseQueue) {
        /*
         Tables that existed in earlier versions and are no longer used:
         - clientEvent: used to be saved in GRDB, but because of a problem of one process holding
           a lock on the database and causing crash 0xdead10cc it is now saved as a json file.
           More information: https://github.com/groue/GRDB.swift/issues/1626#issuecomment-2623927815
         - appEntityRegistryListForDisplay and entityRegistry: both replaced by `displayEntityRegistry`,
           which is sourced from config/entity_registry/list_for_display. ("entityRegistry" was the
           former full-registry table; it has no enum case anymore, hence the string literal.)
         */
        let obsoleteTables = [
            GRDBDatabaseTable.clientEvent.rawValue,
            GRDBDatabaseTable.appEntityRegistryListForDisplay.rawValue,
            "entityRegistry",
        ]
        for tableName in obsoleteTables {
            do {
                let exists = try database.read { try $0.tableExists(tableName) }
                guard exists else { continue }
                try database.write { db in
                    try db.drop(table: tableName)
                }
            } catch {
                Current.Log.verbose(
                    "Failed or not needed to drop obsolete GRDB table \(tableName), error: \(error.localizedDescription)"
                )
            }
        }
    }
}

protocol DatabaseTableProtocol {
    /// The name of the database table
    var tableName: String { get }

    /// The list of column names defined for this table
    var definedColumns: [String] { get }

    /// Creates the table if it doesn't exist, or migrates it if it does
    func createIfNeeded(database: DatabaseQueue) throws
}

extension DatabaseTableProtocol {
    /// Migrates the table by adding new columns and removing obsolete columns
    func migrateColumns(database: DatabaseQueue) throws {
        let (columnsToAdd, columnsToDrop) = try database.read { db -> ([String], [String]) in
            let existingColumnNames = try db.columns(in: tableName).map(\.name)
            let existingColumnSet = Set(existingColumnNames)
            let definedColumnSet = Set(definedColumns)

            let toAdd = definedColumns.filter { !existingColumnSet.contains($0) }
            let toDrop = existingColumnNames.filter { !definedColumnSet.contains($0) }
            return (toAdd, toDrop)
        }

        guard !columnsToAdd.isEmpty || !columnsToDrop.isEmpty else { return }

        try database.write { db in
            for columnName in columnsToAdd {
                try db.alter(table: tableName) { tableAlteration in
                    tableAlteration.add(column: columnName)
                }
            }
            for columnName in columnsToDrop {
                try db.alter(table: tableName) { tableAlteration in
                    tableAlteration.drop(column: columnName)
                }
            }
        }
    }
}
