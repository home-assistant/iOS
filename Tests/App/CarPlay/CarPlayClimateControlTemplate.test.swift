import CarPlay
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The climate control screen: one group per capability the thermostat advertises, values that
/// follow the entity, and steppers/pickers that change it.
final class CarPlayClimateControlTemplateTests: XCTestCase {
    /// Target temperature, range, humidity, fan, preset, swing and horizontal swing.
    private static let allFeatures = 1 | 2 | 4 | 8 | 16 | 32 | 512

    private var previousServers: ServerManager!
    private var server: Server!
    private var connection: HAMockConnection!
    private var viewModel: CarPlayClimateControlViewModel!
    private var sut: CarPlayClimateControlTemplate!

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

    private func fullAttributes() -> [String: Any] {
        [
            "friendly_name": "Hall",
            "supported_features": Self.allFeatures,
            "hvac_modes": ["off", "heat", "cool"],
            "temperature": 20.0,
            "current_temperature": 19.0,
            "target_temp_low": 18.0,
            "target_temp_high": 24.0,
            "min_temp": 7.0,
            "max_temp": 35.0,
            "humidity": 45.0,
            "current_humidity": 50.0,
            "fan_modes": ["auto", "low"],
            "fan_mode": "auto",
            "swing_modes": ["off", "vertical"],
            "swing_mode": "off",
            "swing_horizontal_modes": ["off", "left_right"],
            "swing_horizontal_mode": "off",
            "preset_modes": ["home", "away"],
            "preset_mode": "home",
        ]
    }

    private func makeSut(attributes: [String: Any]) throws {
        let entity = try CarPlayTestHelpers.entity("climate.hall", state: "heat", attributes: attributes)
        viewModel = CarPlayClimateControlViewModel(server: server, entity: entity)
        sut = CarPlayClimateControlTemplate(viewModel: viewModel)
    }

    private var allItems: [any CPListTemplateItem] {
        CarPlayTestHelpers.items(of: sut.template)
    }

    private func section(headed header: String) throws -> CPListSection {
        try XCTUnwrap(sut.template.sections.first(where: { $0.header == header }), "No section \(header)")
    }

    /// The value row of a stepper group: the first row under the capability's header.
    private func valueRow(headed header: String) throws -> CPListItem {
        try XCTUnwrap(section(headed: header).items.first as? CPListItem)
    }

    /// Taps a stepper's +/-; `increase` picks which one, whichever way the OS renders them.
    private func step(headed header: String, increase: Bool) throws {
        let sections = sut.template.sections
        let index = try XCTUnwrap(sections.firstIndex(where: { $0.header == header }))
        if let tile = sections.indices.contains(index + 1)
            ? sections[index + 1].items.first as? CPListImageRowItem
            : nil {
            CarPlayTestHelpers.tap(tile, elementAt: increase ? 1 : 0)
        } else {
            let rows = sections[index].items.compactMap { $0 as? CPListItem }
            try CarPlayTestHelpers.tap(XCTUnwrap(rows.dropFirst(increase ? 1 : 2).first))
        }
    }

    private func modeRows() throws -> [CPListItem] {
        try section(headed: L10n.Climate.Control.Modes.title).items.compactMap { $0 as? CPListItem }
    }

    func testTheTitleIsTheEntityName() throws {
        try makeSut(attributes: fullAttributes())

        XCTAssertEqual(sut.template.title, "Hall")
    }

    func testEveryCapabilityGetsItsGroup() throws {
        try makeSut(attributes: fullAttributes())

        let headers = sut.template.sections.compactMap(\.header)
        XCTAssertEqual(headers, [
            L10n.Climate.Control.Temperature.title,
            L10n.Climate.Control.TemperatureLow.title,
            L10n.Climate.Control.TemperatureHigh.title,
            L10n.Climate.Control.Modes.title,
            L10n.Climate.Control.Humidity.title,
        ])
        XCTAssertEqual(try modeRows().map(\.text), [
            L10n.Climate.Control.Mode.title,
            L10n.Climate.Control.FanMode.title,
            L10n.Climate.Control.SwingMode.title,
            L10n.Climate.Control.SwingHorizontalMode.title,
            L10n.Climate.Control.PresetMode.title,
        ])
    }

