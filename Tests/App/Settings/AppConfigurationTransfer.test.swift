import Foundation
import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing

@MainActor
@Suite(.serialized)
struct AppConfigurationTransferTests {
    @Test func exportMarksTheFileAsAFullConfigurationExport() throws {
        try withConfigurationTestWorld { database in
            try seedEveryCategory(in: database, serverId: validServerId)

            let url = try AppConfigurationTransfer.exportURL(appSettings: AppSettingsSnapshot.capture())
            let payload = try jsonPayload(from: url)

            #expect(payload["kind"] as? String == AppConfigurationTransfer.fileKind)
            #expect(payload["schemaVersion"] as? Int == AppConfigurationTransfer.schemaVersion)
            #expect(payload["appSettings"] as? [String: Any] != nil)
            #expect((payload["customWidgets"] as? [[String: Any]])?.count == 1)
            #expect((payload["allowedTags"] as? [[String: Any]])?.count == 1)
            #expect((payload["remindersSyncConfigurations"] as? [[String: Any]])?.count == 1)
        }
    }

    @Test func entryCountsCoverEveryCategory() throws {
        try withConfigurationTestWorld { database in
            try seedEveryCategory(in: database, serverId: validServerId)

            let counts = try AppConfigurationTransfer.entryCounts(appSettings: AppSettingsSnapshot.capture())

            for category in AppConfigurationCategory.allCases {
                #expect((counts[category] ?? 0) > 0, "expected \(category.rawValue) to report entries")
            }
        }
    }

    @Test func entryCountsAreZeroForUnconfiguredCategories() throws {
        try withConfigurationTestWorld { _ in
            let counts = try AppConfigurationTransfer.entryCounts(appSettings: AppSettingsSnapshot.capture())

            // App settings always exist, and the snooze actions table seeds its defaults when it is
            // created, so both travel in an export even from a device that configured nothing.
            let alwaysPresent: Set<AppConfigurationCategory> = [.appSettings, .notificationSnoozeActions]
            for category in AppConfigurationCategory.allCases where !alwaysPresent.contains(category) {
                #expect(counts[category] == 0, "expected \(category.rawValue) to be empty")
            }
            #expect(counts[.appSettings] == 1)
            #expect((counts[.notificationSnoozeActions] ?? 0) > 0)
        }
    }

    @Test func inspectRejectsASingleFeatureExportFile() throws {
        try withConfigurationTestWorld { database in
            try seedCarPlayConfiguration(in: database, serverId: validServerId)
            let url = try DebugDatabaseTransfer.exportURL(part: .carPlayConfiguration)

            do {
                _ = try AppConfigurationTransfer.inspectImportFile(from: url)
                Issue.record("Expected a single feature export to be rejected")
            } catch let error as AppConfigurationTransfer.TransferError {
                guard case .notAConfigurationFile = error else {
                    Issue.record("Expected notAConfigurationFile, got \(error)")
                    return
                }
            }
        }
    }

    @Test func inspectReportsWhatTheFileContains() throws {
        try withConfigurationTestWorld { database in
            try seedEveryCategory(in: database, serverId: validServerId)
            let url = try AppConfigurationTransfer.exportURL(appSettings: AppSettingsSnapshot.capture())
            // The seeded action plus the defaults the table creates for itself.
            let snoozeActionCount = try database.read { db in try NotificationSnoozeAction.fetchCount(db) }

            let counts = try AppConfigurationTransfer.inspectImportFile(from: url)

            #expect(counts[.customWidgets] == 1)
            #expect(counts[.nfcTags] == 1)
            #expect(counts[.notificationSnoozeActions] == snoozeActionCount)
            #expect(counts[.kiosk] == 1)
        }
    }

