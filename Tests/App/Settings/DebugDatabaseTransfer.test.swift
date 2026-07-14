import Foundation
import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing

@Suite(.serialized)
struct DebugDatabaseTransferTests {
    @Test func exportAvailabilityIsFalseWhenFeatureHasNoRows() throws {
        try withTransferTestWorld { _ in
            for part in DebugDatabaseTransfer.Part.allCases {
                let hasContent = try DebugDatabaseTransfer.hasExportableContent(part: part)
                #expect(hasContent == false)
            }
        }
    }

    @Test func exportAvailabilityIsTrueWhenFeatureHasRows() throws {
        try withTransferTestWorld { database in
            try seedAllParts(in: database, serverId: validServerId)

            for part in DebugDatabaseTransfer.Part.allCases {
                let hasContent = try DebugDatabaseTransfer.hasExportableContent(part: part)
                #expect(hasContent == true)
            }
        }
    }

    @Test func exportWritesFeatureDiscriminator() throws {
        try withTransferTestWorld { database in
            try seedWatchConfiguration(in: database, serverId: validServerId)

            let url = try DebugDatabaseTransfer.exportURL(part: .watchConfiguration)
            let payload = try jsonPayload(from: url)

            #expect(payload["schemaVersion"] as? Int == 1)
            #expect(payload["exportedPart"] as? String == DebugDatabaseTransfer.Part.watchConfiguration.rawValue)
            #expect(payload["watchConfigurations"] as? [[String: Any]] != nil)
        }
    }

    @Test func validateImportRejectsWrongFeatureFile() throws {
        try withTransferTestWorld { database in
            try seedCarPlayConfiguration(in: database, serverId: validServerId)
            let url = try DebugDatabaseTransfer.exportURL(part: .carPlayConfiguration)

            do {
                try DebugDatabaseTransfer.validateImportFile(from: url, part: .watchConfiguration)
                Issue.record("Expected importing a CarPlay export from Watch settings to fail")
            } catch let error as DebugDatabaseTransfer.TransferError {
                guard case let .wrongFeatureFile(actual, expected) = error else {
                    Issue.record("Expected wrongFeatureFile, got \(error)")
                    return
                }
                #expect(actual == .carPlayConfiguration)
                #expect(expected == .watchConfiguration)
            }
        }
    }

    @Test func validateImportAcceptsEveryMatchingFeatureExport() throws {
        try withTransferTestWorld { database in
            try seedAllParts(in: database, serverId: validServerId)

            for part in DebugDatabaseTransfer.Part.allCases {
                let url = try DebugDatabaseTransfer.exportURL(part: part)
                try DebugDatabaseTransfer.validateImportFile(from: url, part: part)
            }
        }
    }

    @Test func importCarPlayReplacesOnlyCarPlayAndSanitizesUnknownServerItems() async throws {
        let sourceDatabase = try makeTransferDatabase()
        try seedCarPlayConfiguration(
            in: sourceDatabase,
            serverId: validServerId,
            invalidServerId: missingServerId,
            itemPrefix: "imported"
        )

        let destinationDatabase = try makeTransferDatabase()
        try seedCarPlayConfiguration(in: destinationDatabase, serverId: validServerId, itemPrefix: "existing")
        try seedWatchConfiguration(in: destinationDatabase, serverId: validServerId)

        let modelManager = NoOpModelManager()
        let appDatabaseUpdater = RecordingAppDatabaseUpdater()

        let url = try withTransferTestWorld(database: sourceDatabase) { _ in
            try DebugDatabaseTransfer.exportURL(part: .carPlayConfiguration)
        }

        try await withTransferTestWorld(
            database: destinationDatabase,
            modelManager: modelManager,
            appDatabaseUpdater: appDatabaseUpdater
        ) { database in
            let summary = try await DebugDatabaseTransfer.importPayload(from: url, part: .carPlayConfiguration)

            #expect(summary.carPlayConfigurations == 1)
            #expect(summary.totalRecords == 1)
            #expect(modelManager.cleanupCallCount == 1)
            #expect(appDatabaseUpdater.updatedServerIds == [validServerId])

            let storedCarPlayConfig = try CarPlayConfig.config()
            let carPlayConfig = try #require(storedCarPlayConfig)
            #expect(carPlayConfig.quickAccessItems.map(\.id) == ["imported-valid"])
            #expect(carPlayConfig.quickAccessItems.map(\.serverId) == [validServerId])

            let storedWatchConfig = try WatchConfig.config()
            let watchConfig = try #require(storedWatchConfig)
            #expect(watchConfig.items.map(\.id) == ["watch-valid"])

            let carPlayCount = try await database.read { db in try CarPlayConfig.fetchCount(db) }
            let watchCount = try await database.read { db in try WatchConfig.fetchCount(db) }
            #expect(carPlayCount == 1)
            #expect(watchCount == 1)
        }
    }

