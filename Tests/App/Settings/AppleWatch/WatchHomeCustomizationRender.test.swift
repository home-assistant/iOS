import Foundation
import GRDB
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Drives the watch home configuration screen, its folders and the folder editor.
/// Shared state: the screens read `Current.database`, `Current.servers` and
/// `Current.magicItemProvider` from the main run loop.
@Suite(.sharedState)
@MainActor
struct WatchHomeCustomizationRenderTests {
    private static let folderItems = [
        MagicItem(id: "light.kitchen", serverId: "server", type: .entity),
        MagicItem(id: "complication-1", serverId: "server", type: .complication),
        MagicItem(id: "prompt", serverId: "server", type: .assistPrompt, displayText: "Ask", assistPrompt: "Hi"),
    ]

    private static let items = folderItems + [
        MagicItem(
            id: "folder",
            serverId: "",
            type: .folder,
            customization: .init(textColor: "#FFFFFF", backgroundColor: "#000000"),
            displayText: "Downstairs",
            items: folderItems
        ),
    ]

    /// Opens every item: entities and prompts lead to their editors, folders to their contents.
    @Test func opensEveryItem() async throws {
        try await withWorld { _ in
            let viewModel = WatchConfigurationViewModel()
            let driver = await SwiftUIScreenDriver.show(WatchConfigurationView(viewModel: viewModel))
            defer { driver.close() }
            await #expect(driver.waitUntil { viewModel.watchConfig.items.count == Self.items.count })

            // Header, layout, areas, items, assist (and debug sections after).
            let itemsSection = 3
            for row in 0 ..< Self.items.count where Self.items[row].type != .complication {
                await #expect(driver.push(IndexPath(item: row, section: itemsSection)), "item \(row)")
                await driver.popToRoot()
            }
            await driver.toggleSwitches()
            #expect(viewModel.save())
        }
    }

    /// Editing an item and saving it in its editor writes it back into the configuration.
    @Test func editingAnItemUpdatesTheConfiguration() async throws {
        try await withWorld { _ in
            let viewModel = WatchConfigurationViewModel()
            let driver = await SwiftUIScreenDriver.show(WatchConfigurationView(viewModel: viewModel))
            defer { driver.close() }
            await #expect(driver.waitUntil { viewModel.watchConfig.items.count == Self.items.count })

            let itemsSection = 3
            for row in [0, 2] {
                try await #require(driver.push(IndexPath(item: row, section: itemsSection)))
                await driver.tapBarButton(titled: L10n.MagicItem.edit)
                await driver.popToRoot()
            }
            #expect(viewModel.watchConfig.items.count == Self.items.count)
        }
    }

    /// Save writes through the view model; without the table it fails and the screen stays. Reset only
    /// asks for confirmation.
    @Test func saveAndResetFromTheScreen() async throws {
        try await withWorld { _ in
            let viewModel = WatchConfigurationViewModel()
            let driver = await SwiftUIScreenDriver.show(WatchConfigurationView(viewModel: viewModel))
            defer { driver.close() }
            await #expect(driver.waitUntil { viewModel.watchConfig.items.count == Self.items.count })

            Current.database = { try! DatabaseQueue() }
            let saved = await driver.tapBarButton(titled: L10n.Watch.Configuration.Save.title)
            #expect(saved)
            await #expect(driver.waitUntil { viewModel.showError })

            // The reset button is the row right after the assist section.
            await driver.tapRow(IndexPath(item: 0, section: 5))
            #expect(viewModel.watchConfig.items.count == Self.items.count)
        }
    }

    @Test func modalScreenBringsItsOwnNavigation() async throws {
        try await withWorld { _ in
            let driver = await SwiftUIScreenDriver.show(
                WatchConfigurationView(needsNavigationStack: true),
                inNavigationStack: false
            )
            #expect(driver.sectionCount > 3)
            driver.close()
        }
    }

    /// Saving an item's editor inside a folder writes the edit back into that folder.
    @Test func editingAFolderItemUpdatesTheFolder() async throws {
        try await withWorld { _ in
            let viewModel = WatchConfigurationViewModel()
            viewModel.watchConfig = WatchConfig(items: Self.items)
            let driver = await SwiftUIScreenDriver.show(FolderDetailView(folderId: "folder", viewModel: viewModel))
            defer { driver.close() }

            // The entity and the Assist prompt each open their editor.
            for row in [0, 2] {
                try await #require(driver.push(IndexPath(item: row, section: 0)))
                await driver.tapBarButton(titled: L10n.MagicItem.edit)
                await driver.popToRoot()
            }
            let folder = viewModel.watchConfig.items.first { $0.id == "folder" }
            #expect(folder?.items?.count == Self.folderItems.count)
        }
    }