    @Test func importReplacesEveryCategoryAndDropsUnknownServerConfiguration() async throws {
        let sourceDatabase = try makeConfigurationDatabase()
        try seedEveryCategory(
            in: sourceDatabase,
            serverId: validServerId,
            invalidServerId: missingServerId,
            itemPrefix: "imported"
        )

        let url = try withConfigurationTestWorld(database: sourceDatabase) { _ in
            try AppConfigurationTransfer.exportURL(appSettings: AppSettingsSnapshot.capture())
        }

        let destinationDatabase = try makeConfigurationDatabase()
        let staleItem = MagicItem(id: "stale-item", serverId: validServerId, type: .script)
        try await destinationDatabase.write { db in
            try CustomWidget(id: "stale", name: "Stale", items: [staleItem]).insert(db)
            try AllowedTag(tag: "stale-tag").insert(db)
        }

        let modelManager = NoOpConfigurationModelManager()
        let appDatabaseUpdater = RecordingConfigurationAppDatabaseUpdater()

        try await withConfigurationTestWorld(
            database: destinationDatabase,
            modelManager: modelManager,
            appDatabaseUpdater: appDatabaseUpdater
        ) { database in
            let counts = try await AppConfigurationTransfer.importPayload(from: url)

            #expect(modelManager.cleanupCallCount == 1)
            #expect(appDatabaseUpdater.updatedServerIds == [validServerId])

            // The stale rows are gone, replaced by the file's contents.
            let widgets = try await database.read { db in try CustomWidget.fetchAll(db) }
            #expect(widgets.map(\.id) == ["imported-widget"])
            let tags = try await database.read { db in try AllowedTag.fetchAll(db) }
            #expect(tags.map(\.tag) == ["imported-tag"])

            // Items belonging to a server this device does not know about never land in the database.
            let storedCarPlayConfig = try await database.read { db in try CarPlayConfig.fetchOne(db) }
            let carPlayConfig = try #require(storedCarPlayConfig)
            #expect(carPlayConfig.quickAccessItems.map(\.id) == ["imported-carplay-valid"])
            #expect(counts[.carPlayConfiguration] == 1)

            let remindersConfigs = try await database.read { db in try RemindersSyncConfig.fetchAll(db) }
            #expect(remindersConfigs.map(\.id) == ["imported-reminders-valid"])

            let categories = try await database.read { db in try NotificationCategory.fetchAll(db) }
            #expect(categories.map(\.identifier) == ["imported-category-valid"])

            let storedKiosk = try await database.read { db in try KioskSettings.fetchOne(db) }
            let kiosk = try #require(storedKiosk)
            #expect(kiosk.serverId == validServerId)
        }
    }

    @Test func appSettingsSnapshotSurvivesAJsonRoundTrip() throws {
        let snapshot = AppSettingsSnapshot.capture()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AppSettingsSnapshot.self, from: encoder.encode(snapshot))

