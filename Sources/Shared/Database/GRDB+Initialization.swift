import Foundation
import GRDB

public extension DatabaseQueue {
    // Following GRDB cocnurrency rules, we have just one database instance
    // https://swiftpackageindex.com/groue/grdb.swift/v6.29.3/documentation/grdb/concurrency#Concurrency-Rules
    static var appDatabase: DatabaseQueue = {
        var configuration = Configuration()
        configuration.busyMode = .timeout(3)
        configuration.observesSuspensionNotifications = true

        let database: DatabaseQueue
        var isInMemoryFallback = false
        do {
            database = try DatabaseQueue(path: databasePath(), configuration: configuration)
            #if targetEnvironment(simulator)
            print("GRDB App database is stored at \(AppConstants.appGRDBFile.description)")
            #endif
        } catch {
            Current.Log.error("Failed to initialize GRDB, error: \(error.localizedDescription)")
            // Fallback to in-memory database so extensions don't crash
            do {
                database = try DatabaseQueue()
                isInMemoryFallback = true
                Current.Log.error("Using in-memory GRDB database as fallback")
            } catch {
                fatalError("Failed to create even an in-memory GRDB database: \(error.localizedDescription)")
            }
        }

        if !Current.isAppExtension || isInMemoryFallback {
            setupSchema(database: database)
        }
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
            WatchComplicationTable(),
            WatchComplicationConfigTable(),
            AppZoneTable(),
            NotificationCategoryTable(),
            LocationHistoryTable(),
            LocationErrorTable(),
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

    /// Delete every row from all app tables, leaving the schema intact. Used by the watch's
    /// "Delete local data" action to wipe the locally-mirrored config/entities without dropping the DB
    /// (so the app keeps working and re-syncs on the next refresh). The table list is the same one used
    /// to create the schema, so new tables are covered automatically. Exposed as an instance method so
    /// callers can invoke it on `Current.database()` without importing GRDB directly.
    func eraseAllData() throws {
        try write { db in
            for table in DatabaseQueue.tables() {
                try db.execute(sql: "DELETE FROM \(table.tableName)")
            }
        }
    }
}

/// Posts GRDB's database suspension notifications without requiring callers to import GRDB
/// (app targets don't all link it directly). Suspending while backgrounded prevents the system from
/// killing the process with 0xdead10cc for holding the app-group SQLite file lock during suspension —
/// see https://github.com/groue/GRDB.swift/issues/1626.
public enum AppDatabaseSuspension {
    public static func suspend() {
        NotificationCenter.default.post(name: Database.suspendNotification, object: nil)
    }

    public static func resume() {
        NotificationCenter.default.post(name: Database.resumeNotification, object: nil)
    }
}

/// Legacy watch complications table. Defined here (rather than a new file) so it joins the Shared
/// target without a project-file change. Mirrors the `WatchConfigTable` pattern.
final class WatchComplicationTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.watchComplication.rawValue }
    var definedColumns: [String] { DatabaseTables.WatchComplication.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.WatchComplication.identifier.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchComplication.serverIdentifier.rawValue, .text)
                    t.column(DatabaseTables.WatchComplication.rawFamily.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchComplication.rawTemplate.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchComplication.complicationData.rawValue, .jsonText)
                    t.column(DatabaseTables.WatchComplication.createdAt.rawValue, .datetime).notNull()
                    t.column(DatabaseTables.WatchComplication.name.rawValue, .text)
                    t.column(DatabaseTables.WatchComplication.isPublic.rawValue, .boolean).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}

/// Modern watch complication configs table. Defined here to avoid a project-file change.
final class WatchComplicationConfigTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.watchComplicationConfig.rawValue }
    var definedColumns: [String] { DatabaseTables.WatchComplicationConfig.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.WatchComplicationConfig.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchComplicationConfig.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchComplicationConfig.widgetFamily.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchComplicationConfig.kind.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchComplicationConfig.name.rawValue, .text)
                    t.column(DatabaseTables.WatchComplicationConfig.entityId.rawValue, .text)
                    t.column(DatabaseTables.WatchComplicationConfig.entityDisplayName.rawValue, .text)
                    t.column(DatabaseTables.WatchComplicationConfig.iconName.rawValue, .text)
                    t.column(DatabaseTables.WatchComplicationConfig.iconColor.rawValue, .text)
                    t.column(DatabaseTables.WatchComplicationConfig.gaugeAttribute.rawValue, .text)
                    t.column(DatabaseTables.WatchComplicationConfig.valueAttribute.rawValue, .text)
                    t.column(DatabaseTables.WatchComplicationConfig.valuePrecision.rawValue, .integer)
                    t.column(DatabaseTables.WatchComplicationConfig.unitOverride.rawValue, .text)
                    t.column(DatabaseTables.WatchComplicationConfig.gaugeMin.rawValue, .double)
                    t.column(DatabaseTables.WatchComplicationConfig.gaugeMax.rawValue, .double)
                    t.column(DatabaseTables.WatchComplicationConfig.showValue.rawValue, .boolean).notNull()
                    // Nullable: absent means "show the unit" (see WatchComplicationConfig.showsUnit()).
                    t.column(DatabaseTables.WatchComplicationConfig.showUnit.rawValue, .boolean)
                    // Nullable: absent means "show when inactive" (see showsWhenInactive()).
                    t.column(DatabaseTables.WatchComplicationConfig.showWhenInactive.rawValue, .boolean)
                    // Nullable: absent means the min/max labels are visible (see showsMin()/showsMax()).
                    t.column(DatabaseTables.WatchComplicationConfig.showMin.rawValue, .boolean)
                    t.column(DatabaseTables.WatchComplicationConfig.showMax.rawValue, .boolean)
                    t.column(DatabaseTables.WatchComplicationConfig.customTextTemplate.rawValue, .text)
                    t.column(DatabaseTables.WatchComplicationConfig.customGaugeTemplate.rawValue, .text)
                    t.column(DatabaseTables.WatchComplicationConfig.sortOrder.rawValue, .integer).notNull()
                    t.column(DatabaseTables.WatchComplicationConfig.families.rawValue, .jsonText)
                    t.column(DatabaseTables.WatchComplicationConfig.isCustomized.rawValue, .boolean)
                }
            }
        } else {
            try migrateColumns(database: database)
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
        try database.write { db in
            let existingColumns = try db.columns(in: tableName)
            let definedColumnSet = Set(definedColumns)

            // Add new columns that don't exist yet
            for columnName in definedColumns {
                let shouldCreateColumn = !existingColumns.contains { $0.name == columnName }
                if shouldCreateColumn {
                    try db.alter(table: tableName) { tableAlteration in
                        tableAlteration.add(column: columnName)
                    }
                }
            }

            // Remove columns that are no longer defined
            for existingColumn in existingColumns where !definedColumnSet.contains(existingColumn.name) {
                try db.alter(table: tableName) { tableAlteration in
                    tableAlteration.drop(column: existingColumn.name)
                }
            }
        }
    }
}
