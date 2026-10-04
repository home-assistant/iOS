import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

/// What the in-car add/edit flows offer and save: only entities CarPlay can act on, areas that hold
/// one of them, pipelines that can listen and speak — and edits that land in the Quick Access list
/// or in the folder the flow was opened from.
final class CarPlayAddItemViewModelTests: XCTestCase {
    private let serverId = "server-1"
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var database: DatabaseQueue!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database

        let database = try CarPlayTestHelpers.makeDatabase()
        self.database = database
        Current.database = { database }
        Current.servers = FakeServerManager()
        try CarPlayAddItemFixture.seed(in: database, serverId: serverId)
    }

    override func tearDown() {
        Current.servers = previousServers
        Current.database = previousDatabase
        database = nil
        super.tearDown()
    }

    private func storedConfig() throws -> CarPlayConfig {
        try XCTUnwrap(CarPlayTestHelpers.storedConfig(in: database))
    }

    private func entityItem(_ entityId: String, requiresConfirmation: Bool = false) -> MagicItem {
        MagicItem(
            id: entityId,
            serverId: serverId,
            type: .entity,
            customization: .init(requiresConfirmation: requiresConfirmation)
        )
    }

    private func folder(_ id: String, items: [MagicItem]) -> MagicItem {
        MagicItem(id: id, serverId: "", type: .folder, displayText: id, items: items)
    }

    // MARK: - What the picker offers

    func testServersAreTheConfiguredOnes() throws {
        let servers = try XCTUnwrap(Current.servers as? FakeServerManager)
        let server = servers.addFake()

        XCTAssertEqual(CarPlayAddItemViewModel().servers.map(\.identifier), [server.identifier])
    }

    /// Covers come first for quick garage access; unsupported, configuration and hidden entities
    /// don't count towards a domain.
    func testDomainsAreTheSupportedOnesWithCoversFirst() {
        let domains = CarPlayAddItemViewModel().domains(serverId: serverId)

        XCTAssertEqual(domains.first, .cover)
        XCTAssertEqual(Set(domains), [.cover, .light, .lock, .climate])
    }

    func testEntitiesOfADomainLeaveOutHiddenAndOtherServers() {
        let viewModel = CarPlayAddItemViewModel()

        XCTAssertEqual(viewModel.entities(serverId: serverId, domain: .light).map(\.entityId), ["light.kitchen"])
        XCTAssertTrue(viewModel.entities(serverId: serverId, domain: .switch).isEmpty)
        XCTAssertTrue(viewModel.entities(serverId: serverId, domain: .sensor).isEmpty)
    }

    /// An area only holding things CarPlay can't act on would open an empty list, so it is left out.
    func testAreasAreTheOnesWithSomethingToAdd() throws {
        let viewModel = CarPlayAddItemViewModel()
        let areas = viewModel.areas(serverId: serverId)

        XCTAssertEqual(areas.map(\.name), ["Kitchen", "Garage"])
        let kitchen = try XCTUnwrap(areas.first)
        let garage = try XCTUnwrap(areas.last)
        // Sorted by display name: "Front door" before "Garage door".
        XCTAssertEqual(
            viewModel.entities(serverId: serverId, area: garage).map(\.entityId),
            ["lock.front_door", "cover.garage_door"]
        )
        XCTAssertEqual(viewModel.entities(serverId: serverId, area: kitchen).map(\.entityId), ["light.kitchen"])
    }

    func testAServerWithNothingCachedOffersNothing() {
        let viewModel = CarPlayAddItemViewModel()

        XCTAssertTrue(viewModel.domains(serverId: "unknown").isEmpty)
        XCTAssertTrue(viewModel.areas(serverId: "unknown").isEmpty)
        XCTAssertTrue(viewModel.assistPipelines(serverId: "unknown").isEmpty)
    }

    /// Only pipelines that can both listen and answer out loud are usable in the car; the server's
    /// preferred one is also offered as "Preferred", which follows the server's choice.
    func testAssistPipelinesAreTheVoiceCapableOnesPlusPreferred() {
        let pipelines = CarPlayAddItemViewModel().assistPipelines(serverId: serverId)

        XCTAssertEqual(pipelines.map(\.id), ["", CarPlayAddItemFixture.preferredPipelineId, CarPlayAddItemFixture.otherPipelineId])
        XCTAssertEqual(pipelines.first?.name, L10n.AppIntents.Assist.PreferredPipeline.title)
    }

    func testNoPreferredEntryWhenThePreferredPipelineCannotSpeak() throws {
        try database.write { db in
            try AssistPipelines(
                serverId: "server-2",
                preferredPipeline: "text",
                pipelines: [
                    Pipeline(id: "text", name: "Text", sttEngine: "stt.cloud", ttsEngine: nil),
                    Pipeline(id: "voice", name: "Voice", sttEngine: "stt.cloud", ttsEngine: "tts.cloud"),
                ]
            ).insert(db)
            try AssistPipelines(
                serverId: "server-3",
                preferredPipeline: "text",
                pipelines: [Pipeline(id: "text", name: "Text")]
            ).insert(db)
        }
        let viewModel = CarPlayAddItemViewModel()

        XCTAssertEqual(viewModel.assistPipelines(serverId: "server-2").map(\.id), ["voice"])
        XCTAssertTrue(viewModel.assistPipelines(serverId: "server-3").isEmpty)
    }

    func testIcons() {
        let viewModel = CarPlayAddItemViewModel()

        XCTAssertEqual(viewModel.icon(for: .cover), .garageLockIcon)
        XCTAssertEqual(viewModel.icon(for: .light), Domain.light.icon())
        XCTAssertEqual(
            viewModel.icon(for: CarPlayAddItemFixture.area("a", serverId: serverId, name: "A", sortOrder: 0, entities: [])),
            MaterialDesignIcons(serversideValueNamed: "mdi:circle")
        )
        XCTAssertEqual(
            viewModel.icon(for: CarPlayAddItemFixture.appEntity("light.kitchen", serverId: serverId, name: "Kitchen")),
            Domain.light.icon()
        )
        XCTAssertEqual(
            viewModel.icon(for: CarPlayAddItemFixture.appEntity("weird.thing", serverId: serverId, name: "Weird")),
            .dotsGridIcon
        )
    }

    // MARK: - Adding

    func testAddingAnEntityAppendsItToQuickAccess() throws {
        try CarPlayTestHelpers.save(CarPlayConfig(quickAccessItems: [entityItem("cover.garage_door")]), in: database)

        CarPlayAddItemViewModel().addEntityToQuickAccess(
            entityId: "light.kitchen",
            serverId: serverId,
            requiresConfirmation: true
        )

        let items = try storedConfig().quickAccessItems
        XCTAssertEqual(items.map(\.id), ["cover.garage_door", "light.kitchen"])
        XCTAssertEqual(items.last?.type, .entity)
        XCTAssertEqual(items.last?.customization?.requiresConfirmation, true)
    }

    func testAddingWithoutAStoredConfigurationCreatesOne() throws {
        CarPlayAddItemViewModel().addEntityToQuickAccess(
            entityId: "light.kitchen",
            serverId: serverId,
            requiresConfirmation: false
        )

        XCTAssertEqual(try storedConfig().quickAccessItems.map(\.id), ["light.kitchen"])
    }

    func testAddingAnEntityToAFolderLandsInsideIt() throws {
        try CarPlayTestHelpers.save(CarPlayConfig(quickAccessItems: [folder("garage", items: [])]), in: database)

        CarPlayAddItemViewModel(destination: .folder(folderId: "garage")).addEntityToQuickAccess(
            entityId: "cover.garage_door",
            serverId: serverId,
            requiresConfirmation: false
        )

        let stored = try storedConfig()
        XCTAssertEqual(stored.quickAccessItems.map(\.id), ["garage"])
        XCTAssertEqual(stored.folder(withId: "garage")?.items?.map(\.id), ["cover.garage_door"])
    }

    func testAddingToAFolderThatIsGoneSavesNothing() throws {
        CarPlayAddItemViewModel(destination: .folder(folderId: "gone")).addEntityToQuickAccess(
            entityId: "cover.garage_door",
            serverId: serverId,
            requiresConfirmation: false
        )
        CarPlayAddItemViewModel(destination: .folder(folderId: "gone")).addAssistPipelineToQuickAccess(
            pipeline: Pipeline(id: "p", name: "P"),
            serverId: serverId
        )

        XCTAssertNil(try CarPlayTestHelpers.storedConfig(in: database))
    }

    /// The "Preferred" entry has no id of its own: it is saved as an item that follows the server's
    /// preferred pipeline.
    func testAddingThePreferredPipelineFollowsTheServersChoice() throws {
        CarPlayAddItemViewModel().addAssistPipelineToQuickAccess(
            pipeline: Pipeline(id: "", name: "Preferred"),
            serverId: serverId
        )

        let item = try XCTUnwrap(storedConfig().quickAccessItems.first)
        XCTAssertEqual(item.type, .assistPipeline)
        XCTAssertEqual(item.assistPipelineId, "")
        XCTAssertFalse(item.id.isEmpty)
        XCTAssertEqual(item.customization?.iconColor, MagicItem.defaultAssistIconColorHex)
    }

    func testAddingASpecificPipelineKeepsItsId() throws {
        CarPlayAddItemViewModel().addAssistPipelineToQuickAccess(
            pipeline: Pipeline(id: CarPlayAddItemFixture.otherPipelineId, name: "Local"),
            serverId: serverId
        )

        let item = try XCTUnwrap(storedConfig().quickAccessItems.first)
        XCTAssertEqual(item.id, CarPlayAddItemFixture.otherPipelineId)
        XCTAssertNil(item.assistPipelineId)
        XCTAssertEqual(item.serverId, serverId)
    }

    // MARK: - Editing

    func testEditableItemsAreThoseOfTheDestination() throws {
        let child = entityItem("cover.garage_door")
        try CarPlayTestHelpers.save(
            CarPlayConfig(quickAccessItems: [entityItem("light.kitchen"), folder("garage", items: [child])]),
            in: database
        )

        XCTAssertEqual(CarPlayAddItemViewModel().editableItems.map(\.id), ["light.kitchen", "garage"])
        XCTAssertEqual(
            CarPlayAddItemViewModel(destination: .folder(folderId: "garage")).editableItems.map(\.id),
            ["cover.garage_door"]
        )
        XCTAssertTrue(CarPlayAddItemViewModel(destination: .folder(folderId: "gone")).editableItems.isEmpty)
    }

    func testNothingIsEditableWithoutAStoredConfiguration() {
        XCTAssertTrue(CarPlayAddItemViewModel().editableItems.isEmpty)
    }

    /// Deleting a folder also removes the tab it backed, which would otherwise point at nothing.
    func testDeletingAFolderRemovesItsTab() throws {
        let garage = folder("garage", items: [])
        try CarPlayTestHelpers.save(
            CarPlayConfig(
                tabs: [.quickAccess, .folder(folderId: "garage"), .settings],
                quickAccessItems: [entityItem("light.kitchen"), garage]
            ),
            in: database
        )

        CarPlayAddItemViewModel().deleteItemFromQuickAccess(garage)

        let stored = try storedConfig()
        XCTAssertEqual(stored.quickAccessItems.map(\.id), ["light.kitchen"])
        XCTAssertEqual(stored.tabs, [.quickAccess, .settings])
    }

    func testDeletingAnEntityKeepsTheTabs() throws {
        try CarPlayTestHelpers.save(
            CarPlayConfig(quickAccessItems: [entityItem("light.kitchen"), entityItem("cover.garage_door")]),
            in: database
        )

        CarPlayAddItemViewModel().deleteItemFromQuickAccess(entityItem("light.kitchen"))

        let stored = try storedConfig()
        XCTAssertEqual(stored.quickAccessItems.map(\.id), ["cover.garage_door"])
        XCTAssertEqual(stored.tabs, CarPlayConfig().tabs)
    }

    func testDeletingFromAFolderOnlyTouchesThatFolder() throws {
        let child = entityItem("cover.garage_door")
        try CarPlayTestHelpers.save(
            CarPlayConfig(quickAccessItems: [entityItem("light.kitchen"), folder("garage", items: [child])]),
            in: database
        )

        CarPlayAddItemViewModel(destination: .folder(folderId: "garage")).deleteItemFromQuickAccess(child)

        let stored = try storedConfig()
        XCTAssertEqual(stored.quickAccessItems.map(\.id), ["light.kitchen", "garage"])
        XCTAssertEqual(stored.folder(withId: "garage")?.items, [])
    }

    /// An item edited elsewhere since the flow opened is still found by its identity.
    func testDeletingMatchesAnItemWhoseCustomizationChanged() throws {
        try CarPlayTestHelpers.save(
            CarPlayConfig(quickAccessItems: [entityItem("light.kitchen", requiresConfirmation: true)]),
            in: database
        )

        CarPlayAddItemViewModel().deleteItemFromQuickAccess(entityItem("light.kitchen", requiresConfirmation: false))

        XCTAssertTrue(try storedConfig().quickAccessItems.isEmpty)
    }

    func testDeletingSomethingThatIsGoneChangesNothing() throws {
        let original = CarPlayConfig(quickAccessItems: [entityItem("light.kitchen"), folder("garage", items: [])])
        try CarPlayTestHelpers.save(original, in: database)

        CarPlayAddItemViewModel().deleteItemFromQuickAccess(entityItem("lock.front_door"))
        CarPlayAddItemViewModel(destination: .folder(folderId: "garage"))
            .deleteItemFromQuickAccess(entityItem("lock.front_door"))
        CarPlayAddItemViewModel(destination: .folder(folderId: "gone"))
            .deleteItemFromQuickAccess(entityItem("light.kitchen"))

        XCTAssertEqual(try storedConfig().quickAccessItems.map(\.id), ["light.kitchen", "garage"])
    }

    func testChangingConfirmationUpdatesTheItem() throws {
        try CarPlayTestHelpers.save(
            CarPlayConfig(quickAccessItems: [MagicItem(id: "light.kitchen", serverId: serverId, type: .entity, customization: nil)]),
            in: database
        )

        CarPlayAddItemViewModel().updateItemConfirmation(
            MagicItem(id: "light.kitchen", serverId: serverId, type: .entity, customization: nil),
            requiresConfirmation: true
        )

        XCTAssertEqual(try storedConfig().quickAccessItems.first?.customization?.requiresConfirmation, true)
    }

    func testChangingConfirmationInsideAFolder() throws {
        let child = entityItem("cover.garage_door")
        try CarPlayTestHelpers.save(CarPlayConfig(quickAccessItems: [folder("garage", items: [child])]), in: database)

        CarPlayAddItemViewModel(destination: .folder(folderId: "garage"))
            .updateItemConfirmation(child, requiresConfirmation: true)

        XCTAssertEqual(
            try storedConfig().folder(withId: "garage")?.items?.first?.customization?.requiresConfirmation,
            true
        )
    }

    func testChangingConfirmationOfSomethingThatIsGoneChangesNothing() throws {
        try CarPlayTestHelpers.save(
            CarPlayConfig(quickAccessItems: [entityItem("light.kitchen"), folder("garage", items: [])]),
            in: database
        )

        CarPlayAddItemViewModel().updateItemConfirmation(entityItem("lock.front_door"), requiresConfirmation: true)
        CarPlayAddItemViewModel(destination: .folder(folderId: "garage"))
            .updateItemConfirmation(entityItem("lock.front_door"), requiresConfirmation: true)
        CarPlayAddItemViewModel(destination: .folder(folderId: "gone"))
            .updateItemConfirmation(entityItem("light.kitchen"), requiresConfirmation: true)

        XCTAssertEqual(try storedConfig().quickAccessItems.first?.customization?.requiresConfirmation, false)
    }

    // MARK: - Unreadable database

    /// A database the app can't read offers nothing and saves nothing, rather than crashing the
    /// car's screen.
    func testAnUnreadableDatabaseOffersAndSavesNothing() throws {
        let broken = try DatabaseQueue()
        Current.database = { broken }
        let viewModel = CarPlayAddItemViewModel()

        XCTAssertTrue(viewModel.editableItems.isEmpty)
        XCTAssertTrue(viewModel.domains(serverId: serverId).isEmpty)
        XCTAssertTrue(viewModel.areas(serverId: serverId).isEmpty)
        XCTAssertTrue(viewModel.assistPipelines(serverId: serverId).isEmpty)

        viewModel.addEntityToQuickAccess(entityId: "light.kitchen", serverId: serverId, requiresConfirmation: false)
        viewModel.addAssistPipelineToQuickAccess(pipeline: Pipeline(id: "p", name: "P"), serverId: serverId)
        viewModel.deleteItemFromQuickAccess(entityItem("light.kitchen"))
        viewModel.updateItemConfirmation(entityItem("light.kitchen"), requiresConfirmation: true)

        XCTAssertNil(try CarPlayTestHelpers.storedConfig(in: database))
    }
}
