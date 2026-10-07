@testable import HomeAssistant
@testable import Shared
import Testing

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
}
