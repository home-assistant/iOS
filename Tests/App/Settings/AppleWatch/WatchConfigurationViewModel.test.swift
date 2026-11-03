import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// The watch home configuration's view model: moving and removing items, edits that match nothing,
/// resetting the configuration, and the database failures it reports.
/// Shared state: swaps `Current.database`, `Current.servers` and `Current.magicItemProvider`.
@MainActor
@Suite(.sharedState)
struct WatchConfigurationViewModelTests {
    private let kitchen = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
    private let porch = MagicItem(id: "light.porch", serverId: "1", type: .entity)

    @Test func itemsAreMovedRemovedAndUnknownEditsIgnored() throws {
        try withWorld { _ in
            let viewModel = WatchConfigurationViewModel()
            viewModel.addItem(kitchen)
            viewModel.addItem(porch)
            viewModel.addFolder(named: "Downstairs")

            viewModel.moveItem(from: IndexSet(integer: 0), to: 2)
            #expect(viewModel.watchConfig.items.map(\.id).prefix(2) == ["light.porch", "light.kitchen"])

            let unknown = MagicItem(id: "light.unknown", serverId: "1", type: .entity)
            let before = viewModel.watchConfig.items
            viewModel.updateItem(unknown)
            viewModel.moveItemToFolder(itemId: "light.unknown", serverId: "1", toFolderId: "nowhere")
            #expect(viewModel.watchConfig.items == before)

            viewModel.deleteItem(at: IndexSet(integer: 0))
            #expect(viewModel.watchConfig.items.map(\.id).first == "light.kitchen")
        }
    }

    @Test func resettingDeletesTheStoredConfiguration() throws {
        try withWorld { database in
            let viewModel = WatchConfigurationViewModel()
            viewModel.addItem(kitchen)
            #expect(viewModel.save())

            var reset: Bool?
            viewModel.deleteConfiguration { reset = $0 }
            #expect(reset == true)
            let count = try database.read { db in try WatchConfig.fetchCount(db) }
            #expect(count == 0)
        }
    }

    @Test func databaseFailuresAreReported() async throws {
        try withWorld { _ in
            Current.database = { try! DatabaseQueue() }
            let viewModel = WatchConfigurationViewModel()
            viewModel.addItem(kitchen)
            #expect(!viewModel.save())

            var reset: Bool?
            viewModel.deleteConfiguration { reset = $0 }
            #expect(reset == nil)

            viewModel.loadWatchConfig()
        }
        let viewModel = WatchConfigurationViewModel()
        try withWorld { _ in
            Current.database = { try! DatabaseQueue() }
            viewModel.loadWatchConfig()
        }
        for _ in 0 ..< 500 where !viewModel.showError {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(viewModel.showError)
        #expect(viewModel.errorMessage != nil)
    }

    private func withWorld(_ body: (DatabaseQueue) throws -> Void) throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let previousProvider = Current.magicItemProvider
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
            Current.magicItemProvider = previousProvider
        }
        let database = try SettingsTestDatabase.make()
        Current.database = { database }
        Current.servers = FakeServerManager(initial: 1)
        Current.magicItemProvider = { ImmediateMagicItemProvider() }
        try body(database)
    }
}

private final class ImmediateMagicItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        nil
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
