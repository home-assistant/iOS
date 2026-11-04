import CarPlay
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Drives the climate control screen through a fake navigator: a section per capability, the +/-
/// tiles, the mode lists, and the service each change sends once its debounce window closes.
final class CarPlayClimateControlTemplateTests: XCTestCase {
    /// Target temperature, range, humidity, fan, preset, swing and horizontal swing.
    private let allFeatures = 1 | 2 | 4 | 8 | 16 | 32 | 512

    private var previousServers: ServerManager!
    private var server: Server!
    private var connection: HAMockConnection!
    private var navigator: FakeCarPlayNavigator!
    private var viewModel: CarPlayClimateControlViewModel!
    private var sut: CarPlayClimateControlTemplate!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
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
        sut = nil
        viewModel = nil
        navigator = nil
        connection = nil
        server = nil
        previousServers = nil
        super.tearDown()
    }

    private func connectAPI() {
        let api = HomeAssistantAPI(server: server)
        let mock = HAMockConnection()
        api.connection = mock
        Current.cachedApis[server.identifier] = api
        connection = mock
    }

    private func attributes(features: Int? = nil, temperature: Double = 20) -> [String: Any] {
        [
            "friendly_name": "Hall",
            "supported_features": features ?? allFeatures,
            "hvac_modes": ["off", "heat", "mystery"],
            "temperature": temperature,
            "current_temperature": 19.0,
            "target_temp_low": 18.0,
            "target_temp_high": 24.0,
            "humidity": 40.0,
            "current_humidity": 45.0,
            "fan_modes": ["auto", "high"],
            "fan_mode": "auto",
            "swing_modes": ["on", "off"],
            "swing_mode": "off",
            "swing_horizontal_modes": ["left", "right"],
            "swing_horizontal_mode": "left",
            "preset_modes": ["eco", "boost"],
            "preset_mode": "eco",
        ]
    }

    private func entity(state: String = "heat", attributes: [String: Any]) throws -> HAEntity {
        try HAEntity(
            entityId: "climate.hall",
            state: state,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: attributes,
            context: .init(id: "", userId: "", parentId: "")
        )
    }

    private func makeSut(state: String = "heat", attributes: [String: Any]? = nil) throws {
        viewModel = try CarPlayClimateControlViewModel(
            server: server,
            entity: entity(state: state, attributes: attributes ?? self.attributes())
        )
        sut = CarPlayClimateControlTemplate(viewModel: viewModel)
        sut.navigatorOverride = navigator
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(condition(), "condition not met within 10 s", file: file, line: line)
    }

    private func services() -> [String] {
        connection.pendingRequests.compactMap { $0.request.data["service"] as? String }
    }

    @available(iOS 26.0, *)
    private func tiles() -> [CPListImageRowItem] {
        sut.template.sections.flatMap(\.items).compactMap { $0 as? CPListImageRowItem }
    }

    private func section(_ header: String) -> CPListSection? {
        sut.template.sections.first { $0.header == header }
    }

    func testEveryCapabilityShowsItsSection() throws {
        try makeSut()

        let headers = sut.template.sections.compactMap(\.header)
        XCTAssertEqual(headers, [
            L10n.Climate.Control.Temperature.title,
            L10n.Climate.Control.TemperatureLow.title,
            L10n.Climate.Control.TemperatureHigh.title,
            L10n.Climate.Control.Modes.title,
            L10n.Climate.Control.Humidity.title,
        ])
        let modes = CarPlayTestRows.listItems(sut.template).filter { $0.accessoryType == .disclosureIndicator }
        XCTAssertEqual(modes.map(\.text), [
            L10n.Climate.Control.Mode.title,
            L10n.Climate.Control.FanMode.title,
            L10n.Climate.Control.SwingMode.title,
            L10n.Climate.Control.SwingHorizontalMode.title,
            L10n.Climate.Control.PresetMode.title,
        ])
        XCTAssertNotNil(section(L10n.Climate.Control.Temperature.title)?.items.first as? CPListItem)
        let humidity = section(L10n.Climate.Control.Humidity.title)?.items.first as? CPListItem
        XCTAssertNotNil(humidity?.detailText)
    }

    func testAnEntityWithoutCapabilitiesShowsNoSections() throws {
        try makeSut(attributes: ["hvac_modes": [String]()])

        XCTAssertTrue(sut.template.sections.isEmpty)
    }

    /// Each +/- tile adjusts its value at once and sends it after the debounce window.
    func testTheStepperTilesSendTheirValues() throws {
        guard #available(iOS 26.0, *) else { return }
        connectAPI()
        // Steppers only: CarPlay drops rows past its item cap, and the mode rows would push the
        // humidity tiles past it.
        try makeSut(attributes: attributes(features: 1 | 2 | 4))
        let temperatureRow = section(L10n.Climate.Control.Temperature.title)?.items.first as? CPListItem
        let before = temperatureRow?.text

        let steppers = tiles()
        XCTAssertEqual(steppers.count, 4)
        for stepper in steppers {
            CarPlayTestRows.tapImageRow(stepper, index: 1)
            CarPlayTestRows.tapImageRow(stepper, index: 0)
            CarPlayTestRows.tapImageRow(stepper, index: 1)
        }
        XCTAssertNotEqual(temperatureRow?.text, before)

        // A snapshot that still carries the old values doesn't bounce the pending ones back.
        try sut.entitiesStateChange(
            serverId: server.identifier.rawValue,
            entities: HACachedStates(entitiesDictionary: [
                "climate.hall": entity(attributes: attributes(features: 1 | 2 | 4)),
            ])
        )
        XCTAssertNotEqual(temperatureRow?.text, before)

        waitUntil { self.services().count == 3 }
        XCTAssertEqual(Set(services()), ["set_temperature", "set_humidity"])
    }

    func testPickingAModeSendsItAndReturns() throws {
        connectAPI()
        try makeSut()
        let modeTitles = [
            L10n.Climate.Control.Mode.title,
            L10n.Climate.Control.FanMode.title,
            L10n.Climate.Control.SwingMode.title,
            L10n.Climate.Control.SwingHorizontalMode.title,
            L10n.Climate.Control.PresetMode.title,
        ]

        for title in modeTitles {
            CarPlayTestRows.tap(CarPlayTestRows.row(sut.template, title))
            let list = try XCTUnwrap(navigator.pushedTemplates.last as? CPListTemplate)
            XCTAssertEqual(list.title, title)
            let options = CarPlayTestRows.listItems(list)
            XCTAssertGreaterThanOrEqual(options.count, 2)
            CarPlayTestRows.tap(options.last)
        }

        XCTAssertEqual(navigator.popCount, modeTitles.count)
        XCTAssertEqual(services(), [
            "set_hvac_mode",
            "set_fan_mode",
            "set_swing_mode",
            "set_swing_horizontal_mode",
            "set_preset_mode",
        ])
    }

    /// Losing a capability rebuilds the screen; a value change only refreshes it in place.
    func testStateChangesRefreshOrRebuild() throws {
        try makeSut()
        let firstRow = CarPlayTestRows.listItems(sut.template).first

        try sut.entitiesStateChange(
            serverId: server.identifier.rawValue,
            entities: HACachedStates(entitiesDictionary: [
                "climate.hall": entity(attributes: attributes(temperature: 22)),
            ])
        )
        XCTAssertTrue(CarPlayTestRows.listItems(sut.template).first === firstRow)

        try sut.entitiesStateChange(
            serverId: "other",
            entities: HACachedStates(entitiesDictionary: [
                "climate.hall": entity(attributes: attributes(features: 0)),
            ])
        )
        XCTAssertTrue(CarPlayTestRows.listItems(sut.template).first === firstRow)

        try sut.entitiesStateChange(
            serverId: server.identifier.rawValue,
            entities: HACachedStates(entitiesDictionary: [
                "climate.hall": entity(state: "mystery", attributes: attributes(features: 0)),
            ])
        )
        XCTAssertEqual(sut.template.sections.compactMap(\.header), [L10n.Climate.Control.Modes.title])

        sut.templateWillDisappear(template: sut.template)
        sut.templateWillAppear(template: sut.template)
        XCTAssertEqual(sut.template.sections.count, 1)
    }
}