    private let validServerId = "server-valid"
    private let missingServerId = "server-missing"

    private func withTransferTestWorld(
        database: DatabaseQueue? = nil,
        modelManager: LegacyModelManager = NoOpModelManager(),
        appDatabaseUpdater: AppDatabaseUpdaterProtocol = RecordingAppDatabaseUpdater(),
        perform work: (DatabaseQueue) async throws -> Void
    ) async throws {
        let database = try database ?? makeTransferDatabase()
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let previousModelManager = Current.modelManager
        let previousAppDatabaseUpdater = Current.appDatabaseUpdater

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
        }

        try await work(database)
    }

    private func withTransferTestWorld<T>(
        database: DatabaseQueue? = nil,
        perform work: (DatabaseQueue) throws -> T
    ) throws -> T {
        let database = try database ?? makeTransferDatabase()
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

    private func makeTransferDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        return database
    }

    private func seedAllParts(in database: DatabaseQueue, serverId: String) throws {
        try seedWatchConfiguration(in: database, serverId: serverId)
        try seedComplications(in: database, serverId: serverId)
        try seedCarPlayConfiguration(in: database, serverId: serverId)
        try seedCustomWidgets(in: database, serverId: serverId)
        try seedAppIconShortcuts(in: database, serverId: serverId)
    }

    private func seedWatchConfiguration(in database: DatabaseQueue, serverId: String) throws {
        let config = WatchConfig(
            id: WatchConfig.watchConfigId,
            items: [.init(id: "watch-valid", serverId: serverId, type: .script)]
        )
        try database.write { db in
            try WatchConfig.deleteAll(db)
            try config.insert(db)
        }
    }

    private func seedComplications(in database: DatabaseQueue, serverId: String) throws {
        let legacy = WatchComplication(identifier: "legacy-valid", serverIdentifier: serverId, name: "Legacy")
        let config = WatchComplicationConfig(id: "config-valid", serverId: serverId, entityId: "sensor.temperature")
        try database.write { db in
            try WatchComplication.deleteAll(db)
            try WatchComplicationConfig.deleteAll(db)
            try legacy.insert(db)
            try config.insert(db)
        }
    }

    private func seedCarPlayConfiguration(
        in database: DatabaseQueue,
        serverId: String,
        invalidServerId: String? = nil,
        itemPrefix: String = "carplay"
    ) throws {
        var items: [MagicItem] = [
            .init(id: "\(itemPrefix)-valid", serverId: serverId, type: .script),
        ]
        if let invalidServerId {
            items.append(.init(id: "\(itemPrefix)-invalid", serverId: invalidServerId, type: .script))
        }
        let config = CarPlayConfig(quickAccessItems: items)
        try database.write { db in
            try CarPlayConfig.deleteAll(db)
            try config.insert(db)
        }
    }

    private func seedCustomWidgets(in database: DatabaseQueue, serverId: String) throws {
        let item = MagicItem(id: "widget-valid", serverId: serverId, type: .script)
        let widget = CustomWidget(id: "widget", name: "Widget", items: [item])
        try database.write { db in
            try CustomWidget.deleteAll(db)
            try widget.insert(db)
        }
    }

    private func seedAppIconShortcuts(in database: DatabaseQueue, serverId: String) throws {
        let config = AppIconShortcutConfig(items: [.init(id: "shortcut-valid", serverId: serverId, type: .script)])
        try database.write { db in
            try AppIconShortcutConfig.deleteAll(db)
            try config.insert(db)
        }
    }

    private func jsonPayload(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class NoOpModelManager: LegacyModelManager {
    var cleanupCallCount = 0

    override func cleanup(definitions: [CleanupDefinition] = CleanupDefinition.defaults) -> Promise<Void> {
        cleanupCallCount += 1
        return .value(())
    }
}

private final class RecordingAppDatabaseUpdater: AppDatabaseUpdaterProtocol {
    var updatedServerIds: [String] = []
    var stopCallCount = 0

    func stop() {
        stopCallCount += 1
    }

    func update(server: Server, forceUpdate: Bool) {
        if forceUpdate {
            updatedServerIds.append(server.identifier.rawValue)
        }
    }
}
