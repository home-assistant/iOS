import Foundation
import GRDB
import HAKit
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

@Suite(.sharedState)
struct CarPlayConfigurationViewModelTests {
    @Test func updateItemReplacesAssistPromptMovedToAnotherServer() {
        let viewModel = CarPlayConfigurationViewModel()
        let prompt = MagicItem(
            id: "prompt-id",
            serverId: "server1",
            type: .assistPrompt,
            displayText: "Lights",
            assistPrompt: "Turn on the lights",
            assistPipelineId: ""
        )
        viewModel.addItem(prompt)

        var moved = prompt
        moved.serverId = "server2"
        viewModel.updateItem(moved)

        #expect(viewModel.config.quickAccessItems.count == 1)
        #expect(viewModel.config.quickAccessItems[0].serverId == "server2")
    }

    @Test func updateItemInFolderReplacesAssistPromptMovedToAnotherServer() throws {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addFolder(named: "My Folder")
        let folderId = try #require(viewModel.config.quickAccessItems.first(where: { $0.type == .folder })?.id)
        let prompt = MagicItem(
            id: "prompt-id",
            serverId: "server1",
            type: .assistPrompt,
            displayText: "Lights",
            assistPrompt: "Turn on the lights",
            assistPipelineId: ""
        )
        viewModel.addItemToFolder(folderId: folderId, item: prompt)

        var moved = prompt
        moved.serverId = "server2"
        viewModel.updateItemInFolder(folderId: folderId, item: moved)

        let folder = try #require(viewModel.config.quickAccessItems.first(where: { $0.id == folderId }))
        #expect(folder.items?.count == 1)
        #expect(folder.items?.first?.serverId == "server2")
    }

    // MARK: - Loading, saving and deleting

    private final class StubMagicItemProvider: MagicItemProviderProtocol {
        func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
            completion([:])
        }

        func loadInformation() async -> [String: [HAAppEntity]] {
            [:]
        }

        func getInfo(for item: MagicItem) -> MagicItem.Info? {
            .init(id: item.id, name: "Stub \(item.id)", iconName: "", customization: nil)
        }

