import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

struct WatchConfig_test {
    @Test func validateWatchConfigScheme() async throws {
        let currentFileURL = URL(fileURLWithPath: #file)
        let directoryURL = currentFileURL.deletingLastPathComponent()
        let sqliteFileURL = directoryURL.appendingPathComponent("WatchConfigV1.sqlite")
        let database = try DatabaseQueue(path: sqliteFileURL.path)
        let watchConfig = try await database.read { db in
            try WatchConfig.fetchOne(db)
        }

        #expect(watchConfig?.id == "0CFEB349-EDA9-4F79-A5F9-326495552E27", "Watch config has wrong ID")
        #expect(watchConfig?.assist == WatchConfig.Assist(
            showAssist: true,
            serverId: "c4f59c50552e4aebbbaffd5754aa2e9f",
            pipelineId: "01j4khbxmamfcpqbes3d6zxm5b"
        ), "Watch config has wrong assist config")
        #expect(watchConfig?.items == [
            .init(
                id: "script.new_script_2",
                serverId: "c4f59c50552e4aebbbaffd5754aa2e9f",
                type: .script,
                customization: .init(iconColor: "5F783D", requiresConfirmation: false)
            ),
            .init(
                id: "script.new_script_3",
                serverId: "c4f59c50552e4aebbbaffd5754aa2e9f",
                type: .script,
                customization: .init(
                    iconColor: "000000",
                    textColor: "91B860",
                    backgroundColor: "C4547A",
                    requiresConfirmation: false
                )
            ),
        ], "Watch config has wrong items config")
    }
}

struct WatchConfigurationViewModel_test {
    @Test func addFolderCreatesEmptyFolder() async throws {
        let viewModel = WatchConfigurationViewModel()

        // Initially no items
        #expect(viewModel.watchConfig.items.isEmpty)

        // Add a folder
        viewModel.addFolder(named: "My Folder")

        // Should have one item which is a folder
        #expect(viewModel.watchConfig.items.count == 1)
        let folder = viewModel.watchConfig.items[0]
        #expect(folder.type == .folder)
        #expect(folder.displayText == "My Folder")
        #expect(folder.items?.isEmpty == true)
    }

    @Test func addItemToFolderAddsItemInsideFolder() async throws {
        let viewModel = WatchConfigurationViewModel()

        // Add a folder
        viewModel.addFolder(named: "My Folder")
        let folderId = viewModel.watchConfig.items[0].id

        // Create an item to add to the folder
        let scriptItem = MagicItem(
            id: "script.test_script",
            serverId: "server1",
            type: .script
        )

        // Add item to folder
        viewModel.addItemToFolder(folderId: folderId, item: scriptItem)

        // Root should still have only 1 item (the folder)
        #expect(viewModel.watchConfig.items.count == 1, "Root should have only the folder, not the item")

        // The folder should contain the item
        let folder = viewModel.watchConfig.items[0]
        #expect(folder.items?.count == 1, "Folder should contain the added item")
        #expect(folder.items?.first?.id == "script.test_script", "Folder should contain the correct item")
        #expect(folder.items?.first?.serverId == "server1", "Folder item should have correct serverId")
    }

    @Test func addItemToFolderDoesNotAddToRoot() async throws {
        let viewModel = WatchConfigurationViewModel()

        // Add a folder
        viewModel.addFolder(named: "Test Folder")
        let folderId = viewModel.watchConfig.items[0].id

        // Add multiple items to the folder
        let item1 = MagicItem(id: "script.one", serverId: "s1", type: .script)
        let item2 = MagicItem(id: "scene.two", serverId: "s1", type: .scene)
        let item3 = MagicItem(id: "action.three", serverId: "s1", type: .action)

        viewModel.addItemToFolder(folderId: folderId, item: item1)
        viewModel.addItemToFolder(folderId: folderId, item: item2)
        viewModel.addItemToFolder(folderId: folderId, item: item3)

        // Root should still have only 1 item (the folder)
        #expect(viewModel.watchConfig.items.count == 1, "Root should only contain the folder")

        // Verify none of the items are at root level
        let rootItemIds = viewModel.watchConfig.items.map(\.id)
        #expect(!rootItemIds.contains("script.one"), "script.one should not be at root")
        #expect(!rootItemIds.contains("scene.two"), "scene.two should not be at root")
        #expect(!rootItemIds.contains("action.three"), "action.three should not be at root")

        // The folder should contain all 3 items
        let folder = viewModel.watchConfig.items[0]
        #expect(folder.items?.count == 3, "Folder should contain all 3 items")

        let folderItemIds = folder.items?.map(\.id) ?? []
        #expect(folderItemIds.contains("script.one"), "Folder should contain script.one")
        #expect(folderItemIds.contains("scene.two"), "Folder should contain scene.two")
        #expect(folderItemIds.contains("action.three"), "Folder should contain action.three")
    }

    @Test func addItemToNonExistentFolderDoesNothing() async throws {
        let viewModel = WatchConfigurationViewModel()

        // Add a folder
        viewModel.addFolder(named: "Real Folder")

        // Try to add item to a non-existent folder
        let item = MagicItem(id: "script.test", serverId: "s1", type: .script)
        viewModel.addItemToFolder(folderId: "non-existent-folder-id", item: item)

        // Root should still have only 1 item (the folder)
        #expect(viewModel.watchConfig.items.count == 1)

        // The real folder should be empty
        let folder = viewModel.watchConfig.items[0]
        #expect(folder.items?.isEmpty == true, "Real folder should still be empty")
    }

