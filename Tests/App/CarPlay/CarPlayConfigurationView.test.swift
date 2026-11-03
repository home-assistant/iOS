import GRDB
import HAKit
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Renders the CarPlay settings screen, pushed and presented modally, with every item kind and
/// with the add/edit toggle in both positions.
@Suite(.sharedState)
@MainActor
struct CarPlayConfigurationViewTests {
    private final class StubMagicItemProvider: MagicItemProviderProtocol {
        func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
            completion([:])
        }

        func loadInformation() async -> [String: [HAAppEntity]] {
            [:]
        }

        func getInfo(for item: MagicItem) -> MagicItem.Info? {
            .init(id: item.id, name: item.id, iconName: "", customization: nil)
        }

        func getAreaName(for item: MagicItem) -> String? {
            nil
        }
    }

    private let items = [
        MagicItem(id: "light.kitchen", serverId: "s", type: .entity),
        MagicItem(id: "folder", serverId: "", type: .folder, displayText: "Garage", items: []),
        MagicItem(
            id: "prompt", serverId: "s", type: .assistPrompt, displayText: "Lights",
            assistPrompt: "Turn on the lights", assistPipelineId: ""
        ),
    ]

    private func seed(_ database: DatabaseQueue, _ config: CarPlayConfig) throws {
        try database.write { db in try config.insert(db) }
    }

    /// Runs `body` against an in-memory database seeded with `config`. The view model autosaves on
    /// an unstructured main-actor task that reads `Current.database` when it runs, so a test that
    /// changes a setting waits for that save to land in this database before `Current` is restored.
    private func withConfiguration(
        _ config: CarPlayConfig?,
        _ body: (DatabaseQueue) async throws -> Void
    ) async throws {
        let previousDatabase = Current.database
        let previousProvider = Current.magicItemProvider
        defer {
            Current.database = previousDatabase
            Current.magicItemProvider = previousProvider
        }
        let database = try CarPlayTestDatabase.make()
        if let config {
            try seed(database, config)
        }
        Current.database = { database }
        Current.magicItemProvider = { StubMagicItemProvider() }
        try await body(database)
    }

    private func storedConfig(_ database: DatabaseQueue) -> CarPlayConfig? {
        try? database.read { db in try CarPlayConfig.fetchOne(db) }
    }

    @Test func aModalPresentationLoadsTheStoredItems() async throws {
        try await withConfiguration(CarPlayConfig(quickAccessItems: items, quickAccessLayout: .list)) { database in
            let viewModel = CarPlayConfigurationViewModel()
            let host = CarPlaySwiftUIHost(CarPlayConfigurationView(needsNavigationStack: true, viewModel: viewModel))
            defer { host.close() }

            let loaded = await carPlayEventually { viewModel.config.quickAccessItems.count == 3 }
            try #require(loaded)
            #expect(viewModel.showAddEditButtons)
            host.layout()

            // What the add/edit toggle's binding does: SwiftUI controls don't expose accessibility
            // elements to activate in a hosted unit test, so the test drives the view model.
            viewModel.showAddEditButtons = false
            host.layout()
            #expect(!viewModel.showAddEditButtons)
            let saved = await carPlayEventually { storedConfig(database)?.showAddEditButtons == false }
            #expect(saved)
        }
    }

    @Test func aPushedScreenRendersTheDefaults() async throws {
        try await withConfiguration(nil) { _ in
            let viewModel = CarPlayConfigurationViewModel()
            // Changed before the screen loads, which doesn't autosave; loading the empty database
            // puts the setting back to its stored default.
            viewModel.showAddEditButtons = false
            let host = CarPlaySwiftUIHost(NavigationStack { CarPlayConfigurationView(viewModel: viewModel) })
            defer { host.close() }

            let loaded = await carPlayEventually { viewModel.config.showAddEditButtons == nil }
            #expect(loaded)
            #expect(viewModel.showAddEditButtons)
            #expect(viewModel.config.tabs == CarPlayConfig().tabs)
        }
    }
}