        func getAreaName(for item: MagicItem) -> String? {
            nil
        }
    }

    /// Runs `body` against `database` and a stub item provider, restoring the app's afterwards.
    @MainActor
    private func withDatabase(
        _ database: DatabaseQueue,
        _ body: () async throws -> Void
    ) async rethrows {
        let previousDatabase = Current.database
        let previousProvider = Current.magicItemProvider
        defer {
            Current.database = previousDatabase
            Current.magicItemProvider = previousProvider
        }
        Current.database = { database }
        Current.magicItemProvider = { StubMagicItemProvider() }
        try await body()
    }

    /// A database whose every access throws.
    private func closedDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue(path: ":memory:")
        try database.close()
        return database
    }

    private func seed(_ database: DatabaseQueue, _ config: CarPlayConfig) throws {
        try database.write { db in try config.insert(db) }
    }

    /// A row whose columns don't decode into a `CarPlayConfig`.
    private func writeUndecodableConfig(_ database: DatabaseQueue) throws {
        try database.write { db in
            let columns = DatabaseTables.CarPlayConfig.self
            try db.execute(
                sql: """
                INSERT INTO \(GRDBDatabaseTable.carPlayConfig.rawValue) \
                (\(columns.id.rawValue), \(columns.tabs.rawValue), \(columns.quickAccessItems.rawValue)) \
                VALUES (?, ?, ?)
                """,
                arguments: [CarPlayConfig.carPlayConfigId, "not-json", "not-json"]
            )
        }
    }

    private func storedConfig(_ database: DatabaseQueue) throws -> CarPlayConfig? {
        try database.read { db in try CarPlayConfig.fetchOne(db) }
    }

    @Test @MainActor func loadingReadsTheStoredConfigAndStripsNestedFolders() async throws {
        let database = try CarPlayTestDatabase.make()
        let nested = MagicItem(id: "nested", serverId: "", type: .folder)
        let light = MagicItem(id: "light.a", serverId: "s", type: .entity)
        let folder = MagicItem(id: "folder", serverId: "", type: .folder, items: [nested, light])
        try seed(database, CarPlayConfig(quickAccessItems: [folder], tabFolders: [folder]))

        try await withDatabase(database) {
            let viewModel = CarPlayConfigurationViewModel()
            viewModel.loadConfig()
            let loaded = await carPlayEventually { !viewModel.config.quickAccessItems.isEmpty }
            #expect(loaded)
            #expect(viewModel.config.quickAccessItems.first?.items?.map(\.id) == ["light.a"])
            #expect(viewModel.config.tabFolders?.first?.items?.map(\.id) == ["light.a"])
            #expect(viewModel.magicItemInfo(for: light)?.name == "Stub light.a")
        }
    }

    /// An item handed over from the frontend's "Add to" is appended once loading finishes, and the
    /// change saves itself.
    @Test @MainActor func aPrefilledItemIsAddedToTheDefaultConfigAndSaved() async throws {
        let database = try CarPlayTestDatabase.make()
        let item = MagicItem(id: "light.prefilled", serverId: "s", type: .entity)

        try await withDatabase(database) {
            let viewModel = CarPlayConfigurationViewModel(prefilledItem: item)
            viewModel.loadConfig()
            let saved = await carPlayEventually {
                (try? storedConfig(database))?.quickAccessItems.map(\.id) == ["light.prefilled"]
            }
            #expect(saved)
            #expect(viewModel.config.tabs == CarPlayConfig().tabs)
        }
    }

    @Test @MainActor func aStoredConfigThatCannotBeDecodedFallsBackToTheDefault() async throws {
        let database = try CarPlayTestDatabase.make()
        try writeUndecodableConfig(database)

        try await withDatabase(database) {
            let viewModel = CarPlayConfigurationViewModel()
            viewModel.addItem(MagicItem(id: "light.before", serverId: "s", type: .entity))
            viewModel.loadConfig()
            let reset = await carPlayEventually { viewModel.config.quickAccessItems.isEmpty }
            #expect(reset)
        }
    }

    @Test @MainActor func aDatabaseThatCannotBeReadShowsAnError() async throws {
        try await withDatabase(closedDatabase()) {
            let viewModel = CarPlayConfigurationViewModel()
            viewModel.loadConfig()
            let shown = await carPlayEventually { viewModel.showError }
            #expect(shown)
            #expect(viewModel.errorMessage != nil)

            #expect(!viewModel.save())

            var deleted = false
            viewModel.deleteConfiguration { deleted = $0 }
            #expect(!deleted)
        }
    }

    @Test @MainActor func deletingRemovesTheStoredConfig() async throws {
        let database = try CarPlayTestDatabase.make()
        try seed(database, CarPlayConfig())

        try await withDatabase(database) {
            let viewModel = CarPlayConfigurationViewModel()
            var deleted = false
            viewModel.deleteConfiguration { deleted = $0 }

            #expect(deleted)
            let stored = try storedConfig(database)
            #expect(stored == nil)
        }
    }

    // MARK: - Editing

    @Test func tabsCanBeAddedOnceMovedAndRemoved() {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addTabFolder(named: "Errands")
        let folderTab = viewModel.config.tabs.last
        #expect(folderTab?.folderId != nil)
        #expect(viewModel.config.tabFolders?.first?.displayText == "Errands")

        viewModel.updateTab(.domains, active: true)
        viewModel.updateTab(.domains, active: true)
        #expect(viewModel.config.tabs.filter { $0 == .domains }.count == 1)

        viewModel.moveTab(from: IndexSet(integer: 0), to: viewModel.config.tabs.count)
        #expect(viewModel.config.tabs.last == .quickAccess)

        viewModel.updateTab(.areas, active: false)
        #expect(!viewModel.config.tabs.contains(.areas))
        #expect(viewModel.config.tabFolders?.count == 1, "a folder with a tab stays")

        let folderIndex = viewModel.config.tabs.firstIndex { $0.folderId != nil }
        viewModel.deleteTab(at: IndexSet(integer: folderIndex ?? 0))
        #expect(viewModel.config.tabFolders?.isEmpty == true, "a tab-only folder goes with its tab")
    }

    @Test func deletingAFolderAlsoRemovesItsTab() throws {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addItem(MagicItem(id: "light.a", serverId: "s", type: .entity))
        viewModel.addFolder(named: "Garage")
        let folderId = try #require(viewModel.config.quickAccessItems.last?.id)
        viewModel.updateTab(.folder(folderId: folderId), active: true)

        viewModel.moveItem(from: IndexSet(integer: 1), to: 0)
        #expect(viewModel.config.quickAccessItems.first?.id == folderId)

        viewModel.deleteItem(at: IndexSet(integer: 1))
        #expect(viewModel.config.tabs.contains(.folder(folderId: folderId)), "deleting an entity keeps tabs")

        viewModel.deleteItem(at: IndexSet(integer: 0))
        #expect(viewModel.config.quickAccessItems.isEmpty)
        #expect(!viewModel.config.tabs.contains(.folder(folderId: folderId)))
    }

    @Test func foldersCanBeRenamedAndTheirItemsEdited() throws {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addFolder(named: "Garage")
        var folder = try #require(viewModel.config.quickAccessItems.first)
        for id in ["light.a", "light.b", "light.c"] {
            viewModel.addItemToFolder(folderId: folder.id, item: MagicItem(id: id, serverId: "s", type: .entity))
        }

        folder.displayText = "Car port"
        folder.items = []
        viewModel.updateFolder(folder)
        viewModel.updateFolder(MagicItem(id: folder.id, serverId: "s", type: .entity))
        let renamed = try #require(viewModel.config.quickAccessItems.first)
        #expect(renamed.displayText == "Car port")
        #expect(renamed.items?.count == 3, "renaming keeps the folder's items")

        viewModel.moveItemWithinFolder(folderId: folder.id, from: IndexSet(integer: 2), to: 0)
        #expect(viewModel.config.quickAccessItems.first?.items?.first?.id == "light.c")
        viewModel.deleteItemInFolder(folderId: folder.id, at: IndexSet(integer: 0))
        #expect(viewModel.config.quickAccessItems.first?.items?.map(\.id) == ["light.a", "light.b"])
    }

    @Test func layoutAndAddEditVisibilityAreStored() {
        let viewModel = CarPlayConfigurationViewModel()

        viewModel.quickAccessLayout = .list
        viewModel.showAddEditButtons = false

        #expect(viewModel.config.quickAccessLayout == .list)
        #expect(viewModel.quickAccessLayout == .list)
        #expect(viewModel.config.showAddEditButtons == false)
        #expect(!viewModel.showAddEditButtons)
    }
}