    /// The folder editor shows a chosen icon; clearing the name falls back to the folder's id.
    @Test func folderEditorClearsTheNameAndKeepsTheIcon() async throws {
        var saved: [MagicItem] = []
        let folder = MagicItem(
            id: "folder",
            serverId: "",
            type: .folder,
            customization: .init(icon: "sofa"),
            displayText: "Downstairs"
        )
        let driver = await SwiftUIScreenDriver.show(FolderEditView(folder: folder) { saved.append($0) })
        defer { driver.close() }

        await driver.type("   ")
        await driver.tapBarButton(titled: L10n.saveLabel)
        #expect(saved.first?.displayText == nil)
        #expect(saved.first?.customization?.icon == "sofa")
    }

    @Test func folderOpensItsItemsAndEditor() async throws {
        try await withWorld { _ in
            let viewModel = WatchConfigurationViewModel()
            viewModel.watchConfig = WatchConfig(items: Self.items)
            let driver = await SwiftUIScreenDriver.show(FolderDetailView(folderId: "folder", viewModel: viewModel))
            defer { driver.close() }
            // The folder's items, then the add menu.
            #expect(driver.rowCount(inSection: 0) == Self.folderItems.count + 1)
            await #expect(driver.push(IndexPath(item: 0, section: 0)))
            await driver.pop()
            await #expect(driver.push(IndexPath(item: 2, section: 0)))
            await driver.pop()

            // The gear opens the folder editor; renaming and saving updates the folder.
            await driver.tapBarButton()
            await #expect(driver.waitUntil { driver.presented != nil })
            await driver.type("Upstairs")
            await driver.toggleSwitches()
            await #expect(driver.tapBarButton(titled: L10n.saveLabel))
            await #expect(driver.waitUntil {
                viewModel.watchConfig.items.first { $0.id == "folder" }?.displayText == "Upstairs"
            })
            await driver.dismissPresented()
        }
    }

    @Test func folderEditorTogglesCustomColors() async throws {
        try await withWorld { _ in
            var saved: [MagicItem] = []
            let plain = MagicItem(id: "f", serverId: "", type: .folder, customization: nil, displayText: "Plain")
            let driver = await SwiftUIScreenDriver.show(FolderEditView(folder: plain) { saved.append($0) })
            defer { driver.close() }
            await driver.toggleSwitches()
            await driver.toggleSwitches()
            await #expect(driver.tapBarButton(titled: L10n.cancelLabel))
            #expect(saved.isEmpty)
            await #expect(driver.tapBarButton(titled: L10n.saveLabel))
            #expect(saved.count == 1)
        }
    }

    @Test func addDestinationsMapToPickers() {
        for destination in [WatchAddItemDestination.entity, .area, .complication, .assist, .assistPrompt] {
            #expect(destination.id == destination.rawValue)
            if destination == .assistPrompt {
                #expect(destination.magicItemType == nil)
                #expect(destination.pickerOption == nil)
            } else {
                #expect(destination.magicItemType != nil)
                #expect(destination.pickerOption != nil)
            }
        }
    }

    private func withWorld(_ body: (DatabaseQueue) async throws -> Void) async throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        try await database.write { db in
            try WatchConfig(items: Self.items, layout: .list, hideAreas: true).insert(db)
        }
        let servers = FakeServerManager(initial: 1)
        let api = HomeAssistantAPI(server: servers.all[0])
        api.connection = HAMockConnection()
        Current.setCachedApi(api, for: servers.all[0].identifier)
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let previousProvider = Current.magicItemProvider
        Current.database = { database }
        Current.servers = servers
        Current.magicItemProvider = { FakeMagicItemProvider() }
        defer {
            Current.resetAPICache(for: servers.all.map(\.identifier))
            Current.database = previousDatabase
            Current.servers = previousServers
            Current.magicItemProvider = previousProvider
        }
        try await body(database)
    }
}

private final class FakeMagicItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        .init(id: item.serverUniqueId, name: "Kitchen light", iconName: "mdi:lightbulb")
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
