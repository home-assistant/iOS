@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// Renders a CarPlay folder's item list with each row kind, and a folder id that no longer exists.
@MainActor
struct CarPlayFolderDetailViewTests {
    @Test func rendersEveryRowKind() throws {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addFolder(named: "Garage")
        let folderId = try #require(viewModel.config.quickAccessItems.first?.id)
        viewModel.addItemToFolder(folderId: folderId, item: MagicItem(id: "light.a", serverId: "s", type: .entity))
        viewModel.addItemToFolder(folderId: folderId, item: MagicItem(
            id: "prompt", serverId: "s", type: .assistPrompt, displayText: "Lights",
            assistPrompt: "Turn on the lights", assistPipelineId: ""
        ))

        let host = CarPlaySwiftUIHost(NavigationStack {
            CarPlayFolderDetailView(folderId: folderId, viewModel: viewModel)
        })
        defer { host.close() }

        #expect(viewModel.config.folder(withId: folderId)?.items?.count == 2)
    }

    @Test func aMissingFolderRendersEmpty() {
        let viewModel = CarPlayConfigurationViewModel()
        let host = CarPlaySwiftUIHost(NavigationStack {
            CarPlayFolderDetailView(folderId: "gone", viewModel: viewModel)
        })
        defer { host.close() }

        #expect(viewModel.config.folder(withId: "gone") == nil)
    }
}
