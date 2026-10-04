@testable import HomeAssistant
@testable import Shared
import SwiftUI
import UIKit
import XCTest

/// Lays the CarPlay settings screens out so SwiftUI evaluates their bodies: the tab picker with
/// built-in, folder and tab-only tabs, a folder's items and the troubleshooting options.
@MainActor
final class CarPlaySettingsScreensRenderTests: XCTestCase {
    /// Deliberately never becomes the key window: the snapshot helpers draw into whatever window is
    /// key, so stealing it here would reach into unrelated tests.
    private func render(_ view: some View, height: CGFloat = 1400) {
        let controller = UIHostingController(rootView: view.injectingViewControllerProvider())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: height))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        XCTAssertNotNil(controller.view)

        window.isHidden = true
        window.rootViewController = nil
    }

    /// A configuration with a Quick Access folder holding two items, that folder promoted to a tab,
    /// a second folder left in Quick Access and a tab-only folder.
    private func makeViewModel() throws -> (CarPlayConfigurationViewModel, folderId: String) {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addItem(MagicItem(id: "light.kitchen", serverId: "server1", type: .entity))
        viewModel.addFolder(named: "Lights")
        viewModel.addFolder(named: "Scenes")
        let folderId = try XCTUnwrap(viewModel.config.folders.first?.id)
        viewModel.addItemToFolder(
            folderId: folderId,
            item: MagicItem(id: "light.porch", serverId: "server1", type: .entity, displayText: "Porch")
        )
        viewModel.addItemToFolder(
            folderId: folderId,
            item: MagicItem(
                id: "prompt",
                serverId: "server1",
                type: .assistPrompt,
                displayText: "Lights off",
                assistPrompt: "Turn off the lights",
                assistPipelineId: ""
            )
        )
        viewModel.updateTab(.folder(folderId: folderId), active: true)
        viewModel.addTabFolder(named: "Garage")
        return (viewModel, folderId)
    }

    func testRendersTheTabsSelection() throws {
        let (viewModel, folderId) = try makeViewModel()
        XCTAssertTrue(viewModel.config.tabs.contains(.folder(folderId: folderId)))

        render(NavigationStack { CarPlayTabsSelectionView(viewModel: viewModel) })
    }

    func testRendersTheTabsSelectionWithEveryBuiltInTabActive() {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.updateTab(.domains, active: true)
        XCTAssertEqual(viewModel.config.tabs.count, CarPlayTab.allCases.count)

        render(NavigationStack { CarPlayTabsSelectionView(viewModel: viewModel) })
    }

    func testRendersAFoldersItems() throws {
        let (viewModel, folderId) = try makeViewModel()
        XCTAssertEqual(viewModel.config.folder(withId: folderId)?.items?.count, 2)

        render(NavigationStack { CarPlayFolderDetailView(folderId: folderId, viewModel: viewModel) })
    }

    func testRendersAMissingFolder() {
        let viewModel = CarPlayConfigurationViewModel()

        render(NavigationStack { CarPlayFolderDetailView(folderId: "missing", viewModel: viewModel) })
    }

    func testRendersTheTroubleshootingSettings() {
        render(NavigationStack { CarPlayTroubleshootingSettingsView() })
    }

    func testAddItemDestinationsMapToPickerOptions() {
        XCTAssertEqual(CarPlayAddItemDestination.entity.magicItemType, .entities)
        XCTAssertEqual(CarPlayAddItemDestination.assist.magicItemType, .assistPipelines)
        XCTAssertNil(CarPlayAddItemDestination.assistPrompt.magicItemType)
        XCTAssertEqual(CarPlayAddItemDestination.entity.pickerOption, .entities)
        XCTAssertEqual(CarPlayAddItemDestination.assist.pickerOption, .assistPipelines)
        XCTAssertNil(CarPlayAddItemDestination.assistPrompt.pickerOption)
        XCTAssertEqual(CarPlayAddItemDestination.assistPrompt.id, "assistPrompt")
    }
}