        #expect(decoded == snapshot)
    }

    @Test func appSettingsSnapshotDecodesAFileMissingEveryField() throws {
        let data = try #require("{}".data(using: .utf8))

        let decoded = try JSONDecoder().decode(AppSettingsSnapshot.self, from: data)

        #expect(decoded.pageZoom == nil)
        #expect(decoded.privacy == nil)
        #expect(decoded.locationSources == nil)
        #expect(decoded.gestures == nil)
        #expect(decoded.appIcon == nil)
    }

    private let validServerId = "server-valid"
    private let missingServerId = "server-missing"

    private func withConfigurationTestWorld(
        database: DatabaseQueue? = nil,
        modelManager: LegacyModelManager = NoOpConfigurationModelManager(),
        appDatabaseUpdater: AppDatabaseUpdaterProtocol = RecordingConfigurationAppDatabaseUpdater(),
        perform work: @MainActor (DatabaseQueue) async throws -> Void
    ) async throws {
        let database = try database ?? makeConfigurationDatabase()
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let previousModelManager = Current.modelManager
        let previousAppDatabaseUpdater = Current.appDatabaseUpdater
        // Importing applies an `AppSettingsSnapshot`, which writes across the shared app group
        // defaults; re-applying the snapshot taken here restores exactly the preferences an import
        // can touch, using the same code path. The menu bar template is restored by key on top of
        // that, because `apply()` skips it when its server is gone.
        let previousSettings = AppSettingsSnapshot.capture()
        let previousMenuItemTemplate = Current.settingsStore.prefs.string(forKey: "menuItemTemplate")
        let previousMenuItemTemplateServer = Current.settingsStore.prefs.string(forKey: "menuItemTemplate-server")

        let servers = FakeServerManager(initial: 0)
        servers.add(identifier: .init(rawValue: validServerId), serverInfo: .fake())

        Current.database = { database }
        Current.servers = servers
        Current.modelManager = modelManager
        Current.appDatabaseUpdater = appDatabaseUpdater

        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
            Current.modelManager = previousModelManager
            Current.appDatabaseUpdater = previousAppDatabaseUpdater
            previousSettings.apply()
            Current.settingsStore.prefs.set(previousMenuItemTemplate, forKey: "menuItemTemplate")
            Current.settingsStore.prefs.set(previousMenuItemTemplateServer, forKey: "menuItemTemplate-server")
        }

        try await work(database)
    }

    private func withConfigurationTestWorld<T>(
        database: DatabaseQueue? = nil,
        perform work: @MainActor (DatabaseQueue) throws -> T
    ) throws -> T {
        let database = try database ?? makeConfigurationDatabase()
        let previousDatabase = Current.database
        let previousServers = Current.servers

        let servers = FakeServerManager(initial: 0)
        servers.add(identifier: .init(rawValue: validServerId), serverInfo: .fake())

        Current.database = { database }
        Current.servers = servers

        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        return try work(database)
    }

    private func makeConfigurationDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        return database
    }

    private func seedEveryCategory(
        in database: DatabaseQueue,
        serverId: String,
        invalidServerId: String? = nil,
        itemPrefix: String = "seed"
    ) throws {
        try seedCarPlayConfiguration(
            in: database,
            serverId: serverId,
            invalidServerId: invalidServerId,
            itemPrefix: itemPrefix
        )
        try database.write { db in
            try WatchConfig(
                id: WatchConfig.watchConfigId,
                items: [.init(id: "\(itemPrefix)-watch", serverId: serverId, type: .script)]
            ).insert(db, onConflict: .replace)
            try WatchComplication(
                identifier: "\(itemPrefix)-complication",
                serverIdentifier: serverId,
                name: "Complication"
            ).insert(db, onConflict: .replace)
            try WatchComplicationConfig(
                id: "\(itemPrefix)-complication-config",
                serverId: serverId,
                entityId: "sensor.temperature"
            ).insert(db, onConflict: .replace)
            try CustomWidget(
                id: "\(itemPrefix)-widget",
                name: "Widget",
                items: [.init(id: "\(itemPrefix)-widget-item", serverId: serverId, type: .script)]
            ).insert(db, onConflict: .replace)
            try AppIconShortcutConfig(
                items: [.init(id: "\(itemPrefix)-shortcut", serverId: serverId, type: .script)]
            ).insert(db, onConflict: .replace)
            try MacToolbarConfig(
                items: [.init(id: "\(itemPrefix)-toolbar", serverId: serverId, type: .script)]
            ).insert(db, onConflict: .replace)
            try KioskSettings(enabled: true, serverId: serverId, dashboard: "lovelace")
                .insert(db, onConflict: .replace)
            try NotificationCategory(
                identifier: "\(itemPrefix)-category-valid",
                serverIdentifier: serverId,
                name: "Category"
            ).insert(db, onConflict: .replace)
            try NotificationSnoozeAction(id: "\(itemPrefix)-snooze", minutes: 5, sortOrder: 0)
                .insert(db, onConflict: .replace)
            try AllowedTag(tag: "\(itemPrefix)-tag").insert(db, onConflict: .replace)
            try RemindersSyncConfig(
                id: "\(itemPrefix)-reminders-valid",
                serverId: serverId,
                todoEntityId: "todo.shopping",
                todoEntityName: "Shopping",
                reminderListId: "list",
                reminderListName: "List",
                direction: .bothWays
            ).insert(db, onConflict: .replace)

            if let invalidServerId {
                try NotificationCategory(
                    identifier: "\(itemPrefix)-category-invalid",
                    serverIdentifier: invalidServerId,
                    name: "Invalid"
                ).insert(db, onConflict: .replace)
                try RemindersSyncConfig(
                    id: "\(itemPrefix)-reminders-invalid",
                    serverId: invalidServerId,
                    todoEntityId: "todo.other",
                    todoEntityName: "Other",
                    reminderListId: "other-list",
                    reminderListName: "Other List",
                    direction: .bothWays
                ).insert(db, onConflict: .replace)
            }
        }
    }

    private func seedCarPlayConfiguration(
        in database: DatabaseQueue,
        serverId: String,
        invalidServerId: String? = nil,
        itemPrefix: String = "seed"
    ) throws {
        var items: [MagicItem] = [
            .init(id: "\(itemPrefix)-carplay-valid", serverId: serverId, type: .script),
        ]
        if let invalidServerId {
            items.append(.init(id: "\(itemPrefix)-carplay-invalid", serverId: invalidServerId, type: .script))
        }
        try database.write { db in
            try CarPlayConfig.deleteAll(db)
            try CarPlayConfig(quickAccessItems: items).insert(db)
        }
    }

    private func jsonPayload(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class NoOpConfigurationModelManager: LegacyModelManager {
    var cleanupCallCount = 0

    override func cleanup(definitions: [CleanupDefinition] = CleanupDefinition.defaults) -> Promise<Void> {
        cleanupCallCount += 1
        return .value(())
    }
}

private final class RecordingConfigurationAppDatabaseUpdater: AppDatabaseUpdaterProtocol {
    var updatedServerIds: [String] = []

    func stop() {}

    func update(server: Server, forceUpdate: Bool, showProgress _: Bool) {
        if forceUpdate {
            updatedServerIds.append(server.identifier.rawValue)
        }
    }
}
