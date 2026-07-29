import Foundation
import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing

@MainActor
@Suite(.serialized)
struct ImportExportConfigurationViewModelTests {
    @Test func refreshingCountsReportsWhatIsConfigured() async throws {
        try await withViewModelTestWorld { database, viewModel in
            try seedCustomWidget(in: database, id: "widget")

            viewModel.refreshEntryCounts()

            #expect(viewModel.entryCount(for: .customWidgets) == 1)
            #expect(viewModel.entryCount(for: .nfcTags) == 0)
            #expect(viewModel.entryCount(for: .appSettings) == 1)
        }
    }

    @Test func exportOffersTheFileForSharing() async throws {
        try await withViewModelTestWorld { database, viewModel in
            try seedCustomWidget(in: database, id: "widget")

            await viewModel.export()

            let shareWrapper = try #require(viewModel.shareWrapper)
            #expect(shareWrapper.url.pathExtension == "json")
            #expect(viewModel.isExporting == false)
            #expect(viewModel.errorMessage == nil)
        }
    }

    @Test func choosingAConfigurationFileAsksForConfirmationFirst() async throws {
        try await withViewModelTestWorld { database, viewModel in
            try seedCustomWidget(in: database, id: "widget")
            let url = try AppConfigurationTransfer.exportURL(appSettings: AppSettingsSnapshot.capture())

            await viewModel.handleFileSelection(.success([url]))

            #expect(viewModel.showImportConfirmation)
            #expect(viewModel.pendingImportFilename == url.lastPathComponent)
            #expect(viewModel.pendingImportSummary.contains(AppConfigurationCategory.customWidgets.title))
            #expect(viewModel.errorMessage == nil)
        }
    }

    @Test func choosingASingleFeatureFileFailsWithoutTouchingTheDatabase() async throws {
        try await withViewModelTestWorld { database, viewModel in
            try seedCustomWidget(in: database, id: "existing")
            let url = try DebugDatabaseTransfer.exportURL(part: .customWidgets)

            await viewModel.handleFileSelection(.success([url]))

            #expect(viewModel.showImportConfirmation == false)
            #expect(viewModel.pendingImportFilename.isEmpty)
            #expect(viewModel.errorMessage != nil)

            let widgets = try database.read { db in try CustomWidget.fetchAll(db) }
            #expect(widgets.map(\.id) == ["existing"])
        }
    }

    @Test func cancellingForgetsTheSelectedFile() async throws {
        try await withViewModelTestWorld { database, viewModel in
            try seedCustomWidget(in: database, id: "widget")
            let url = try AppConfigurationTransfer.exportURL(appSettings: AppSettingsSnapshot.capture())
            await viewModel.handleFileSelection(.success([url]))

            viewModel.cancelImport()

            #expect(viewModel.pendingImportFilename.isEmpty)
            #expect(viewModel.pendingImportSummary.isEmpty)
        }
    }

    @Test func confirmingWithoutASelectedFileDoesNothing() async throws {
        try await withViewModelTestWorld { database, viewModel in
            try seedCustomWidget(in: database, id: "existing")

            await viewModel.confirmImport()

            #expect(viewModel.isImporting == false)
            let widgets = try database.read { db in try CustomWidget.fetchAll(db) }
            #expect(widgets.map(\.id) == ["existing"])
        }
    }

    @Test func confirmingImportReplacesConfigurationAndRefreshesCounts() async throws {
        let sourceDatabase = try makeViewModelDatabase()
        try seedCustomWidget(in: sourceDatabase, id: "imported")
        let restoreSource = prepareWorld(database: sourceDatabase)
        let url = try AppConfigurationTransfer.exportURL(appSettings: AppSettingsSnapshot.capture())
        restoreSource()

        let destinationDatabase = try makeViewModelDatabase()
        try seedCustomWidget(in: destinationDatabase, id: "existing")

        try await withViewModelTestWorld(database: destinationDatabase) { database, viewModel in
            await viewModel.handleFileSelection(.success([url]))

            await viewModel.confirmImport()

            #expect(viewModel.isImporting == false)
            #expect(viewModel.errorMessage == nil)
            #expect(viewModel.pendingImportFilename.isEmpty)
            #expect(viewModel.entryCount(for: .customWidgets) == 1)

            let widgets = try database.read { db in try CustomWidget.fetchAll(db) }
            #expect(widgets.map(\.id) == ["imported"])
        }
    }

    private let serverId = "server-valid"

    private func withViewModelTestWorld(
        database: DatabaseQueue? = nil,
        perform work: @MainActor (DatabaseQueue, ImportExportConfigurationViewModel) async throws -> Void
    ) async throws {
        let database = try database ?? makeViewModelDatabase()
        let restore = prepareWorld(database: database)
        defer { restore() }

        try await work(database, ImportExportConfigurationViewModel())
    }

    /// Points the world at an isolated database with a single known server, and returns the closure
    /// that puts everything back.
    ///
    /// Importing applies an `AppSettingsSnapshot`, which writes across the shared app group
    /// defaults, so the snapshot taken here is re-applied on the way out: it covers exactly the
    /// preferences an import can touch, using the same code path. The menu bar template is restored
    /// by key on top of that, because `apply()` skips it when its server is gone.
    private func prepareWorld(database: DatabaseQueue) -> @MainActor () -> Void {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let previousModelManager = Current.modelManager
        let previousAppDatabaseUpdater = Current.appDatabaseUpdater
        let previousSettings = AppSettingsSnapshot.capture()
        let previousMenuItemTemplate = Current.settingsStore.prefs.string(forKey: "menuItemTemplate")
        let previousMenuItemTemplateServer = Current.settingsStore.prefs.string(forKey: "menuItemTemplate-server")

        let servers = FakeServerManager(initial: 0)
        servers.add(identifier: .init(rawValue: serverId), serverInfo: .fake())

        Current.database = { database }
        Current.servers = servers
        Current.modelManager = NoOpViewModelModelManager()
        Current.appDatabaseUpdater = NoOpViewModelAppDatabaseUpdater()

        return {
            Current.database = previousDatabase
            Current.servers = previousServers
            Current.modelManager = previousModelManager
            Current.appDatabaseUpdater = previousAppDatabaseUpdater
            previousSettings.apply()
            Current.settingsStore.prefs.set(previousMenuItemTemplate, forKey: "menuItemTemplate")
            Current.settingsStore.prefs.set(previousMenuItemTemplateServer, forKey: "menuItemTemplate-server")
        }
    }

    private func makeViewModelDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        return database
    }

    private func seedCustomWidget(in database: DatabaseQueue, id: String) throws {
        let item = MagicItem(id: "\(id)-item", serverId: serverId, type: .script)
        try database.write { db in
            try CustomWidget.deleteAll(db)
            try CustomWidget(id: id, name: id, items: [item]).insert(db, onConflict: .replace)
        }
    }
}

private final class NoOpViewModelModelManager: LegacyModelManager {
    override func cleanup(definitions _: [CleanupDefinition] = CleanupDefinition.defaults) -> Promise<Void> {
        .value(())
    }
}

private final class NoOpViewModelAppDatabaseUpdater: AppDatabaseUpdaterProtocol {
    func stop() {}

    func update(server _: Server, forceUpdate _: Bool, showProgress _: Bool) {}
}
