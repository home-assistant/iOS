import Foundation
import GRDB

public enum GRDBDatabaseTable: String {
    case HAAppEntity = "hAAppEntity"
    case watchConfig
    case assistPipelines
    case carPlayConfig
    case clientEvent
}

public enum DatabaseTables {
    public enum AppEntity: String {
        case id
        case entityId
        case serverId
        case domain
        case name
        case icon
    }

    public enum WatchConfig: String {
        case id
        case assist
        case items
    }

    // Assist pipelines
    public enum AssistPipelines: String {
        case serverId
        case preferredPipeline
        case pipelines
    }

    // CarPlay configuration
    public enum CarPlayConfig: String {
        case id
        case tabs
        case quickAccessItems
    }

    // Client events
    public enum ClientEvent: String {
        case id
        case text
        case type
        case jsonPayload
        case date
    }
}

public extension DatabaseQueue {
    // Following GRDB cocnurrency rules, we have just one database instance
    // https://swiftpackageindex.com/groue/grdb.swift/v6.29.3/documentation/grdb/concurrency#Concurrency-Rules
    static var appDatabase: DatabaseQueue = {
        do {
            let database = try DatabaseQueue(path: databasePath())
            createAppConfigTables(database: database)
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

    private static func createAppConfigTables(database: DatabaseQueue) {
        do {
            var shouldCreateHAppEntity: Bool = false
            var shouldCreateAssistPipelines: Bool = false
            var shouldCreateWatchConfig: Bool = false
            var shouldCreateCarPlayConfig: Bool = false
            var shouldCreateClientEvent: Bool = false
            try database.read { db in
                shouldCreateHAppEntity = try !db.tableExists(GRDBDatabaseTable.HAAppEntity.rawValue)
                shouldCreateWatchConfig = try !db.tableExists(GRDBDatabaseTable.watchConfig.rawValue)
                shouldCreateCarPlayConfig = try !db.tableExists(GRDBDatabaseTable.carPlayConfig.rawValue)
                shouldCreateAssistPipelines = try !db.tableExists(GRDBDatabaseTable.assistPipelines.rawValue)
                shouldCreateClientEvent = try !db.tableExists(GRDBDatabaseTable.clientEvent.rawValue)
            }

            // HAAppEntity - App used domain entities
            if shouldCreateHAppEntity {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.HAAppEntity.rawValue) { t in
                        t.primaryKey(DatabaseTables.AppEntity.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntity.entityId.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntity.serverId.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntity.domain.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntity.name.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntity.icon.rawValue, .text)
                    }
                }
            }
            // WatchConfig - Apple Watch configuration
            if shouldCreateWatchConfig {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.watchConfig.rawValue) { t in
                        t.primaryKey(DatabaseTables.WatchConfig.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.WatchConfig.assist.rawValue, .jsonText).notNull()
                        t.column(DatabaseTables.WatchConfig.items.rawValue, .jsonText).notNull()
                    }
                }
            }
            // CarPlayConfig - CarPlay configuration
            if shouldCreateCarPlayConfig {
                try database.write { db in
                    if try !db.tableExists(GRDBDatabaseTable.carPlayConfig.rawValue) {
                        try db.create(table: GRDBDatabaseTable.carPlayConfig.rawValue) { t in
                            t.primaryKey(DatabaseTables.CarPlayConfig.id.rawValue, .text).notNull()
                            t.column(DatabaseTables.CarPlayConfig.tabs.rawValue, .text).notNull()
                            t.column(DatabaseTables.CarPlayConfig.quickAccessItems.rawValue, .jsonText).notNull()
                        }
                    }
                }
            }
            // PipelineResponse - Assist pipelines cache
            if shouldCreateAssistPipelines {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.assistPipelines.rawValue) { t in
                        t.primaryKey(DatabaseTables.AssistPipelines.serverId.rawValue, .text).notNull()
                        t.column(DatabaseTables.AssistPipelines.preferredPipeline.rawValue, .text).notNull()
                        t.column(DatabaseTables.AssistPipelines.pipelines.rawValue, .jsonText).notNull()
                    }
                }
            }
            // Client Event
            if shouldCreateClientEvent {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.clientEvent.rawValue) { t in
                        t.primaryKey(DatabaseTables.ClientEvent.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.ClientEvent.text.rawValue, .text).notNull()
                        t.column(DatabaseTables.ClientEvent.type.rawValue, .text).notNull()
                        t.column(DatabaseTables.ClientEvent.jsonPayload.rawValue, .jsonText).notNull()
                        t.column(DatabaseTables.ClientEvent.date.rawValue, .date).notNull()
                    }
                }
            }
        } catch {
            let errorMessage = "Failed to create GRDB tables, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
            fatalError(errorMessage)
        }
    }
}