    @Test func addItemDirectlyGoesToRoot() async throws {
        let viewModel = WatchConfigurationViewModel()

        // Add a folder first
        viewModel.addFolder(named: "My Folder")

        // Add item directly (not to folder)
        let item = MagicItem(id: "script.root_item", serverId: "s1", type: .script)
        viewModel.addItem(item)

        // Root should have 2 items: the folder and the item
        #expect(viewModel.watchConfig.items.count == 2)

        // Verify the item is at root, not in the folder
        let rootItemIds = viewModel.watchConfig.items.map(\.id)
        #expect(rootItemIds.contains("script.root_item"), "Item should be at root")

        // Folder should still be empty
        let folder = viewModel.watchConfig.items.first(where: { $0.type == .folder })
        #expect(folder?.items?.isEmpty == true, "Folder should be empty")
    }

    @Test func deleteItemInFolderRemovesFromFolder() async throws {
        let viewModel = WatchConfigurationViewModel()

        // Add a folder with items
        viewModel.addFolder(named: "My Folder")
        let folderId = viewModel.watchConfig.items[0].id

        let item1 = MagicItem(id: "script.one", serverId: "s1", type: .script)
        let item2 = MagicItem(id: "script.two", serverId: "s1", type: .script)
        viewModel.addItemToFolder(folderId: folderId, item: item1)
        viewModel.addItemToFolder(folderId: folderId, item: item2)

        // Delete first item in folder
        viewModel.deleteItemInFolder(folderId: folderId, at: IndexSet(integer: 0))

        // Folder should have 1 item remaining
        let folder = viewModel.watchConfig.items[0]
        #expect(folder.items?.count == 1)
        #expect(folder.items?.first?.id == "script.two")
    }

    @Test func moveItemWithinFolderReordersItems() async throws {
        let viewModel = WatchConfigurationViewModel()

        // Add a folder with items
        viewModel.addFolder(named: "My Folder")
        let folderId = viewModel.watchConfig.items[0].id

        let item1 = MagicItem(id: "script.one", serverId: "s1", type: .script)
        let item2 = MagicItem(id: "script.two", serverId: "s1", type: .script)
        let item3 = MagicItem(id: "script.three", serverId: "s1", type: .script)
        viewModel.addItemToFolder(folderId: folderId, item: item1)
        viewModel.addItemToFolder(folderId: folderId, item: item2)
        viewModel.addItemToFolder(folderId: folderId, item: item3)

        // Move first item to end
        viewModel.moveItemWithinFolder(folderId: folderId, from: IndexSet(integer: 0), to: 3)

        // Check new order
        let folder = viewModel.watchConfig.items[0]
        let itemIds = folder.items?.map(\.id) ?? []
        #expect(itemIds == ["script.two", "script.three", "script.one"])
    }

    @Test func moveItemToFolderFromRoot() async throws {
        let viewModel = WatchConfigurationViewModel()

        // Add a root item and a folder
        let item = MagicItem(id: "script.moveme", serverId: "s1", type: .script)
        viewModel.addItem(item)
        viewModel.addFolder(named: "Target Folder")
        let folderId = viewModel.watchConfig.items[1].id

        #expect(viewModel.watchConfig.items.count == 2, "Root should have the item and the folder")

        // Move item from root into folder
        viewModel.moveItemToFolder(itemId: "script.moveme", serverId: "s1", toFolderId: folderId)

        // Root should now only have the folder
        #expect(viewModel.watchConfig.items.count == 1, "Root should only have the folder after move")
        #expect(viewModel.watchConfig.items[0].type == .folder)

        // Folder should contain the moved item
        let folder = viewModel.watchConfig.items[0]
        #expect(folder.items?.count == 1, "Folder should contain the moved item")
        #expect(folder.items?.first?.id == "script.moveme")
        #expect(folder.items?.first?.serverId == "s1")
    }

    @Test func moveItemToFolderFromAnotherFolder() async throws {
        let viewModel = WatchConfigurationViewModel()

        // Create two folders
        viewModel.addFolder(named: "Source Folder")
        viewModel.addFolder(named: "Destination Folder")
        let sourceFolderId = viewModel.watchConfig.items[0].id
        let destFolderId = viewModel.watchConfig.items[1].id

        // Add an item to the source folder
        let item = MagicItem(id: "scene.transfer", serverId: "s1", type: .scene)
        viewModel.addItemToFolder(folderId: sourceFolderId, item: item)

        #expect(viewModel.watchConfig.items[0].items?.count == 1, "Source folder should have the item")
        #expect(viewModel.watchConfig.items[1].items?.isEmpty == true, "Destination folder should be empty")

        // Move item from source folder to destination folder
        viewModel.moveItemToFolder(itemId: "scene.transfer", serverId: "s1", toFolderId: destFolderId)

        // Source folder should be empty
        let sourceFolder = viewModel.watchConfig.items.first(where: { $0.id == sourceFolderId })
        #expect(sourceFolder?.items?.isEmpty == true, "Source folder should be empty after move")

        // Destination folder should contain the item
        let destFolder = viewModel.watchConfig.items.first(where: { $0.id == destFolderId })
        #expect(destFolder?.items?.count == 1, "Destination folder should contain the moved item")
        #expect(destFolder?.items?.first?.id == "scene.transfer")

        // Root should still have exactly 2 folders
        #expect(viewModel.watchConfig.items.count == 2, "Root should still have exactly 2 folders")
    }
}
