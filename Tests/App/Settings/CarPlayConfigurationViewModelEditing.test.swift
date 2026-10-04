import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Editing the CarPlay configuration from the iPhone: tabs, Quick Access items, folders, tab-only
/// folders and the layout options, plus persisting the result.
@MainActor
final class CarPlayConfigurationViewModelEditingTests: XCTestCase {
    private func makeEntity(_ id: String) -> MagicItem {
        MagicItem(id: id, serverId: "server1", type: .entity)
    }

    func testStartsFromTheDefaultConfiguration() {
        let viewModel = CarPlayConfigurationViewModel()

        XCTAssertEqual(viewModel.config.tabs, [.quickAccess, .areas, .settings])
        XCTAssertTrue(viewModel.config.quickAccessItems.isEmpty)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testActivatingAndDeactivatingABuiltInTab() {
        let viewModel = CarPlayConfigurationViewModel()

        viewModel.updateTab(.domains, active: true)
        viewModel.updateTab(.domains, active: true)
        XCTAssertEqual(viewModel.config.tabs, [.quickAccess, .areas, .settings, .domains])

        viewModel.updateTab(.areas, active: false)
        XCTAssertEqual(viewModel.config.tabs, [.quickAccess, .settings, .domains])
    }

    func testMovingAndDeletingTabs() {
        let viewModel = CarPlayConfigurationViewModel()

        viewModel.moveTab(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(viewModel.config.tabs, [.areas, .settings, .quickAccess])

        viewModel.deleteTab(at: IndexSet(integer: 1))
        XCTAssertEqual(viewModel.config.tabs, [.areas, .quickAccess])
    }

    func testATabFolderIsDeletedTogetherWithItsTab() throws {
        let viewModel = CarPlayConfigurationViewModel()

        viewModel.addTabFolder(named: "Garage")
        let folder = try XCTUnwrap(viewModel.config.tabFolders?.first)
        XCTAssertEqual(folder.type, .folder)
        XCTAssertEqual(folder.displayText, "Garage")
        XCTAssertEqual(viewModel.config.tabs.last, .folder(folderId: folder.id))
        XCTAssertTrue(viewModel.config.quickAccessItems.isEmpty)
        XCTAssertEqual(viewModel.config.name(for: .folder(folderId: folder.id)), "Garage")

        viewModel.deleteTab(at: IndexSet(integer: viewModel.config.tabs.count - 1))

        XCTAssertEqual(viewModel.config.tabFolders?.isEmpty, true)
        XCTAssertFalse(viewModel.config.tabs.contains(.folder(folderId: folder.id)))
    }

    func testDeactivatingATabFolderAlsoRemovesIt() throws {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addTabFolder(named: "Garage")
        let folder = try XCTUnwrap(viewModel.config.tabFolders?.first)

        viewModel.updateTab(.folder(folderId: folder.id), active: false)

        XCTAssertEqual(viewModel.config.tabFolders?.isEmpty, true)
    }

    func testDeletingAQuickAccessFolderAlsoRemovesTheTabItBacks() throws {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addItem(makeEntity("light.kitchen"))
        viewModel.addFolder(named: "Lights")
        let folder = try XCTUnwrap(viewModel.config.folders.first)
        viewModel.updateTab(.folder(folderId: folder.id), active: true)
        XCTAssertTrue(viewModel.config.tabs.contains(.folder(folderId: folder.id)))

        viewModel.deleteItem(at: IndexSet(integer: 1))

        XCTAssertEqual(viewModel.config.quickAccessItems.map(\.id), ["light.kitchen"])
        XCTAssertFalse(viewModel.config.tabs.contains(.folder(folderId: folder.id)))
    }

    func testDeletingAPlainItemLeavesTheTabsAlone() {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addItem(makeEntity("light.kitchen"))
        viewModel.addItem(makeEntity("light.porch"))

        viewModel.deleteItem(at: IndexSet(integer: 0))

        XCTAssertEqual(viewModel.config.quickAccessItems.map(\.id), ["light.porch"])
        XCTAssertEqual(viewModel.config.tabs, [.quickAccess, .areas, .settings])
    }

    func testMovingAndUpdatingQuickAccessItems() {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addItem(makeEntity("light.kitchen"))
        viewModel.addItem(makeEntity("light.porch"))

        viewModel.moveItem(from: IndexSet(integer: 1), to: 0)
        XCTAssertEqual(viewModel.config.quickAccessItems.map(\.id), ["light.porch", "light.kitchen"])

        var renamed = makeEntity("light.kitchen")
        renamed.displayText = "Kitchen"
        viewModel.updateItem(renamed)
        XCTAssertEqual(viewModel.config.quickAccessItems[1].displayText, "Kitchen")
    }

    func testEditingItemsInsideAFolder() throws {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addFolder(named: "Lights")
        let folderId = try XCTUnwrap(viewModel.config.folders.first?.id)

        viewModel.addItemToFolder(folderId: folderId, item: makeEntity("light.kitchen"))
        viewModel.addItemToFolder(folderId: folderId, item: makeEntity("light.porch"))
        // Folders can't contain other folders.
        viewModel.addItemToFolder(
            folderId: folderId,
            item: MagicItem(id: "nested", serverId: "", type: .folder, items: [])
        )
        XCTAssertEqual(viewModel.config.folder(withId: folderId)?.items?.map(\.id), ["light.kitchen", "light.porch"])

        viewModel.moveItemWithinFolder(folderId: folderId, from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(viewModel.config.folder(withId: folderId)?.items?.map(\.id), ["light.porch", "light.kitchen"])

        viewModel.deleteItemInFolder(folderId: folderId, at: IndexSet(integer: 0))
        XCTAssertEqual(viewModel.config.folder(withId: folderId)?.items?.map(\.id), ["light.kitchen"])
    }

    func testUpdatingAFolderKeepsItsItems() throws {
        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addFolder(named: "Lights")
        var folder = try XCTUnwrap(viewModel.config.folders.first)
        viewModel.addItemToFolder(folderId: folder.id, item: makeEntity("light.kitchen"))

        folder.displayText = "All lights"
        folder.items = []
        viewModel.updateFolder(folder)

        let updated = try XCTUnwrap(viewModel.config.folder(withId: folder.id))
        XCTAssertEqual(updated.displayText, "All lights")
        XCTAssertEqual(updated.items?.map(\.id), ["light.kitchen"])

        // Only folders can be updated as folders.
        viewModel.updateFolder(makeEntity(folder.id))
        XCTAssertEqual(viewModel.config.folder(withId: folder.id)?.displayText, "All lights")
    }

    func testLayoutFollowsTheItemsUntilChosen() {
        let viewModel = CarPlayConfigurationViewModel()
        XCTAssertEqual(viewModel.quickAccessLayout, .grid)

        viewModel.addItem(makeEntity("light.kitchen"))
        XCTAssertEqual(viewModel.quickAccessLayout, .list)

        viewModel.quickAccessLayout = .grid
        XCTAssertEqual(viewModel.quickAccessLayout, .grid)
        XCTAssertEqual(viewModel.config.quickAccessLayout, .grid)
    }

    func testAddEditButtonsAreShownUntilTurnedOff() {
        let viewModel = CarPlayConfigurationViewModel()
        XCTAssertTrue(viewModel.showAddEditButtons)

        viewModel.showAddEditButtons = false

        XCTAssertFalse(viewModel.showAddEditButtons)
        XCTAssertEqual(viewModel.config.showAddEditButtons, false)
    }

    func testSavingAndDeletingTheConfiguration() throws {
        let database = try DatabaseQueue()
        try CarPlayConfigTable().createIfNeeded(database: database)
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }

        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addItem(makeEntity("light.kitchen"))
        viewModel.updateTab(.domains, active: true)

        XCTAssertTrue(viewModel.save())
        let saved = try database.read { db in try CarPlayConfig.fetchOne(db) }
        XCTAssertEqual(saved?.quickAccessItems.map(\.id), ["light.kitchen"])
        XCTAssertEqual(saved?.tabs, [.quickAccess, .areas, .settings, .domains])

        var deleted: Bool?
        viewModel.deleteConfiguration { deleted = $0 }

        XCTAssertEqual(deleted, true)
        let remaining = try database.read { db in try CarPlayConfig.fetchCount(db) }
        XCTAssertEqual(remaining, 0)
    }
}