    func testValuesFollowTheEntity() throws {
        try makeSut(attributes: fullAttributes())

        let temperature = try valueRow(headed: L10n.Climate.Control.Temperature.title)
        XCTAssertEqual(
            temperature.text,
            L10n.Climate.Control.targetValue(ClimateControlState.formatTemperature(20))
        )
        XCTAssertEqual(
            temperature.detailText,
            L10n.Climate.Control.currentValue(ClimateControlState.formatTemperature(19))
        )
        XCTAssertEqual(
            try valueRow(headed: L10n.Climate.Control.TemperatureLow.title).text,
            L10n.Climate.Control.targetValue(ClimateControlState.formatTemperature(18))
        )
        XCTAssertEqual(
            try valueRow(headed: L10n.Climate.Control.TemperatureHigh.title).text,
            L10n.Climate.Control.targetValue(ClimateControlState.formatTemperature(24))
        )
        let humidity = try valueRow(headed: L10n.Climate.Control.Humidity.title)
        XCTAssertEqual(humidity.text, L10n.Climate.Control.targetValue(ClimateControlState.formatHumidity(45)))
        XCTAssertEqual(
            humidity.detailText,
            L10n.Climate.Control.currentValue(ClimateControlState.formatHumidity(50))
        )
        XCTAssertEqual(try modeRows().map(\.detailText), [
            ClimateHvacMode.localizedTitle(forMode: "heat"),
            "Auto",
            "Off",
            "Off",
            "Home",
        ])
    }

    /// A thermostat that only reports its mode gets no steppers, and an unset target reads as a dash.
    func testAMinimalThermostatOnlyOffersWhatItSupports() throws {
        try makeSut(attributes: ["supported_features": 1])

        XCTAssertEqual(sut.template.sections.compactMap(\.header), [L10n.Climate.Control.Temperature.title])
        let temperature = try valueRow(headed: L10n.Climate.Control.Temperature.title)
        XCTAssertEqual(temperature.text, L10n.Climate.Control.targetValue("—"))
        XCTAssertNil(temperature.detailText)
    }

