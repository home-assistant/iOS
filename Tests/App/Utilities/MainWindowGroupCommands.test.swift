@testable import HomeAssistant
@testable import Shared
import Testing

struct MainWindowGroupCommandsTests {
    @Test func outletsNestUnderThePowerStripTheyArePartOf() {
        let devicesById = Dictionary(
            [
                AppDeviceRegistry.makeTest(areaId: "living_room", deviceId: "strip", name: "Power strip"),
                AppDeviceRegistry.makeTest(
                    areaId: nil,
                    deviceId: "outlet_1",
                    name: "Outlet 1",
                    parentDeviceId: "strip"
                ),
                AppDeviceRegistry.makeTest(
                    areaId: nil,
                    deviceId: "outlet_2",
                    name: "Outlet 2",
                    parentDeviceId: "strip"
                ),
                AppDeviceRegistry.makeTest(areaId: "living_room", deviceId: "lamp", name: "Arc lamp"),
            ].map { ($0.deviceId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let entities: [EntityRegistryListForDisplay.Entity] = [
            .init(entityId: "switch.outlet_2", deviceId: "outlet_2", name: "Kettle"),
            .init(entityId: "switch.outlet_1", deviceId: "outlet_1", name: "Coffee machine"),
            .init(entityId: "sensor.outlet_1_power", deviceId: "outlet_1", name: "Coffee machine power"),
            .init(entityId: "light.lamp", deviceId: "lamp", name: "Lamp"),
            .init(entityId: "input_boolean.guests", name: "Guests"),
        ]

        let devices = MainWindowGroupCommands.DataSource.devices(
            from: entities,
            areaId: "living_room",
            devicesById: devicesById
        )

        let topLevelNames = devices.map(\.name)
        #expect(topLevelNames == ["Arc lamp", "Power strip", L10n.MainWindowGroupCommands.OtherEntities.title])
        let strip = devices.first { $0.id == "strip" }
        #expect(strip?.domains.isEmpty == true)
        let outletNames = strip?.children.map(\.name)
        #expect(outletNames == ["Outlet 1", "Outlet 2"])
        let outletDomains = strip?.children.first?.domains.map(\.id).sorted()
        #expect(outletDomains == ["sensor", "switch"])
    }

    @Test func anOutletInAnotherAreaStandsOnItsOwn() {
        let devicesById = Dictionary(
            [
                AppDeviceRegistry.makeTest(areaId: "living_room", deviceId: "strip", name: "Power strip"),
                AppDeviceRegistry.makeTest(
                    areaId: "kitchen",
                    deviceId: "outlet_3",
                    name: "Outlet 3",
                    parentDeviceId: "strip"
                ),
            ].map { ($0.deviceId, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let devices = MainWindowGroupCommands.DataSource.devices(
            from: [.init(entityId: "switch.outlet_3", deviceId: "outlet_3", name: "Toaster")],
            areaId: "kitchen",
            devicesById: devicesById
        )

        let names = devices.map(\.name)
        #expect(names == ["Outlet 3"])
        #expect(devices.first?.children.isEmpty == true)
    }
}
