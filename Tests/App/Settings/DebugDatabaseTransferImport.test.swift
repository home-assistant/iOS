import Foundation
import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Import paths of the per-feature debug database transfer that the round-trip tests don't reach:
/// the files it refuses, the errors it reports, and a custom widgets import.
@MainActor
@Suite(.serialized)
struct DebugDatabaseTransferImportTests {
    private let serverId = "transfer-import-server"

    @Test func everyPartHasATitleAndASlug() {
        for part in DebugDatabaseTransfer.Part.allCases {
            #expect(part.title.isEmpty == false)
            #expect(part.filenameSlug == part.rawValue)
        }
    }

    @Test func errorsDescribeThemselves() {
        let errors: [DebugDatabaseTransfer.TransferError] = [
            .unsupportedFile,
            .unsupportedFeatureFile,
            .wrongFeatureFile(actual: .customWidgets, expected: .appIconShortcuts),
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test func summaryAddsUpEveryKindOfRecord() {
        let summary = DebugDatabaseTransferSummary(
            watchConfigurations: 1,
            legacyComplications: 2,
            complicationConfigurations: 3,
            carPlayConfigurations: 4,
            customWidgets: 5,
            appIconShortcutConfigurations: 6
        )
        #expect(summary.totalRecords == 21)
    }

    @Test func aFileThatIsNotJSONIsRefused() throws {
        let url = try writeFile(named: "export.txt", contents: "{}")

        do {
            try DebugDatabaseTransfer.validateImportFile(from: url, part: .customWidgets)
            Issue.record("Expected a non-JSON file to be refused")
        } catch let error as DebugDatabaseTransfer.TransferError {
            guard case .unsupportedFile = error else {
                Issue.record("Expected unsupportedFile, got \(error)")
                return
            }
        }
    }

    @Test func aFileWithoutAFeatureIsRefused() throws {
        let url = try writeFile(named: "no-feature.json", contents: """
        {
          "schemaVersion": 1,
          "exportedAt": "2024-03-15T12:00:00Z",
          "watchConfigurations": [],
          "legacyComplications": [],
          "complicationConfigurations": [],
          "carPlayConfigurations": [],
          "customWidgets": [],
          "appIconShortcutConfigurations": []
        }
        """)

        do {
            try DebugDatabaseTransfer.validateImportFile(from: url, part: .customWidgets)
            Issue.record("Expected a file without a feature to be refused")
        } catch let error as DebugDatabaseTransfer.TransferError {
            guard case .unsupportedFeatureFile = error else {
                Issue.record("Expected unsupportedFeatureFile, got \(error)")
                return
            }
        }
    }

    @Test func importingCustomWidgetsReplacesThemAndDropsUnknownServers() async throws {
        let source = try makeDatabase()
        try await source.write { [serverId] db in
            try CustomWidget(
                id: "imported",
                name: "Imported",
                items: [
                    MagicItem(id: "script.kept", serverId: serverId, type: .script),
                    MagicItem(id: "script.dropped", serverId: "unknown-server", type: .script),
                ]
            ).insert(db)
        }
        let url = try withWorld(database: source) {
            try DebugDatabaseTransfer.exportURL(part: .customWidgets)
        }

        let destination = try makeDatabase()
        try await destination.write { [serverId] db in
            try CustomWidget(
                id: "existing",
                name: "Existing",
                items: [MagicItem(id: "script.old", serverId: serverId, type: .script)]
            ).insert(db)
        }

        let previousModelManager = Current.modelManager
        let previousUpdater = Current.appDatabaseUpdater
        defer {
            Current.modelManager = previousModelManager
            Current.appDatabaseUpdater = previousUpdater
        }
        Current.modelManager = TransferImportModelManager()
        Current.appDatabaseUpdater = TransferImportAppDatabaseUpdater()

        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        Current.database = { destination }
        Current.servers = makeServers()

        let summary = try await DebugDatabaseTransfer.importPayload(from: url, part: .customWidgets)
        #expect(summary.customWidgets == 1)
        #expect(summary.totalRecords == 1)

        let widgets = try await destination.read { db in try CustomWidget.fetchAll(db) }
        #expect(widgets.map(\.id) == ["imported"])
        #expect(widgets.first?.items.map(\.id) == ["script.kept"])
    }

    @Test func sectionRendersForEveryPart() throws {
        try withWorld(database: makeDatabase()) {
            for part in DebugDatabaseTransfer.Part.allCases {
                let controller = UIHostingController(rootView: List { DebugDatabaseTransferSection(part: part) })
                let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
                window.rootViewController = controller
                window.isHidden = false
                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                controller.view.layoutIfNeeded()
                window.isHidden = true
                window.rootViewController = nil
            }
        }
    }

    private func makeServers() -> FakeServerManager {
        let servers = FakeServerManager(initial: 0)
        servers.add(identifier: .init(rawValue: serverId), serverInfo: .fake())
        return servers
    }

    private func makeDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        return database
    }

    private func writeFile(named name: String, contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("dir")
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func withWorld<T>(database: DatabaseQueue, _ work: () throws -> T) throws -> T {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        Current.database = { database }
        Current.servers = makeServers()
        return try work()
    }
}

private final class TransferImportModelManager: LegacyModelManager {
    override func cleanup(definitions _: [CleanupDefinition] = CleanupDefinition.defaults) -> Promise<Void> {
        .value(())
    }
}

private final class TransferImportAppDatabaseUpdater: AppDatabaseUpdaterProtocol {
    func stop() {}

    func update(server: Server, forceUpdate: Bool, showProgress: Bool) {}
}