    func testSteppersAdjustTheTargets() throws {
        try makeSut(attributes: fullAttributes())

        try step(headed: L10n.Climate.Control.Temperature.title, increase: true)
        XCTAssertEqual(viewModel.control.targetTemperature, 20.5)
        XCTAssertEqual(
            try valueRow(headed: L10n.Climate.Control.Temperature.title).text,
            L10n.Climate.Control.targetValue(ClimateControlState.formatTemperature(20.5))
        )
        try step(headed: L10n.Climate.Control.Temperature.title, increase: false)
        XCTAssertEqual(viewModel.control.targetTemperature, 20)

        try step(headed: L10n.Climate.Control.TemperatureLow.title, increase: true)
        XCTAssertEqual(viewModel.control.targetTemperatureLow, 18.5)
        try step(headed: L10n.Climate.Control.TemperatureLow.title, increase: false)
        XCTAssertEqual(viewModel.control.targetTemperatureLow, 18)

        try step(headed: L10n.Climate.Control.TemperatureHigh.title, increase: false)
        XCTAssertEqual(viewModel.control.targetTemperatureHigh, 23.5)
        try step(headed: L10n.Climate.Control.TemperatureHigh.title, increase: true)
        XCTAssertEqual(viewModel.control.targetTemperatureHigh, 24)

        try step(headed: L10n.Climate.Control.Humidity.title, increase: true)
        XCTAssertEqual(viewModel.control.targetHumidity, 50)
        try step(headed: L10n.Climate.Control.Humidity.title, increase: false)
        XCTAssertEqual(viewModel.control.targetHumidity, 45)

        // Adjustments are debounced; nothing is sent while the driver is still tapping.
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// The range bounds can't cross: raising the low bound stops at the high one.
    func testTheLowBoundCannotPassTheHighOne() throws {
        var attributes = fullAttributes()
        attributes["target_temp_low"] = 24.0
        try makeSut(attributes: attributes)

        try step(headed: L10n.Climate.Control.TemperatureLow.title, increase: true)

        XCTAssertEqual(viewModel.control.targetTemperatureLow, 24)
    }

    func testModesAreSentRightAway() throws {
        try makeSut(attributes: fullAttributes())

        viewModel.setHvacMode("cool")
        viewModel.setFanMode("low")
        viewModel.setSwingMode("vertical")
        viewModel.setSwingHorizontalMode("left_right")
        viewModel.setPresetMode("away")

        XCTAssertEqual(connection.pendingRequests.count, 5)
        XCTAssertEqual(try modeRows().map(\.detailText), [
            ClimateHvacMode.localizedTitle(forMode: "cool"),
            "Low",
            "Vertical",
            "Left right",
            "Away",
        ])
    }

    /// Opening a mode picker needs a CarPlay screen to push onto; without one nothing changes.
    func testOpeningTheModePickersChangesNothing() throws {
        try makeSut(attributes: fullAttributes())

        for row in try modeRows() {
            CarPlayTestHelpers.tap(row)
        }

        XCTAssertTrue(connection.pendingRequests.isEmpty)
        XCTAssertEqual(viewModel.control.hvacMode, "heat")
    }

    /// A state update with the same capabilities refreshes the rows in place; one with different
    /// capabilities rebuilds the screen.
    func testStateUpdatesRefreshOrRebuild() throws {
        try makeSut(attributes: fullAttributes())
        let sectionsBefore = sut.template.sections.count
        let temperatureRow = try valueRow(headed: L10n.Climate.Control.Temperature.title)

        var warmer = fullAttributes()
        warmer["temperature"] = 22.0
        let updated = try CarPlayTestHelpers.entity("climate.hall", state: "heat", attributes: warmer)
        sut.entitiesStateChange(
            serverId: server.identifier.rawValue,
            entities: CarPlayTestHelpers.states([updated])
        )

        XCTAssertEqual(sut.template.sections.count, sectionsBefore)
        XCTAssertTrue(try valueRow(headed: L10n.Climate.Control.Temperature.title) === temperatureRow)
        XCTAssertEqual(
            temperatureRow.text,
            L10n.Climate.Control.targetValue(ClimateControlState.formatTemperature(22))
        )

        let simpler = try CarPlayTestHelpers.entity("climate.hall", state: "off", attributes: ["supported_features": 1])
        sut.entitiesStateChange(
            serverId: server.identifier.rawValue,
            entities: CarPlayTestHelpers.states([simpler])
        )
        XCTAssertEqual(sut.template.sections.compactMap(\.header), [L10n.Climate.Control.Temperature.title])
    }

    func testUpdatesForAnotherServerOrEntityAreIgnored() throws {
        try makeSut(attributes: fullAttributes())
        let other = try CarPlayTestHelpers.entity("climate.hall", state: "off", attributes: ["supported_features": 1])

        let unrelated = try CarPlayTestHelpers.entity("climate.other")

        sut.entitiesStateChange(serverId: "other", entities: CarPlayTestHelpers.states([other]))
        sut.entitiesStateChange(serverId: server.identifier.rawValue, entities: CarPlayTestHelpers.states([unrelated]))

        XCTAssertEqual(viewModel.control.hvacMode, "heat")
        XCTAssertEqual(sut.template.sections.compactMap(\.header).count, 5)
    }

    func testAppearingRefreshesTheValues() throws {
        try makeSut(attributes: fullAttributes())
        let before = sut.template.sections.count

        sut.templateWillAppear(template: sut.template)
        sut.templateWillDisappear(template: sut.template)
        sut.templateWillAppear(template: CPListTemplate(title: "Other", sections: []))

        XCTAssertEqual(sut.template.sections.count, before)
    }
}
