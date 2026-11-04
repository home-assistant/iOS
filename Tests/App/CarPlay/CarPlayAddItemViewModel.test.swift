import GRDB
import HAKit
@testable import HomeAssistant
@testable import Shared
import XCTest

/// CarPlay Assist items talk and listen through the car, so the picker only offers pipelines the server
/// can both transcribe and speak for.
final class CarPlayAddItemViewModelTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!
    private var database: DatabaseQueue!
    private var previousServers: ServerManager?

    private let voicePipeline = Pipeline(id: "voice", name: "Voice", sttEngine: "stt.cloud", ttsEngine: "tts.cloud")
    private let speechToTextOnlyPipeline = Pipeline(id: "stt-only", name: "STT only", sttEngine: "stt.cloud")
    private let textOnlyPipeline = Pipeline(id: "text", name: "Text", sttEngine: " ", ttsEngine: nil)

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousDatabase = Current.database
        let database = try CarPlayTestDatabase.make()
        self.database = database
        Current.database = { database }
    }

    override func tearDown() {
        Current.database = previousDatabase
        if let previousServers {
            Current.servers = previousServers
        }
        previousServers = nil
        database = nil
        super.tearDown()
    }

    func testOnlyPipelinesWithSpeechToTextAndTextToSpeechAreOffered() throws {
        try cache(preferred: voicePipeline.id)

        let pipelines = CarPlayAddItemViewModel().assistPipelines(serverId: "server")

        XCTAssertEqual(pipelines.map(\.id), ["", voicePipeline.id], "the preferred entry, then the voice pipeline")
    }

    func testPreferredEntryIsLeftOutWhenThePreferredPipelineCannotSpeak() throws {
        try cache(preferred: textOnlyPipeline.id)

        let pipelines = CarPlayAddItemViewModel().assistPipelines(serverId: "server")

        XCTAssertEqual(pipelines.map(\.id), [voicePipeline.id])
    }

    func testNoPipelinesAreOfferedWithoutACacheForTheServer() {
        XCTAssertTrue(CarPlayAddItemViewModel().assistPipelines(serverId: "server").isEmpty)
    }

    func testNoPipelinesAreOfferedWhenNoneCanSpeak() throws {
        try database.write { db in
            try AssistPipelines(
                serverId: "server",
                preferredPipeline: textOnlyPipeline.id,
                pipelines: [textOnlyPipeline]
            ).save(db)
        }

        XCTAssertTrue(CarPlayAddItemViewModel().assistPipelines(serverId: "server").isEmpty)
    }

    func testServersAreTheConfiguredOnes() {
        let servers = FakeServerManager(initial: 2)
        previousServers = Current.servers
        Current.servers = servers

        XCTAssertEqual(CarPlayAddItemViewModel().servers.map(\.identifier), servers.all.map(\.identifier))
    }

    func testEditableItemsComeFromTheDestination() throws {
        let folder = MagicItem(id: "folder", serverId: "server", type: .folder, items: [entity("light.inside")])
        try save(CarPlayConfig(quickAccessItems: [entity("light.root"), folder]))

        XCTAssertEqual(CarPlayAddItemViewModel().editableItems.map(\.id), ["light.root", "folder"])
        XCTAssertEqual(
            CarPlayAddItemViewModel(destination: .folder(folderId: "folder")).editableItems.map(\.id),
            ["light.inside"]
        )
        XCTAssertTrue(CarPlayAddItemViewModel(destination: .folder(folderId: "gone")).editableItems.isEmpty)
    }

    func testEditableItemsAreEmptyWithoutAConfig() {
        XCTAssertTrue(CarPlayAddItemViewModel().editableItems.isEmpty)
    }

    /// Hidden and configuration/diagnostic entities, other servers' entities and unsupported
    /// domains never reach the picker.
    func testDomainsAndEntitiesOnlyListCompatibleEntities() throws {
        try insertEntity("light.kitchen", name: "Kitchen")
        try insertEntity("cover.garage", name: "Garage")
        try insertEntity("switch.alpha", name: "alpha")
        try insertEntity("switch.Beta", name: "Beta")
        try insertEntity("sensor.temperature", name: "Temperature")
        try insertEntity("light.hidden", name: "Hidden")
        try insertEntity("switch.diagnostic", name: "Diagnostic")
        try insertEntity("light.elsewhere", name: "Elsewhere", serverId: "other")
        try insertRegistryEntry(["ei": "light.hidden", "hb": true])
        try insertRegistryEntry(["ei": "switch.diagnostic", "ec": 1])
        try insertRegistryEntry(["ei": "light.kitchen"])

        let viewModel = CarPlayAddItemViewModel()

        XCTAssertEqual(viewModel.domains(serverId: "server").first, .cover)
        XCTAssertEqual(Set(viewModel.domains(serverId: "server")), [.cover, .light, .switch])
        XCTAssertEqual(viewModel.entities(serverId: "server", domain: .light).map(\.entityId), ["light.kitchen"])
        XCTAssertEqual(
            viewModel.entities(serverId: "server", domain: .switch).map(\.name),
            ["alpha", "Beta"],
            "sorted case-insensitively by name"
        )
    }

    func testAreasOnlyListThoseWithCompatibleEntities() throws {
        try insertEntity("light.kitchen", name: "Kitchen")
        try insertEntity("sensor.temperature", name: "Temperature")
        let kitchen = area("Kitchen", entities: ["light.kitchen", "sensor.temperature"])
        try database.write { db in
            try kitchen.insert(db)
            try self.area("Attic", entities: ["sensor.temperature"]).insert(db)
        }

        let viewModel = CarPlayAddItemViewModel()

        XCTAssertEqual(viewModel.areas(serverId: "server").map(\.name), ["Kitchen"])
        XCTAssertEqual(viewModel.entities(serverId: "server", area: kitchen).map(\.entityId), ["light.kitchen"])
    }

    func testIconsFallBackSensibly() throws {
        let viewModel = CarPlayAddItemViewModel()
        let withIcon = HAAppEntity(
            id: "1", entityId: "light.a", serverId: "server", domain: "light", name: "A",
            icon: "mdi:lamp", rawDeviceClass: nil
        )
        let withoutIcon = HAAppEntity(
            id: "2", entityId: "light.b", serverId: "server", domain: "light", name: "B",
            icon: nil, rawDeviceClass: nil
        )
        let unknownDomain = HAAppEntity(
            id: "3", entityId: "nope.c", serverId: "server", domain: "nope", name: "C",
            icon: nil, rawDeviceClass: nil
        )

        XCTAssertEqual(viewModel.icon(for: withIcon).name, MaterialDesignIcons(serversideValueNamed: "mdi:lamp").name)
        XCTAssertEqual(viewModel.icon(for: withoutIcon).name, Domain.light.icon().name)
        XCTAssertEqual(viewModel.icon(for: unknownDomain).name, MaterialDesignIcons.dotsGridIcon.name)
        XCTAssertEqual(viewModel.icon(for: .cover).name, MaterialDesignIcons.garageLockIcon.name)
        XCTAssertEqual(viewModel.icon(for: .light).name, Domain.light.icon().name)
        XCTAssertEqual(
            viewModel.icon(for: area("A", entities: [])).name,
            MaterialDesignIcons(serversideValueNamed: "mdi:circle").name
        )
    }

    func testAddingAnEntityToAFolderAppendsInsideIt() throws {
        try save(CarPlayConfig(quickAccessItems: [MagicItem(id: "folder", serverId: "server", type: .folder)]))

        CarPlayAddItemViewModel(destination: .folder(folderId: "folder"))
            .addEntityToQuickAccess(entityId: "light.a", serverId: "server", requiresConfirmation: true)

        let folder = try XCTUnwrap(config()?.quickAccessItems.first)
        XCTAssertEqual(folder.items?.map(\.id), ["light.a"])
    }

    func testAddingANamedPipelineKeepsItsId() throws {
        CarPlayAddItemViewModel().addAssistPipelineToQuickAccess(pipeline: voicePipeline, serverId: "server")

        let item = try XCTUnwrap(config()?.quickAccessItems.first)
        XCTAssertEqual(item.id, voicePipeline.id)
        XCTAssertNil(item.assistPipelineId)
    }

    func testAddingAPipelineToAMissingFolderSavesNothing() throws {
        CarPlayAddItemViewModel(destination: .folder(folderId: "gone"))
            .addAssistPipelineToQuickAccess(pipeline: voicePipeline, serverId: "server")

        XCTAssertNil(try config())
    }

    func testDeletingAFolderAlsoRemovesItsTab() throws {
        let folder = MagicItem(id: "folder", serverId: "server", type: .folder)
        try save(CarPlayConfig(tabs: [.quickAccess, .folder(folderId: "folder")], quickAccessItems: [folder]))

        CarPlayAddItemViewModel().deleteItemFromQuickAccess(folder)

        let saved = try XCTUnwrap(config())
        XCTAssertTrue(saved.quickAccessItems.isEmpty)
        XCTAssertEqual(saved.tabs, [.quickAccess])
    }

    func testDeletingAnItemThatIsNotThereSavesNothing() throws {
        try save(CarPlayConfig(quickAccessItems: [entity("light.a")]))

        CarPlayAddItemViewModel().deleteItemFromQuickAccess(entity("light.gone"))
        CarPlayAddItemViewModel(destination: .folder(folderId: "gone")).deleteItemFromQuickAccess(entity("light.a"))

        XCTAssertEqual(try config()?.quickAccessItems.map(\.id), ["light.a"])
    }

    func testUpdatingConfirmationOfAnItemThatIsNotThereSavesNothing() throws {
        let folder = MagicItem(id: "folder", serverId: "server", type: .folder, items: [entity("light.inside")])
        try save(CarPlayConfig(quickAccessItems: [entity("light.a"), folder]))

        CarPlayAddItemViewModel().updateItemConfirmation(entity("light.gone"), requiresConfirmation: true)
        CarPlayAddItemViewModel(destination: .folder(folderId: "folder"))
            .updateItemConfirmation(entity("light.gone"), requiresConfirmation: true)
        CarPlayAddItemViewModel(destination: .folder(folderId: "folder"))
            .updateItemConfirmation(entity("light.inside"), requiresConfirmation: true)

        let saved = try XCTUnwrap(config())
        XCTAssertEqual(saved.quickAccessItems.first?.customization?.requiresConfirmation, false)
        XCTAssertEqual(saved.quickAccessItems.last?.items?.first?.customization?.requiresConfirmation, true)
    }

    /// Every read and write fails against a database without tables; each call logs and gives up.
    func testADatabaseThatFailsLeavesEverythingEmpty() throws {
        let broken = try CarPlayTestDatabase.broken()
        Current.database = { broken }
        let viewModel = CarPlayAddItemViewModel()

        XCTAssertTrue(viewModel.editableItems.isEmpty)
        XCTAssertTrue(viewModel.domains(serverId: "server").isEmpty)
        XCTAssertTrue(viewModel.areas(serverId: "server").isEmpty)
        XCTAssertTrue(viewModel.assistPipelines(serverId: "server").isEmpty)
        viewModel.addEntityToQuickAccess(entityId: "light.a", serverId: "server", requiresConfirmation: false)
        viewModel.addAssistPipelineToQuickAccess(pipeline: voicePipeline, serverId: "server")
        viewModel.deleteItemFromQuickAccess(entity("light.a"))
        viewModel.updateItemConfirmation(entity("light.a"), requiresConfirmation: true)
    }

    private func entity(_ id: String) -> MagicItem {
        MagicItem(id: id, serverId: "server", type: .entity, customization: .init(requiresConfirmation: false))
    }

    private func area(_ name: String, entities: Set<String>) -> AppArea {
        AppArea(
            id: "server-\(name)", serverId: "server", areaId: name, name: name, aliases: [],
            picture: nil, icon: nil, sortOrder: nil, entities: entities
        )
    }

    private func insertEntity(_ entityId: String, name: String, serverId: String = "server") throws {
        try database.write { db in
            try HAAppEntity(
                id: "\(serverId)-\(entityId)", entityId: entityId, serverId: serverId,
                domain: String(entityId.split(separator: ".")[0]), name: name, icon: nil, rawDeviceClass: nil
            ).insert(db)
        }
    }

    private func insertRegistryEntry(_ data: [String: Any]) throws {
        var entry = try EntityRegistryListForDisplay.Entity(data: .dictionary(data))
        entry.serverId = "server"
        try database.write { db in try entry.insert(db) }
    }

    private func save(_ config: CarPlayConfig) throws {
        try database.write { db in try config.insert(db, onConflict: .replace) }
    }

    private func config() throws -> CarPlayConfig? {
        try database.read { db in try CarPlayConfig.fetchOne(db) }
    }

    private func cache(preferred: String) throws {
        try database.write { db in
            try AssistPipelines(
                serverId: "server",
                preferredPipeline: preferred,
                pipelines: [voicePipeline, speechToTextOnlyPipeline, textOnlyPipeline]
            ).save(db)
        }
    }
}
