import CarPlay
import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Covers what tapping a Quick Access row does once a request is in flight: the action is
/// dispatched, a repeat tap is ignored while it is outstanding, and every outcome settles the row.
final class CarPlayQuickAccessTemplateTests: XCTestCase {
    private final class ConfirmationRequiredMagicItemProvider: MagicItemProviderProtocol {
        func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
            completion([:])
        }

        func loadInformation() async -> [String: [HAAppEntity]] {
            [:]
        }

        func getInfo(for item: MagicItem) -> MagicItem.Info? {
            .init(
                id: item.serverUniqueId,
                name: "Garage door",
                iconName: "mdi:garage",
                customization: .init(requiresConfirmation: true)
            )
        }

        func getAreaName(for item: MagicItem) -> String? {
            nil
        }
    }

    /// Names every item after its id and colors it as configured, so rows can be found by text.
    private final class NamingMagicItemProvider: MagicItemProviderProtocol {
        var customization: MagicItem.Customization?

        func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
            completion([:])
        }

        func loadInformation() async -> [String: [HAAppEntity]] {
            [:]
        }

        func getInfo(for item: MagicItem) -> MagicItem.Info? {
            .init(id: item.serverUniqueId, name: item.id, iconName: "mdi:star", customization: customization)
        }

        func getAreaName(for item: MagicItem) -> String? {
            nil
        }
    }

    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousMagicItemProvider: (() -> MagicItemProviderProtocol)!
    private var database: DatabaseQueue!
    private var server: Server!
    private var connection: HAMockConnection!
    private var navigator: FakeCarPlayNavigator!
    private var sut: CarPlayQuickAccessTemplate!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        previousMagicItemProvider = Current.magicItemProvider
        let database = try CarPlayTestDatabase.make()
        self.database = database
        Current.database = { database }
        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()
        navigator = FakeCarPlayNavigator()
        sut = CarPlayQuickAccessTemplate(viewModel: CarPlayQuickAccessViewModel())
        sut.navigatorOverride = navigator
    }

    override func tearDown() {
        connection?.pendingRequests.removeAll()
        connection?.pendingSubscriptions.removeAll()
        Current.cachedApis = [:]
        Current.servers = previousServers
        Current.database = previousDatabase
        Current.magicItemProvider = previousMagicItemProvider
        sut = nil
        navigator = nil
        connection = nil
        server = nil
        database = nil
        previousServers = nil
        previousDatabase = nil
        previousMagicItemProvider = nil
        super.tearDown()
    }

    private func connectAPI() {
        let api = HomeAssistantAPI(server: server)
        let mock = HAMockConnection()
        api.connection = mock
        Current.cachedApis[server.identifier] = api
        connection = mock
    }

    /// `CarPlayPaginatedListTemplate` applies its rows asynchronously, so the sections are only
    /// readable once the main queue has turned over.
    private func drainMainQueue(cycles: Int = 3) {
        let drained = expectation(description: "main queue drained")

        func schedule(_ remaining: Int) {
            DispatchQueue.main.async {
                if remaining == 0 {
                    drained.fulfill()
                } else {
                    schedule(remaining - 1)
                }
            }
        }

        schedule(cycles)
        wait(for: [drained], timeout: 30)
    }

    private func item(id: String, type: MagicItem.ItemType) -> MagicItem {
        MagicItem(id: id, serverId: server.identifier.rawValue, type: type)
    }

    /// Renders the given items as a list (rather than the iOS 26 grid) and returns the rows, whose
    /// handlers are what a tap in the car runs.
    private func rows(for items: [MagicItem]) -> [CPListItem] {
        sut.updateList(for: items, layout: .list, showAddEditButtons: false)
        drainMainQueue()
        return sut.template.sections.flatMap(\.items).compactMap { $0 as? CPListItem }
    }

    private func tap(_ row: CPListItem) {
        row.handler?(row, {})
    }

    /// Gives the template a live state for an entity. Locks need one: an unrecognised state sends
    /// nothing, and an unseeded row resolves to a placeholder whose state is empty.
    private func seedState(entityId: String, state: String) throws {
        let entity = try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: "", parentId: "")
        )
        sut.entitiesStateChange(
            serverId: server.identifier.rawValue,
            entities: HACachedStates(entitiesDictionary: [entityId: entity])
        )
    }

    func testTappingAnEntityRowDispatchesItsAction() throws {
        connectAPI()
        let rendered = rows(for: [item(id: "light.kitchen", type: .entity)])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    /// The row sits on "Executing…" while the call is outstanding, and on a slow connection that is
    /// long enough to invite a second tap — which must not run the action twice.
    func testASecondTapWhileTheFirstIsInFlightIsIgnored() throws {
        connectAPI()
        let rendered = rows(for: [item(id: "light.kitchen", type: .entity)])
        let row = try XCTUnwrap(rendered.first)

        tap(row)
        drainMainQueue()
        tap(row)
        drainMainQueue()

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testATapThatSucceedsSettlesTheRow() throws {
        connectAPI()
        let rendered = rows(for: [item(id: "light.kitchen", type: .entity)])
        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.success(.empty))
        drainMainQueue()

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testATapTheServerRejectsSettlesTheRow() throws {
        connectAPI()
        let rendered = rows(for: [item(id: "light.kitchen", type: .entity)])
        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.failure(.internal(debugDescription: "nope")))
        drainMainQueue()

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testTappingAnOpenCoverRowClosesIt() throws {
        connectAPI()
        try seedState(entityId: "cover.garage_door", state: "open")
        let rendered = rows(for: [item(id: "cover.garage_door", type: .entity)])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        let request = try XCTUnwrap(connection.pendingRequests.first)
        XCTAssertEqual(request.request.data["service"] as? String, "close_cover")
    }

    func testTappingAClosedCoverRowOpensIt() throws {
        connectAPI()
        try seedState(entityId: "cover.garage_door", state: "closed")
        let rendered = rows(for: [item(id: "cover.garage_door", type: .entity)])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        let request = try XCTUnwrap(connection.pendingRequests.first)
        XCTAssertEqual(request.request.data["service"] as? String, "open_cover")
    }

    func testARowThatRequiresConfirmationActsOnTheStateWhenConfirmed() throws {
        let previousProvider = Current.magicItemProvider
        defer { Current.magicItemProvider = previousProvider }
        Current.magicItemProvider = { ConfirmationRequiredMagicItemProvider() }
        sut = CarPlayQuickAccessTemplate(viewModel: CarPlayQuickAccessViewModel())
        connectAPI()
        let presenter = FakeCarPlayAlertPresenter()
        sut.alertPresenterOverride = presenter
        try seedState(entityId: "cover.garage_door", state: "open")
        let rendered = rows(for: [item(id: "cover.garage_door", type: .entity)])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()
        XCTAssertTrue(connection.pendingRequests.isEmpty)

        try seedState(entityId: "cover.garage_door", state: "closed")
        let alert = try XCTUnwrap(presenter.presentedTemplates.first as? CPAlertTemplate)
        let confirm = try XCTUnwrap(alert.actions.last)
        confirm.handler(confirm)
        drainMainQueue()

        let request = try XCTUnwrap(connection.pendingRequests.first)
        XCTAssertEqual(request.request.data["service"] as? String, "open_cover")
    }

    func testTappingAScriptRowDispatchesItsAction() throws {
        connectAPI()
        let rendered = rows(for: [item(id: "script.good_morning", type: .script)])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        XCTAssertFalse(rendered.isEmpty)
    }

    /// A Quick Access item can outlive the server it points at; tapping it must fail visibly rather
    /// than silently do nothing.
    func testTappingAnItemWhoseServerIsGoneDoesNotDispatchAnything() throws {
        connectAPI()
        let orphan = MagicItem(id: "light.kitchen", serverId: "gone", type: .entity)
        let rendered = rows(for: [orphan])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// Locks always confirm first: the action must not reach the server until the driver taps
    /// through the confirmation.
    func testALockRowRunsItsActionOnlyOnceConfirmed() throws {
        connectAPI()
        let presenter = FakeCarPlayAlertPresenter()
        sut.alertPresenterOverride = presenter
        try seedState(entityId: "lock.front_door", state: "locked")
        let rendered = rows(for: [item(id: "lock.front_door", type: .entity)])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()
        XCTAssertTrue(connection.pendingRequests.isEmpty)

        let alert = try XCTUnwrap(presenter.presentedTemplates.first as? CPAlertTemplate)
        let confirm = try XCTUnwrap(alert.actions.last)
        confirm.handler(confirm)
        drainMainQueue()

        XCTAssertEqual(connection.pendingRequests.count, 1)
        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.success(.empty))
        drainMainQueue()
    }

    /// A lock whose server is gone can't run, and the driver has to be told rather than left with a
    /// row that quietly did nothing.
    func testALockRowWhoseServerIsGoneRunsNothing() throws {
        connectAPI()
        let presenter = FakeCarPlayAlertPresenter()
        sut.alertPresenterOverride = presenter
        let orphan = MagicItem(id: "lock.front_door", serverId: "gone", type: .entity)
        let rendered = rows(for: [orphan])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()
        let alert = try XCTUnwrap(presenter.presentedTemplates.first as? CPAlertTemplate)
        let confirm = try XCTUnwrap(alert.actions.last)
        confirm.handler(confirm)
        drainMainQueue()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// A lock on a server the app can't reach: same, but the reason is the connection.
    func testALockRowWithoutAReachableServerRunsNothing() throws {
        connectAPI()
        let unreachable = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
        let servers = try XCTUnwrap(Current.servers as? FakeServerManager)
        servers.add(identifier: unreachable.identifier, serverInfo: unreachable.info)
        let presenter = FakeCarPlayAlertPresenter()
        sut.alertPresenterOverride = presenter
        let item = MagicItem(
            id: "lock.front_door",
            serverId: unreachable.identifier.rawValue,
            type: .entity
        )
        let rendered = rows(for: [item])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()
        let alert = try XCTUnwrap(presenter.presentedTemplates.first as? CPAlertTemplate)
        let confirm = try XCTUnwrap(alert.actions.last)
        confirm.handler(confirm)
        drainMainQueue()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    func testCancellingALockConfirmationRunsNothing() throws {
        connectAPI()
        let presenter = FakeCarPlayAlertPresenter()
        sut.alertPresenterOverride = presenter
        let rendered = rows(for: [item(id: "lock.front_door", type: .entity)])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        let alert = try XCTUnwrap(presenter.presentedTemplates.first as? CPAlertTemplate)
        let cancel = try XCTUnwrap(alert.actions.first)
        cancel.handler(cancel)
        drainMainQueue()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// Climate rows open a control screen instead of executing, and a missing server leaves nothing
    /// to open.
    func testTappingAClimateRowWhoseServerIsGoneOpensNothing() throws {
        connectAPI()
        let orphan = MagicItem(id: "climate.hall", serverId: "gone", type: .entity)
        let rendered = rows(for: [orphan])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    // MARK: - Empty states, layouts and folders

    private var serverId: String { server.identifier.rawValue }

    private func makeSut(
        source: CarPlayQuickAccessViewModel.Source = .quickAccess,
        folder: MagicItem? = nil,
        customization: MagicItem.Customization? = nil
    ) {
        let provider = NamingMagicItemProvider()
        provider.customization = customization
        Current.magicItemProvider = { provider }
        sut = CarPlayQuickAccessTemplate(viewModel: CarPlayQuickAccessViewModel(source: source), folder: folder)
        sut.navigatorOverride = navigator
        sut.alertPresenterOverride = navigator
    }

    private func listRows() -> [CPListItem] {
        CarPlayTestRows.listItems(sut.template)
    }

    @available(iOS 26.0, *)
    private func imageRows() -> [CPListImageRowItem] {
        sut.template.sections.flatMap(\.items).compactMap { $0 as? CPListImageRowItem }
    }

    private func save(_ config: CarPlayConfig) throws {
        try database.write { db in try config.insert(db, onConflict: .replace) }
    }

    /// Spins the main run loop until `condition` holds, failing (not hanging) after 10 seconds.
    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(condition(), "condition not met within 10 s", file: file, line: line)
    }

    func testAFolderTabTakesItsNameAndIconFromTheFolder() {
        let named = MagicItem(
            id: "f1",
            serverId: serverId,
            type: .folder,
            customization: .init(icon: "mdi:car"),
            displayText: "Car"
        )
        makeSut(source: .folder(folderId: "f1"), folder: named)
        XCTAssertEqual(sut.template.tabTitle, "Car")

        let unnamed = MagicItem(id: "f2", serverId: serverId, type: .folder, customization: nil)
        makeSut(source: .folder(folderId: "f2"), folder: unnamed)
        XCTAssertEqual(sut.template.tabTitle, L10n.Watch.Configuration.Folder.defaultName)
    }

    func testAnEmptyFolderTabOffersToAddIntoTheFolderOrExplains() throws {
        makeSut(source: .folder(folderId: "f1"))
        sut.updateList(for: [], layout: .list, showAddEditButtons: true)
        XCTAssertEqual(listRows().map(\.text), [L10n.CarPlay.QuickAccess.AddItem.button])

        CarPlayTestRows.tap(listRows().first)
        let flowTemplate = try XCTUnwrap(navigator.pushedTemplates.last as? CPListTemplate)
        XCTAssertFalse(CarPlayTestRows.texts(flowTemplate).contains(L10n.Watch.Configuration.Folder.defaultName))

        sut.updateList(for: [], layout: .list, showAddEditButtons: false)
        XCTAssertEqual(listRows().map(\.text), [L10n.CarPlay.Folder.Empty.title])
    }

    func testTheEmptyQuickAccessListOffersToAddOrExplainsWhyNot() throws {
        sut.updateList(for: [], layout: .list, showAddEditButtons: true)
        XCTAssertEqual(listRows().map(\.text), [L10n.CarPlay.QuickAccess.AddItem.button])

        sut.updateList(for: [], layout: .list, showAddEditButtons: false)
        XCTAssertEqual(listRows().map(\.text), [L10n.CarPlay.QuickAccess.Empty.title])

        guard #available(iOS 26.0, *) else { return }
        sut.updateList(for: [], layout: .grid, showAddEditButtons: true)
        drainMainQueue()
        let addTile = try XCTUnwrap(imageRows().first)
        XCTAssertEqual(addTile.elements.count, 1)
        CarPlayTestRows.tapImageRow(addTile, index: 7)
        XCTAssertTrue(navigator.pushedTemplates.isEmpty, "a tap outside the row's tiles does nothing")
        CarPlayTestRows.tapImageRow(addTile, index: 0)
        XCTAssertEqual(navigator.pushedTemplates.count, 1)
    }

    /// The list layout ends with Add and Edit rows; Edit lists the configured items with the
    /// same names and context the Quick Access rows show.
    func testListFooterRowsOpenTheAddAndEditFlows() throws {
        let items = [
            item(id: "light.kitchen", type: .entity),
            item(id: "script.morning", type: .script),
            item(id: "invalid", type: .entity),
        ]
        try save(CarPlayConfig(quickAccessItems: items))
        try database.write { db in
            try AppArea(
                id: "kitchen", serverId: self.serverId, areaId: "kitchen", name: "Kitchen", aliases: [],
                picture: nil, icon: nil, sortOrder: nil, entities: ["light.kitchen"]
            ).insert(db)
        }
        makeSut()
        let rendered = rows(for: items).map { $0.text ?? "" }
        sut.updateList(for: items, layout: .list, showAddEditButtons: true)
        drainMainQueue()
        let footer = listRows().suffix(2)
        XCTAssertEqual(
            footer.map(\.text),
            [L10n.CarPlay.QuickAccess.AddItem.button, L10n.CarPlay.QuickAccess.EditItem.button]
        )
        XCTAssertTrue(rendered.contains(""), "an entity id that can't be parsed renders as a blank row")

        CarPlayTestRows.tap(footer.first)
        XCTAssertEqual(navigator.pushedTemplates.count, 1)
        drainMainQueue()

        CarPlayTestRows.tap(footer.last)
        let editTemplate = try XCTUnwrap(navigator.pushedTemplates.last as? CPListTemplate)
        let editRows = CarPlayTestRows.listItems(editTemplate)
        XCTAssertEqual(editRows.map(\.text), ["light.kitchen", "script.morning", "invalid"])
        XCTAssertEqual(editRows[0].detailText, "Kitchen")
        XCTAssertEqual(editRows[1].detailText, server.info.name)
        drainMainQueue()
    }

    func testGridTilesRunTheirItemsAndFooterTilesOpenTheFlows() throws {
        guard #available(iOS 26.0, *) else { return }
        connectAPI()
        let folder = MagicItem(
            id: "folder",
            serverId: serverId,
            type: .folder,
            items: [item(id: "light.inside", type: .entity)]
        )
        let items = [item(id: "light.kitchen", type: .entity), folder, item(id: "climate.hall", type: .entity)]
        try save(CarPlayConfig(quickAccessItems: items))
        makeSut()
        sut.updateList(for: items, layout: .grid, showAddEditButtons: true)
        drainMainQueue()

        let tiles = imageRows()
        XCTAssertEqual(tiles.count, 2, "a row of item tiles, then the Add/Edit tiles")
        let itemTiles = try XCTUnwrap(tiles.first)
        XCTAssertEqual(
            itemTiles.elements.map { ($0 as? CPListImageRowItemCondensedElement)?.accessorySymbolName },
            [nil, "chevron.forward", "chevron.forward"]
        )

        CarPlayTestRows.tapImageRow(itemTiles, index: 0)
        drainMainQueue()
        XCTAssertEqual(connection.pendingRequests.count, 1)

        CarPlayTestRows.tapImageRow(itemTiles, index: 1)
        let folderList = try XCTUnwrap(navigator.pushedTemplates.last as? CPListTemplate)
        XCTAssertEqual(CarPlayTestRows.texts(folderList).first, "light.inside")

        let footerTiles = try XCTUnwrap(tiles.last)
        CarPlayTestRows.tapImageRow(footerTiles, index: 0)
        CarPlayTestRows.tapImageRow(footerTiles, index: 1)
        XCTAssertEqual(navigator.pushedTemplates.count, 3)
        drainMainQueue()
    }

    func testFolderRowsOpenTheirContentsAndStayCurrent() throws {
        connectAPI()
        let nested = MagicItem(id: "nested", serverId: serverId, type: .folder)
        let folder = MagicItem(
            id: "folder",
            serverId: serverId,
            type: .folder,
            items: [item(id: "light.inside", type: .entity), nested, item(id: "script.go", type: .script)]
        )
        let emptyFolder = MagicItem(id: "empty", serverId: serverId, type: .folder, items: [])
        makeSut()
        sut.updateList(for: [folder, emptyFolder], layout: .list, showAddEditButtons: true)
        drainMainQueue()

        CarPlayTestRows.tap(CarPlayTestRows.row(sut.template, "folder"))
        let folderList = try XCTUnwrap(navigator.pushedTemplates.last as? CPListTemplate)
        XCTAssertEqual(CarPlayTestRows.texts(folderList), [
            "light.inside",
            "script.go",
            L10n.CarPlay.QuickAccess.AddItem.button,
            L10n.CarPlay.QuickAccess.EditItem.button,
        ])

        CarPlayTestRows.tap(CarPlayTestRows.row(sut.template, "empty"))
        let emptyList = try XCTUnwrap(navigator.pushedTemplates.last as? CPListTemplate)
        XCTAssertEqual(CarPlayTestRows.texts(emptyList), [L10n.CarPlay.QuickAccess.AddItem.button])

        // A state change for an entity inside the folder refreshes the open folder list in place.
        let rowBefore = CarPlayTestRows.listItems(folderList).first
        try seedState(entityId: "light.inside", state: "on")
        try seedState(entityId: "light.inside", state: "off")
        drainMainQueue()
        XCTAssertTrue(CarPlayTestRows.listItems(folderList).first === rowBefore)

        // Hiding the add/edit affordances drops them from open folder lists too.
        sut.updateList(for: [folder, emptyFolder], layout: .list, showAddEditButtons: false)
        drainMainQueue()
        XCTAssertEqual(CarPlayTestRows.texts(folderList), ["light.inside", "script.go"])
        XCTAssertEqual(CarPlayTestRows.texts(emptyList), [L10n.CarPlay.Folder.Empty.title])

        // Coming back to the list closes the folders and reloads from the saved configuration.
        try save(CarPlayConfig(quickAccessItems: [], quickAccessLayout: .list))
        sut.templateWillAppear(template: sut.template)
        drainMainQueue()
        XCTAssertEqual(listRows().map(\.text), [L10n.CarPlay.QuickAccess.AddItem.button])
    }

    func testAFolderListLongerThanCarPlayAllowsIsTruncated() throws {
        let children = (0 ... Int(CPListTemplate.maximumItemCount)).map { item(id: "script.s\($0)", type: .script) }
        let folder = MagicItem(id: "folder", serverId: serverId, type: .folder, items: children)
        makeSut()
        sut.updateList(for: [folder], layout: .list, showAddEditButtons: false)
        drainMainQueue()

        CarPlayTestRows.tap(CarPlayTestRows.row(sut.template, "folder"))
        let folderList = try XCTUnwrap(navigator.pushedTemplates.last as? CPListTemplate)
        XCTAssertEqual(CarPlayTestRows.listItems(folderList).count, Int(CPListTemplate.maximumItemCount))
    }

    func testAnUnchangedStateDoesNotRefreshTheList() throws {
        let entity = try HAEntity(
            entityId: "light.kitchen",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: "", parentId: "")
        )
        let states = HACachedStates(entitiesDictionary: ["light.kitchen": entity])
        sut.updateList(for: [item(id: "light.kitchen", type: .entity)], layout: .list, showAddEditButtons: false)
        sut.entitiesStateChange(serverId: serverId, entities: states)
        drainMainQueue()
        let row = listRows().first

        sut.entitiesStateChange(serverId: serverId, entities: states)
        sut.entitiesStateChange(serverId: "other", entities: states)
        drainMainQueue()
        XCTAssertTrue(listRows().first === row)

        // A server with no entity items in the list never refreshes it either.
        sut.entitiesStateChange(serverId: "other", entities: HACachedStates(entitiesDictionary: [:]))
        // A snapshot that drops the entity keeps rendering its last known state.
        sut.entitiesStateChange(serverId: serverId, entities: HACachedStates(entitiesDictionary: [:]))
        drainMainQueue()
        XCTAssertEqual(listRows().count, 1)
    }

    func testTheExecutingSubtitleClearsAfterItsMinimumDuration() throws {
        connectAPI()
        let rendered = rows(for: [item(id: "light.kitchen", type: .entity)])
        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()
        XCTAssertEqual(listRows().first?.detailText, CarPlayEntityListItem.executingSubtitle)

        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.success(.empty))
        waitUntil { listRows().first?.detailText != CarPlayEntityListItem.executingSubtitle }
    }

    func testAssistRowsDescribeTheirPromptOrPipeline() throws {
        let prompt = MagicItem(
            id: "prompt", serverId: serverId, type: .assistPrompt, displayText: "Lights",
            assistPrompt: " Turn on the lights ", assistPipelineId: ""
        )
        let blankPrompt = MagicItem(
            id: "blank", serverId: serverId, type: .assistPrompt, assistPrompt: "  ", assistPipelineId: ""
        )
        let pipeline = MagicItem(id: "pipeline", serverId: serverId, type: .assistPipeline)
        makeSut(customization: .init(iconColor: "#FF0000", iconColorIsCustomized: true))
        let rendered = rows(for: [prompt, blankPrompt, pipeline])

        XCTAssertEqual(rendered.map(\.detailText), ["Turn on the lights", nil, L10n.Widgets.Action.Name.assist])
    }

    /// Tapping an Assist row whose server is gone starts no session.
    func testAnAssistRowWhoseServerIsGoneStartsNothing() throws {
        let orphan = MagicItem(id: "pipeline", serverId: "gone", type: .assistPipeline)
        let rendered = rows(for: [orphan])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        XCTAssertTrue(navigator.pushedTemplates.isEmpty)
    }

    func testAClimateRowOpensItsControlScreenAndForwardsEvents() throws {
        try seedState(entityId: "climate.hall", state: "heat")
        let rendered = rows(for: [item(id: "climate.hall", type: .entity)])
        XCTAssertEqual(rendered.first?.accessoryType, .disclosureIndicator)

        try tap(XCTUnwrap(rendered.first))
        let controlScreen = try XCTUnwrap(navigator.pushedTemplates.last as? CPListTemplate)

        try seedState(entityId: "climate.hall", state: "cool")
        sut.templateWillDisappear(template: controlScreen)
        sut.templateWillAppear(template: controlScreen)
        sut.templateWillAppear(template: sut.template)
        drainMainQueue()
        XCTAssertEqual(navigator.pushedTemplates.count, 1)
    }

    /// A climate item whose entity id can't be parsed has nothing to control; the driver is told.
    func testAClimateRowWithoutAnEntityTellsTheDriver() throws {
        sut.alertPresenterOverride = navigator
        let rendered = rows(for: [item(id: "climate", type: .entity)])

        try tap(XCTUnwrap(rendered.first))
        drainMainQueue()

        XCTAssertTrue(navigator.pushedTemplates.isEmpty)
        XCTAssertEqual(navigator.presentedTemplates.count, 1)
    }

    func testCancellingARunConfirmationRunsNothing() throws {
        Current.magicItemProvider = { ConfirmationRequiredMagicItemProvider() }
        sut = CarPlayQuickAccessTemplate(viewModel: CarPlayQuickAccessViewModel())
        connectAPI()
        let presenter = FakeCarPlayAlertPresenter()
        sut.alertPresenterOverride = presenter
        let rendered = rows(for: [item(id: "switch.fan", type: .entity)])

        try tap(XCTUnwrap(rendered.first))
        let alert = try XCTUnwrap(presenter.presentedTemplates.first as? CPAlertTemplate)
        let cancel = try XCTUnwrap(alert.actions.first)
        cancel.handler(cancel)
        drainMainQueue()

        XCTAssertEqual(presenter.dismissCount, 1)
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    func testALockTheServerRejectsTellsTheDriver() throws {
        connectAPI()
        sut.alertPresenterOverride = navigator
        try seedState(entityId: "lock.front_door", state: "locked")
        let rendered = rows(for: [item(id: "lock.front_door", type: .entity)])

        try tap(XCTUnwrap(rendered.first))
        let alert = try XCTUnwrap(navigator.presentedTemplates.first as? CPAlertTemplate)
        let confirm = try XCTUnwrap(alert.actions.last)
        confirm.handler(confirm)
        drainMainQueue()
        let request = try XCTUnwrap(connection.pendingRequests.first)
        request.completion(.failure(.internal(debugDescription: "nope")))
        drainMainQueue()

        XCTAssertEqual(navigator.presentedTemplates.count, 2, "the failure alert follows the confirmation")
    }

    /// Area names come from the database; when it can't be read the rows still render.
    func testRowsRenderWhenAreasCannotBeRead() throws {
        let broken = try CarPlayTestDatabase.broken()
        Current.database = { broken }
        let rendered = rows(for: [item(id: "light.kitchen", type: .entity)])

        XCTAssertEqual(rendered.count, 1)
    }

    /// Rows can outlive the template (CarPlay holds them); a tap after that does nothing.
    func testRowsOfAReleasedTemplateDoNothing() throws {
        connectAPI()
        let rendered = rows(for: [
            item(id: "light.kitchen", type: .entity),
            item(id: "script.go", type: .script),
        ])
        sut = nil

        var completions = 0
        for row in rendered {
            row.handler?(row) { completions += 1 }
        }

        XCTAssertEqual(completions, 2)
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    func testTheBuildersMakeTheQuickAccessAndFolderTabs() {
        let quickAccess = CarPlayQuickAccessTemplate.build()
        XCTAssertEqual(quickAccess.template.tabTitle, L10n.CarPlay.Navigation.Tab.quickAccess)

        let folder = MagicItem(id: "f", serverId: serverId, type: .folder, displayText: "Errands")
        XCTAssertEqual(CarPlayQuickAccessTemplate.buildFolderTab(folder: folder).template.tabTitle, "Errands")
    }

    /// Grid tiles (item and Add/Edit) of a released template do nothing either.
    func testTilesOfAReleasedTemplateDoNothing() throws {
        guard #available(iOS 26.0, *) else { return }
        connectAPI()
        sut.updateList(for: [item(id: "light.kitchen", type: .entity)], layout: .grid, showAddEditButtons: true)
        drainMainQueue()
        let tiles = imageRows()
        XCTAssertEqual(tiles.count, 2)
        sut = nil

        var completions = 0
        for tile in tiles {
            for index in tile.elements.indices {
                tile.listImageRowHandler?(tile, index) { completions += 1 }
            }
        }

        XCTAssertEqual(completions, 3)
        XCTAssertTrue(connection.pendingRequests.isEmpty)
        XCTAssertTrue(navigator.pushedTemplates.isEmpty)
    }
}
