import Foundation
import GRDB

public enum GRDBDatabaseTable: String {
    case HAAppEntity = "hAAppEntity"
    case watchConfig
    case assistPipelines
    case carPlayConfig
    case clientEvent
    case appEntityRegistryListForDisplay
    case appPanel
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

    public enum AppEntityRegistryListForDisplay: String {
        case id
        case serverId
        case entityId
        case registry
    }

    public enum AppPanel: String {
        case id
        case serverId
        case icon
        case title
        case path
        case component
        case showInSidebar
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

    // swiftlint:disable:next cyclomatic_complexity
    private static func createAppConfigTables(database: DatabaseQueue) {
        var shouldCreateHAppEntity = false
        var shouldCreateAssistPipelines = false
        var shouldCreateWatchConfig = false
        var shouldCreateCarPlayConfig = false
        var shouldCreateClientEvent = false
        var shouldCreateAppEntityRegistryListForDisplay = false
        var shouldCreateAppPanel = false

        do {
            try database.read { db in
                shouldCreateHAppEntity = try !db.tableExists(GRDBDatabaseTable.HAAppEntity.rawValue)
                shouldCreateWatchConfig = try !db.tableExists(GRDBDatabaseTable.watchConfig.rawValue)
                shouldCreateCarPlayConfig = try !db.tableExists(GRDBDatabaseTable.carPlayConfig.rawValue)
                shouldCreateAssistPipelines = try !db.tableExists(GRDBDatabaseTable.assistPipelines.rawValue)
                shouldCreateClientEvent = try !db.tableExists(GRDBDatabaseTable.clientEvent.rawValue)
                shouldCreateAppEntityRegistryListForDisplay = try !db
                    .tableExists(GRDBDatabaseTable.appEntityRegistryListForDisplay.rawValue)
                shouldCreateAppPanel = try !db
                    .tableExists(GRDBDatabaseTable.appPanel.rawValue)
            }
        } catch {
            let errorMessage = "Failed to check if GRDB tables exist, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
        }

        // HAAppEntity - App used domain entities
        if shouldCreateHAppEntity {
            do {
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
            } catch {
                let errorMessage = "Failed to create HAAppEntity GRDB table, error: \(error.localizedDescription)"
                Current.Log.error(errorMessage)
            }
        }
        // WatchConfig - Apple Watch configuration
        if shouldCreateWatchConfig {
            do {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.watchConfig.rawValue) { t in
                        t.primaryKey(DatabaseTables.WatchConfig.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.WatchConfig.assist.rawValue, .jsonText).notNull()
                        t.column(DatabaseTables.WatchConfig.items.rawValue, .jsonText).notNull()
                    }
                }
            } catch {
                let errorMessage = "Failed to create WatchConfig GRDB table, error: \(error.localizedDescription)"
                Current.Log.error(errorMessage)
            }
        }
        // CarPlayConfig - CarPlay configuration
        if shouldCreateCarPlayConfig {
            do {
                try database.write { db in
                    if try !db.tableExists(GRDBDatabaseTable.carPlayConfig.rawValue) {
                        try db.create(table: GRDBDatabaseTable.carPlayConfig.rawValue) { t in
                            t.primaryKey(DatabaseTables.CarPlayConfig.id.rawValue, .text).notNull()
                            t.column(DatabaseTables.CarPlayConfig.tabs.rawValue, .text).notNull()
                            t.column(DatabaseTables.CarPlayConfig.quickAccessItems.rawValue, .jsonText).notNull()
                        }
                    }
                }
            } catch {
                let errorMessage = "Failed to create CarPlayConfig GRDB table, error: \(error.localizedDescription)"
                Current.Log.error(errorMessage)
            }
        }
        // PipelineResponse - Assist pipelines cache
        if shouldCreateAssistPipelines {
            do {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.assistPipelines.rawValue) { t in
                        t.primaryKey(DatabaseTables.AssistPipelines.serverId.rawValue, .text).notNull()
                        t.column(DatabaseTables.AssistPipelines.preferredPipeline.rawValue, .text).notNull()
                        t.column(DatabaseTables.AssistPipelines.pipelines.rawValue, .jsonText).notNull()
                    }
                }
            } catch {
                let errorMessage = "Failed to create AssistPipelines GRDB table, error: \(error.localizedDescription)"
                Current.Log.error(errorMessage)
            }
        }
        // Client Event
        if shouldCreateClientEvent {
            do {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.clientEvent.rawValue) { t in
                        t.primaryKey(DatabaseTables.ClientEvent.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.ClientEvent.text.rawValue, .text).notNull()
                        t.column(DatabaseTables.ClientEvent.type.rawValue, .text).notNull()
                        t.column(DatabaseTables.ClientEvent.jsonPayload.rawValue, .jsonText).notNull()
                        t.column(DatabaseTables.ClientEvent.date.rawValue, .date).notNull()
                    }
                }
            } catch {
                let errorMessage = "Failed to create ClientEvent GRDB table, error: \(error.localizedDescription)"
                Current.Log.error(errorMessage)
            }
        }

        // AppEntityRegistryListForDisplay
        if shouldCreateAppEntityRegistryListForDisplay {
            do {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.appEntityRegistryListForDisplay.rawValue) { t in
                        t.primaryKey(DatabaseTables.AppEntityRegistryListForDisplay.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntityRegistryListForDisplay.serverId.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntityRegistryListForDisplay.entityId.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntityRegistryListForDisplay.registry.rawValue, .jsonText).notNull()
                    }
                }
            } catch {
                let errorMessage =
                    "Failed to create AppEntityRegistryListForDisplay GRDB table, error: \(error.localizedDescription)"
                Current.Log.error(errorMessage)
            }
        }

        // AppPanel
        if shouldCreateAppPanel {
            do {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.appPanel.rawValue) { t in
                        t.primaryKey(DatabaseTables.AppPanel.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppPanel.serverId.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppPanel.icon.rawValue, .text)
                        t.column(DatabaseTables.AppPanel.title.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppPanel.path.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppPanel.component.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppPanel.showInSidebar.rawValue, .boolean).notNull()
                    }
                }
            } catch {
                let errorMessage =
                    "Failed to create AppPanel GRDB table, error: \(error.localizedDescription)"
                Current.Log.error(errorMessage)
            }
        }
    }
}
