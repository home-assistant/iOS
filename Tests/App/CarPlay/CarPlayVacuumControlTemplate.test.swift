import CarPlay
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The vacuum control screen: a status row, the commands the vacuum supports (start flipping to
/// pause while it cleans), and the clean-areas and fan-speed pickers.
final class CarPlayVacuumControlTemplateTests: XCTestCase {
    /// Pause, stop, return home, fan speed, battery, locate, start and clean area.
    private static let allFeatures = 4 | 8 | 16 | 32 | 64 | 512 | 8192 | 16384

    private var previousServers: ServerManager!
    private var server: Server!
    private var connection: HAMockConnection!
    private var viewModel: CarPlayVacuumControlViewModel!
    private var sut: CarPlayVacuumControlTemplate!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()

        let api = HomeAssistantAPI(server: server)
        let mock = HAMockConnection()
        api.connection = mock
        Current.cachedApis[server.identifier] = api
        connection = mock
    }

    override func tearDown() {
        Current.cachedApis = [:]
        Current.servers = previousServers
        sut = nil
        viewModel = nil
        connection = nil
        server = nil
        super.tearDown()
    }

    private func attributes(features: Int = CarPlayVacuumControlTemplateTests.allFeatures) -> [String: Any] {
        [
            "friendly_name": "Robbie",
            "supported_features": features,
            "battery_level": 80,
            "fan_speed": "max",
            "fan_speed_list": ["quiet", "max"],
        ]
    }

    private func makeSut(state: String = "docked", features: Int = CarPlayVacuumControlTemplateTests.allFeatures) throws {
        let entity = try CarPlayTestHelpers.entity(
            "vacuum.robbie",
            state: state,
            attributes: attributes(features: features)
        )
        viewModel = CarPlayVacuumControlViewModel(server: server, entity: entity)
        sut = CarPlayVacuumControlTemplate(viewModel: viewModel)
    }

    private var commandRows: [CPListItem] {
        sut.template.sections.first?.items.compactMap { $0 as? CPListItem } ?? []
    }

    private var selectionRows: [CPListItem] {
        sut.template.sections.dropFirst().first?.items.compactMap { $0 as? CPListItem } ?? []
    }

    private func command(_ text: String) throws -> CPListItem {
        try XCTUnwrap(commandRows.first(where: { $0.text == text }), "No command \(text)")
    }

    func testADockedVacuumOffersEveryCommand() throws {
        try makeSut()

        XCTAssertEqual(sut.template.title, "Robbie")
        XCTAssertEqual(commandRows.dropFirst().map(\.text), [
            L10n.Vacuum.Control.start,
            L10n.Vacuum.Control.stop,
            L10n.Vacuum.Control.returnToBase,
            L10n.Vacuum.Control.locate,
        ])
        XCTAssertEqual(commandRows.first?.text, viewModel.stateText)
        XCTAssertEqual(commandRows.first?.detailText, L10n.Vacuum.Control.battery("80%"))
        XCTAssertEqual(selectionRows.map(\.text), [
            L10n.Vacuum.Control.CleanAreas.title,
            L10n.Vacuum.Control.FanSpeed.title,
        ])
        XCTAssertEqual(selectionRows.last?.detailText, "Max")
    }

    func testACleaningVacuumOffersPauseInsteadOfStart() throws {
        try makeSut(state: "cleaning")

        XCTAssertEqual(commandRows.dropFirst().first?.text, L10n.Vacuum.Control.pause)
        XCTAssertFalse(commandRows.contains(where: { $0.text == L10n.Vacuum.Control.start }))
    }

    func testAVacuumWithoutFeaturesOnlyShowsItsStatus() throws {
        try makeSut(features: 0)

        XCTAssertEqual(sut.template.sections.count, 1)
        XCTAssertEqual(commandRows.count, 1)
        XCTAssertNil(commandRows.first?.detailText, "Battery is only shown when the vacuum reports it")
    }

    func testEachCommandIsSent() throws {
        try makeSut()

        for text in [
            L10n.Vacuum.Control.start,
            L10n.Vacuum.Control.stop,
            L10n.Vacuum.Control.returnToBase,
            L10n.Vacuum.Control.locate,
        ] {
            try CarPlayTestHelpers.tap(command(text))
        }

        XCTAssertEqual(connection.pendingRequests.count, 4)
    }

    func testPauseIsSentWhileCleaning() throws {
        try makeSut(state: "cleaning")

        try CarPlayTestHelpers.tap(command(L10n.Vacuum.Control.pause))

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    /// Opening the fan speed picker needs a CarPlay screen; choosing a speed sends it.
    func testFanSpeed() throws {
        try makeSut()
        try CarPlayTestHelpers.tap(XCTUnwrap(selectionRows.last))
        XCTAssertTrue(connection.pendingRequests.isEmpty)

        viewModel.setFanSpeed("quiet")

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    /// Opening the area picker starts loading the vacuum's mapping and clears any earlier picks.
    func testOpeningTheAreaPickerLoadsTheMapping() throws {
        try makeSut()
        viewModel.toggleAreaSelection("kitchen")

        try CarPlayTestHelpers.tap(XCTUnwrap(selectionRows.first))

        XCTAssertTrue(viewModel.selectedAreaIds.isEmpty)
        XCTAssertTrue(viewModel.isLoadingAreas)
        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testAreaSelectionKeepsTapOrderAndSendsIt() throws {
        try makeSut()

        viewModel.startCleaningSelectedAreas()
        XCTAssertTrue(connection.pendingRequests.isEmpty, "Nothing picked, nothing to clean")

        viewModel.toggleAreaSelection("kitchen")
        viewModel.toggleAreaSelection("hall")
        viewModel.toggleAreaSelection("bedroom")
        viewModel.toggleAreaSelection("hall")
        XCTAssertEqual(viewModel.selectedAreaIds, ["kitchen", "bedroom"])
        XCTAssertEqual(viewModel.selectionOrder(of: "bedroom"), 2)
        XCTAssertNil(viewModel.selectionOrder(of: "hall"))

        viewModel.startCleaningSelectedAreas()

        XCTAssertEqual(connection.pendingRequests.count, 1)
        XCTAssertTrue(viewModel.selectedAreaIds.isEmpty)
    }

    /// Starting to clean swaps start for pause, which rebuilds the commands; a battery change only
    /// refreshes the status row.
    func testStateUpdatesRefreshOrRebuild() throws {
        try makeSut()
        let status = try XCTUnwrap(commandRows.first)

        var lowBattery = attributes()
        lowBattery["battery_level"] = 20
        let draining = try CarPlayTestHelpers.entity("vacuum.robbie", state: "docked", attributes: lowBattery)
        sut.entitiesStateChange(serverId: server.identifier.rawValue, entities: CarPlayTestHelpers.states([draining]))

        XCTAssertTrue(commandRows.first === status)
        XCTAssertEqual(status.detailText, L10n.Vacuum.Control.battery("20%"))

        let cleaning = try CarPlayTestHelpers.entity("vacuum.robbie", state: "cleaning", attributes: lowBattery)
        sut.entitiesStateChange(serverId: server.identifier.rawValue, entities: CarPlayTestHelpers.states([cleaning]))

        XCTAssertEqual(commandRows.dropFirst().first?.text, L10n.Vacuum.Control.pause)
        XCTAssertFalse(commandRows.first === status)
    }

    func testUpdatesForAnotherServerAreIgnored() throws {
        try makeSut()
        let cleaning = try CarPlayTestHelpers.entity("vacuum.robbie", state: "cleaning", attributes: attributes())

        sut.entitiesStateChange(serverId: "other", entities: CarPlayTestHelpers.states([cleaning]))

        XCTAssertFalse(viewModel.isCleaning)
    }

    func testAppearingRefreshesTheValues() throws {
        try makeSut()
        let status = try XCTUnwrap(commandRows.first)

        sut.templateWillAppear(template: sut.template)
        sut.templateWillDisappear(template: sut.template)
        sut.update()

        XCTAssertTrue(commandRows.first === status)
    }
}
