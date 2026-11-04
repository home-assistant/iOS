import CarPlay
import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Drives the vacuum control screen through a fake navigator: the rows each capability adds, the
/// commands they send, the fan speed list, and the clean-areas picker from mapping to start.
final class CarPlayVacuumControlTemplateTests: XCTestCase {
    private let allFeatures = 4 | 8 | 16 | 32 | 64 | 512 | 8192 | 16384

    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var database: DatabaseQueue!
    private var server: Server!
    private var connection: HAMockConnection!
    private var navigator: FakeCarPlayNavigator!
    private var viewModel: CarPlayVacuumControlViewModel!
    private var sut: CarPlayVacuumControlTemplate!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        let database = try CarPlayTestDatabase.make()
        self.database = database
        Current.database = { database }
        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()
        navigator = FakeCarPlayNavigator()
    }

    override func tearDown() {
        connection?.pendingRequests.removeAll()
        connection?.pendingSubscriptions.removeAll()
        Current.cachedApis = [:]
        Current.servers = previousServers
        Current.database = previousDatabase
        sut = nil
        viewModel = nil
        navigator = nil
        connection = nil
        server = nil
        database = nil
        previousServers = nil
        previousDatabase = nil
        super.tearDown()
    }

    private func connectAPI() {
        let api = HomeAssistantAPI(server: server)
        let mock = HAMockConnection()
        api.connection = mock
        Current.cachedApis[server.identifier] = api
        connection = mock
    }

    private func entity(state: String, attributes: [String: Any]) throws -> HAEntity {
        try HAEntity(
            entityId: "vacuum.robot",
            state: state,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: attributes,
            context: .init(id: "", userId: "", parentId: "")
        )
    }

    private func fullAttributes(battery: Int = 80) -> [String: Any] {
        [
            "friendly_name": "Robot",
            "supported_features": allFeatures,
            "fan_speed_list": ["low", "high"],
            "fan_speed": "low",
            "battery_level": battery,
        ]
    }

    private func makeSut(state: String = "docked", attributes: [String: Any]? = nil) throws {
        viewModel = try CarPlayVacuumControlViewModel(
            server: server,
            entity: entity(state: state, attributes: attributes ?? fullAttributes())
        )
        sut = CarPlayVacuumControlTemplate(viewModel: viewModel)
        sut.navigatorOverride = navigator
    }

    private func texts(_ template: CPListTemplate?) -> [String] {
        CarPlayTestRows.texts(template)
    }

    private func services() -> [String?] {
        connection.pendingRequests.map { $0.request.data["service"] as? String }
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(condition(), "condition not met within 10 s", file: file, line: line)
    }

    private func addArea(_ areaId: String, name: String) throws {
        try database.write { db in
            try AppArea(
                id: "\(self.server.identifier.rawValue)-\(areaId)", serverId: self.server.identifier.rawValue,
                areaId: areaId, name: name, aliases: [], picture: nil, icon: nil, sortOrder: nil, entities: []
            ).insert(db)
        }
    }

    private func mapping(_ areaIds: [String]) -> HAData {
        .dictionary([
            "options": [
                "vacuum": [
                    "area_mapping": Dictionary(uniqueKeysWithValues: areaIds.map { ($0, ["segment"]) }),
                ],
            ],
        ])
    }

    func testEveryCapabilityAddsItsRowAndSendsItsCommand() throws {
        connectAPI()
        try makeSut()

        XCTAssertEqual(sut.template.title, "Robot")
        let rows = CarPlayTestRows.listItems(sut.template)
        XCTAssertEqual(rows.dropFirst().map(\.text), [
            L10n.Vacuum.Control.start,
            L10n.Vacuum.Control.stop,
            L10n.Vacuum.Control.returnToBase,
            L10n.Vacuum.Control.locate,
            L10n.Vacuum.Control.CleanAreas.title,
            L10n.Vacuum.Control.FanSpeed.title,
        ])
        XCTAssertEqual(rows.first?.detailText, L10n.Vacuum.Control.battery("80%"))
        XCTAssertEqual(rows.last?.detailText, "Low")

        for row in rows.dropFirst().prefix(4) {
            CarPlayTestRows.tap(row)
        }
        XCTAssertEqual(services(), ["start", "stop", "return_to_base", "locate"])
    }

    func testACleaningVacuumOffersPause() throws {
        connectAPI()
        try makeSut(state: "cleaning")

        CarPlayTestRows.tap(CarPlayTestRows.row(sut.template, L10n.Vacuum.Control.pause))

        XCTAssertFalse(texts(sut.template).contains(L10n.Vacuum.Control.start))
        XCTAssertEqual(services(), ["pause"])
    }

    func testAVacuumWithoutCapabilitiesOnlyShowsItsStatus() throws {
        try makeSut(attributes: [:])

        XCTAssertEqual(CarPlayTestRows.listItems(sut.template).count, 1)
        XCTAssertNil(CarPlayTestRows.listItems(sut.template).first?.detailText)
    }

    /// New values refresh rows in place; a new cleaning state swaps start for pause.
    func testStateChangesRefreshTheScreen() throws {
        try makeSut()
        let status = CarPlayTestRows.listItems(sut.template).first

        try sut.entitiesStateChange(
            serverId: server.identifier.rawValue,
            entities: HACachedStates(entitiesDictionary: ["vacuum.robot": entity(
                state: "docked",
                attributes: fullAttributes(battery: 40)
            )])
        )
        XCTAssertTrue(CarPlayTestRows.listItems(sut.template).first === status)
        XCTAssertEqual(status?.detailText, L10n.Vacuum.Control.battery("40%"))

        try sut.entitiesStateChange(
            serverId: "other",
            entities: HACachedStates(entitiesDictionary: ["vacuum.robot": entity(
                state: "cleaning",
                attributes: fullAttributes()
            )])
        )
        XCTAssertTrue(texts(sut.template).contains(L10n.Vacuum.Control.start))

        try sut.entitiesStateChange(
            serverId: server.identifier.rawValue,
            entities: HACachedStates(entitiesDictionary: ["vacuum.robot": entity(
                state: "cleaning",
                attributes: fullAttributes()
            )])
        )
        XCTAssertTrue(texts(sut.template).contains(L10n.Vacuum.Control.pause))

        sut.templateWillDisappear(template: sut.template)
        sut.templateWillAppear(template: sut.template)
        XCTAssertTrue(texts(sut.template).contains(L10n.Vacuum.Control.pause))
    }

    func testPickingAFanSpeedSendsItAndReturns() throws {
        connectAPI()
        try makeSut()

        CarPlayTestRows.tap(CarPlayTestRows.row(sut.template, L10n.Vacuum.Control.FanSpeed.title))
        let speeds = try XCTUnwrap(navigator.pushedTemplates.last as? CPListTemplate)
        XCTAssertEqual(texts(speeds), ["Low", "High"])
        XCTAssertNotNil(CarPlayTestRows.listItems(speeds).first?.image, "the current speed is checked")

        CarPlayTestRows.tap(CarPlayTestRows.row(speeds, "High"))

        XCTAssertEqual(services(), ["set_fan_speed"])
        XCTAssertEqual(navigator.popCount, 1)
    }

    /// Areas are numbered in tap order; the start row cleans them in that order and returns.
    func testCleaningPickedAreasInTheOrderTapped() throws {
        connectAPI()
        try addArea("hall", name: "Hall")
        try addArea("kitchen", name: "Kitchen")
        try makeSut()

        CarPlayTestRows.tap(CarPlayTestRows.row(sut.template, L10n.Vacuum.Control.CleanAreas.title))
        let picker = try XCTUnwrap(navigator.pushedTemplates.last as? CPListTemplate)
        let request = try XCTUnwrap(connection.pendingRequests.last)
        request.completion(.success(mapping(["kitchen", "hall", "deleted"])))
        waitUntil { !texts(picker).isEmpty }
        XCTAssertEqual(texts(picker), ["Hall", "Kitchen"])

        CarPlayTestRows.tap(CarPlayTestRows.row(picker, "Kitchen"))
        CarPlayTestRows.tap(CarPlayTestRows.row(picker, "Hall"))
        XCTAssertEqual(CarPlayTestRows.row(picker, "Kitchen")?.detailText, L10n.Vacuum.Control.CleanAreas.order("1"))
        CarPlayTestRows.tap(CarPlayTestRows.row(picker, "Kitchen"))
        CarPlayTestRows.tap(CarPlayTestRows.row(picker, "Kitchen"))
        let start = L10n.Vacuum.Control.CleanAreas.start("2")
        XCTAssertNotNil(CarPlayTestRows.row(picker, start))

        CarPlayTestRows.tap(CarPlayTestRows.row(picker, start))

        let clean = try XCTUnwrap(connection.pendingRequests.last)
        XCTAssertEqual(clean.request.data["service"] as? String, "clean_area")
        let serviceData = clean.request.data["service_data"] as? [String: Any]
        XCTAssertEqual(serviceData?["cleaning_area_id"] as? [String], ["hall", "kitchen"])
        XCTAssertEqual(navigator.popCount, 1)
        XCTAssertTrue(viewModel.selectedAreaIds.isEmpty)
    }

    func testAnEmptyMappingSaysSo() throws {
        connectAPI()
        try makeSut()

        CarPlayTestRows.tap(CarPlayTestRows.row(sut.template, L10n.Vacuum.Control.CleanAreas.title))
        let picker = try XCTUnwrap(navigator.pushedTemplates.last as? CPListTemplate)
        try XCTUnwrap(connection.pendingRequests.last).completion(.success(mapping([])))

        waitUntil { picker.emptyViewSubtitleVariants == [L10n.Vacuum.Control.CleanAreas.empty] }
        XCTAssertTrue(picker.sections.isEmpty)
        viewModel.startCleaningSelectedAreas()
        XCTAssertEqual(connection.pendingRequests.count, 1, "nothing picked, nothing sent")
    }

    func testAFailedMappingRequestEndsTheLoad() throws {
        connectAPI()
        try makeSut()

        CarPlayTestRows.tap(CarPlayTestRows.row(sut.template, L10n.Vacuum.Control.CleanAreas.title))
        let picker = try XCTUnwrap(navigator.pushedTemplates.last as? CPListTemplate)
        try XCTUnwrap(connection.pendingRequests.last).completion(.failure(.internal(debugDescription: "nope")))

        waitUntil { !self.viewModel.isLoadingAreas }
        waitUntil { picker.emptyViewSubtitleVariants == [L10n.Vacuum.Control.CleanAreas.empty] }
    }

    func testAMappingThatCannotBeResolvedListsNothing() throws {
        connectAPI()
        try makeSut()
        let broken = try CarPlayTestDatabase.broken()
        Current.database = { broken }

        CarPlayTestRows.tap(CarPlayTestRows.row(sut.template, L10n.Vacuum.Control.CleanAreas.title))
        try XCTUnwrap(connection.pendingRequests.last).completion(.success(mapping(["kitchen"])))

        waitUntil { !self.viewModel.isLoadingAreas }
        XCTAssertTrue(viewModel.cleanableAreas.isEmpty)
    }

    /// A server the app can't reach has no API, which is what a dead zone looks like here.
    func testThePickerWithoutAConnectionShowsTheEmptyState() throws {
        server = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
        try makeSut()

        CarPlayTestRows.tap(CarPlayTestRows.row(sut.template, L10n.Vacuum.Control.CleanAreas.title))
        let picker = try XCTUnwrap(navigator.pushedTemplates.last as? CPListTemplate)

        XCTAssertEqual(picker.emptyViewSubtitleVariants, [L10n.Vacuum.Control.CleanAreas.empty])
    }

    func testOnlyClimateAndVacuumEntitiesHaveAControlScreen() throws {
        let vacuum = try CarPlayControlScreenFactory.template(
            entity: entity(state: "docked", attributes: [:]),
            server: server
        )
        XCTAssertTrue(vacuum is CarPlayVacuumControlTemplate)

        let light = try HAEntity(
            entityId: "light.kitchen",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: "", parentId: "")
        )
        XCTAssertNil(CarPlayControlScreenFactory.template(entity: light, server: server))
    }
}
