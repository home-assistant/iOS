import Foundation
import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import Testing

@Suite(.sharedState)
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

    @Test func transferErrorsDescribeThemselves() {
        let errors: [DebugDatabaseTransfer.TransferError] = [
            .unsupportedFile,
            .unsupportedFeatureFile,
            .wrongFeatureFile(actual: .customWidgets, expected: .complications),
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test func validateRejectsAFileThatIsNotJSON() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("debug-transfer-\(UUID()).txt")
        try Data("{}".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: DebugDatabaseTransfer.TransferError.self) {
            try DebugDatabaseTransfer.validateImportFile(from: url, part: .watchConfiguration)
        }
    }

    /// Files exported before the discriminator existed name their part through the only list they fill.
    @Test func validateInfersThePartOfAFileWithoutDiscriminator() throws {
        try withTransferTestWorld { database in
            try seedAllParts(in: database, serverId: validServerId)
            for part in DebugDatabaseTransfer.Part.allCases {
                let url = try strippedExport(of: part)
                defer { try? FileManager.default.removeItem(at: url) }
                try DebugDatabaseTransfer.validateImportFile(from: url, part: part)
            }
        }
    }

    /// Without a discriminator, a file filling several lists (or none) cannot be matched to a part.
    @Test func validateRejectsAnAmbiguousFileWithoutDiscriminator() throws {
        try withTransferTestWorld { database in
            try seedAllParts(in: database, serverId: validServerId)
            let watch = try strippedExport(of: .watchConfiguration)
            let carPlay = try strippedExport(of: .carPlayConfiguration)
            defer {
                try? FileManager.default.removeItem(at: watch)
                try? FileManager.default.removeItem(at: carPlay)
            }
            var mixed = try jsonPayload(from: watch)
            mixed["carPlayConfigurations"] = try jsonPayload(from: carPlay)["carPlayConfigurations"]
            try JSONSerialization.data(withJSONObject: mixed).write(to: watch)

            do {
                try DebugDatabaseTransfer.validateImportFile(from: watch, part: .watchConfiguration)
                Issue.record("Expected a mixed file without discriminator to be rejected")
            } catch DebugDatabaseTransfer.TransferError.unsupportedFeatureFile {
                // expected
            }
        }
    }

    /// Importing each remaining part replaces only its rows, drops what points at an unknown server
    /// and refreshes the surfaces that show it.
    @Test(arguments: [
        DebugDatabaseTransfer.Part.watchConfiguration,
        .complications,
        .customWidgets,
        .appIconShortcuts,
    ])
    func importReplacesThePartAndDropsUnknownServers(part: DebugDatabaseTransfer.Part) async throws {
        let sourceDatabase = try makeTransferDatabase()
        try seedMixedServers(part: part, in: sourceDatabase)
        let url = try withTransferTestWorld(database: sourceDatabase) { _ in
            try DebugDatabaseTransfer.exportURL(part: part)
        }
        defer { try? FileManager.default.removeItem(at: url) }

        let destinationDatabase = try makeTransferDatabase()
        try await withTransferTestWorld(database: destinationDatabase) { _ in
            let summary = try await DebugDatabaseTransfer.importPayload(from: url, part: part)
            switch part {
            case .watchConfiguration:
                #expect(summary.watchConfigurations == 1)
                let storedConfig = try WatchConfig.config()
                let config = try #require(storedConfig)
                #expect(config.items.map(\.id) == ["watch-valid"])
                #expect(config.assist.serverId == nil)
                #expect(config.assist.pipelineId == nil)
            case .complications:
                #expect(summary.legacyComplications == 2)
                #expect(summary.complicationConfigurations == 1)
            case .customWidgets:
                #expect(summary.customWidgets == 1)
                let storedWidgets = try CustomWidget.widgets()
                let widgets = try #require(storedWidgets)
                #expect(widgets.map(\.id) == ["mixed"])
                #expect(widgets.first?.items.map(\.id) == ["customWidgets-valid"])
            case .appIconShortcuts:
                #expect(summary.appIconShortcutConfigurations == 1)
            case .carPlayConfiguration:
                Issue.record("CarPlay is covered by its own test")
            }
        }
    }

    @Test func importFailsWhenThePostImportCleanupFails() async throws {
        let sourceDatabase = try makeTransferDatabase()
        try seedCarPlayConfiguration(in: sourceDatabase, serverId: validServerId)
        let url = try withTransferTestWorld(database: sourceDatabase) { _ in
            try DebugDatabaseTransfer.exportURL(part: .carPlayConfiguration)
        }
        defer { try? FileManager.default.removeItem(at: url) }

        try await withTransferTestWorld(modelManager: FailingModelManager()) { _ in
            await #expect(throws: (any Error).self) {
                _ = try await DebugDatabaseTransfer.importPayload(from: url, part: .carPlayConfiguration)
            }
        }
    }

    /// Exports `part` and removes its feature discriminator, as older exports were written.
    private func strippedExport(of part: DebugDatabaseTransfer.Part) throws -> URL {
        let url = try DebugDatabaseTransfer.exportURL(part: part)
        var payload = try jsonPayload(from: url)
        payload.removeValue(forKey: "exportedPart")
        try JSONSerialization.data(withJSONObject: payload).write(to: url)
        return url
    }

    /// Seeds `part` with rows for the known server and for one the destination does not know.
    private func seedMixedServers(part: DebugDatabaseTransfer.Part, in database: DatabaseQueue) throws {
        let valid = MagicItem(id: "\(part.rawValue)-valid", serverId: validServerId, type: .script)
        let invalid = MagicItem(id: "\(part.rawValue)-invalid", serverId: missingServerId, type: .script)
        try database.write { db in
            switch part {
            case .watchConfiguration:
                var config = WatchConfig(id: WatchConfig.watchConfigId, items: [
                    .init(id: "watch-valid", serverId: validServerId, type: .script),
                    .init(id: "watch-invalid", serverId: missingServerId, type: .script),
                ])
                config.assist = .init(showAssist: true, serverId: missingServerId, pipelineId: "pipeline")
                try config.insert(db)
            case .complications:
                try WatchComplication(identifier: "legacy-valid", serverIdentifier: validServerId, name: "A")
                    .insert(db)
                try WatchComplication(identifier: "legacy-unowned", serverIdentifier: nil, name: "B").insert(db)
                try WatchComplication(identifier: "legacy-invalid", serverIdentifier: missingServerId, name: "C")
                    .insert(db)
                try WatchComplicationConfig(id: "config-valid", serverId: validServerId, entityId: "sensor.a")
                    .insert(db)
                try WatchComplicationConfig(id: "config-invalid", serverId: missingServerId, entityId: "sensor.b")
                    .insert(db)
            case .customWidgets:
                try CustomWidget(
                    id: "mixed",
                    name: "Mixed",
                    items: [valid, invalid],
                    itemsStates: [valid.serverUniqueId: .idle, invalid.serverUniqueId: .pendingConfirmation]
                ).insert(db)
                try CustomWidget(id: "orphan", name: "Orphan", items: [invalid]).insert(db)
            case .appIconShortcuts:
                try AppIconShortcutConfig(items: [valid, invalid]).insert(db)
            case .carPlayConfiguration:
                try CarPlayConfig(quickAccessItems: [valid, invalid]).insert(db)
            }
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

    func update(server: Server, forceUpdate: Bool, showProgress _: Bool) {
        if forceUpdate {
            updatedServerIds.append(server.identifier.rawValue)
        }
    }
}

private final class FailingModelManager: LegacyModelManager {
    override func cleanup(definitions: [CleanupDefinition] = CleanupDefinition.defaults) -> Promise<Void> {
        .init(error: URLError(.cannotOpenFile))
    }
}
