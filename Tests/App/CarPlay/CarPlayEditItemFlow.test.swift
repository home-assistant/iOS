import CarPlay
import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The in-car "Edit" list: one row per item of the list or folder it was opened from.
final class CarPlayEditItemFlowTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!
    private var database: DatabaseQueue!
    private var finishCount = 0
    private var displayedItemIds: [String] = []
    private var sut: CarPlayEditItemFlow!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousDatabase = Current.database
        let database = try CarPlayTestHelpers.makeDatabase()
        self.database = database
        Current.database = { database }
        finishCount = 0
        displayedItemIds = []
    }

    override func tearDown() {
        Current.database = previousDatabase
        sut = nil
        database = nil
        super.tearDown()
    }

    private func start(destination: CarPlayAddItemViewModel.Destination = .quickAccess) {
        sut = CarPlayEditItemFlow(
            interfaceController: nil,
            viewModel: CarPlayAddItemViewModel(destination: destination),
            itemDisplay: { [weak self] item in
                self?.displayedItemIds.append(item.id)
                return (title: "Title \(item.id)", subtitle: "Subtitle \(item.id)", image: UIImage())
            },
            onFinish: { [weak self] in self?.finishCount += 1 }
        )
        sut.start()
    }

    private func rows() throws -> [CPListItem] {
        let flow = try XCTUnwrap(sut)
        let template = try XCTUnwrap(CarPlayTestHelpers.listTemplate(named: "template", of: flow))
        return CarPlayTestHelpers.listItems(of: template)
    }

    func testNothingToEditEndsTheFlowRightAway() throws {
        start()

        XCTAssertEqual(finishCount, 1)
        XCTAssertTrue(try rows().isEmpty)
    }

    func testListsTheQuickAccessItems() throws {
        try CarPlayTestHelpers.save(
            CarPlayConfig(quickAccessItems: [
                MagicItem(id: "light.kitchen", serverId: "s", type: .entity),
                MagicItem(id: "script.morning", serverId: "s", type: .script),
                MagicItem(id: "garage", serverId: "", type: .folder, items: []),
            ]),
            in: database
        )

        start()

        XCTAssertEqual(finishCount, 0)
        XCTAssertEqual(displayedItemIds, ["light.kitchen", "script.morning", "garage"])
        XCTAssertEqual(try rows().map(\.text), ["Title light.kitchen", "Title script.morning", "Title garage"])
        XCTAssertEqual(try rows().first?.detailText, "Subtitle light.kitchen")

        // The action sheet needs a CarPlay screen; tapping must not change anything on its own.
        for row in try rows() {
            CarPlayTestHelpers.tap(row)
        }
        XCTAssertEqual(try CarPlayTestHelpers.storedConfig(in: database)?.quickAccessItems.count, 3)
        XCTAssertEqual(finishCount, 0)
    }

    func testListsTheItemsOfTheFolderItWasOpenedFrom() throws {
        let children = [
            MagicItem(id: "cover.garage_door", serverId: "s", type: .entity),
            MagicItem(id: "lock.front_door", serverId: "s", type: .entity),
            MagicItem(id: "climate.hall", serverId: "s", type: .entity),
        ]
        try CarPlayTestHelpers.save(
            CarPlayConfig(quickAccessItems: [MagicItem(id: "garage", serverId: "", type: .folder, items: children)]),
            in: database
        )

        start(destination: .folder(folderId: "garage"))

        XCTAssertEqual(displayedItemIds, ["cover.garage_door", "lock.front_door", "climate.hall"])
        for row in try rows() {
            CarPlayTestHelpers.tap(row)
        }
        XCTAssertEqual(finishCount, 0)
    }
}
