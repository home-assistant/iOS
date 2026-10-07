import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct EntityContextParentDeviceTests {
    private static let serverId = "A"

    @available(iOS 18, *)
    @Test func everyEntityPickerNamesThePowerStripAnOutletIsPartOf() async throws {
        try await withSeededDatabase {
            let readableOptions = try await ReadableEntityOptionsProvider().results().sections
                .flatMap(\.items)
                .map(\.value)
            let subtitles: [String: String?] = try await [
                "IntentLight": IntentLightAppEntityQuery().entities(for: [id("light.outlet_1")]).first?
                    .contextSubtitle,
                "IntentSwitch": IntentSwitchAppEntityQuery().entities(for: [id("switch.outlet_1")]).first?
                    .contextSubtitle,
                "IntentCover": IntentCoverAppEntityQuery().entities(for: [id("cover.outlet_1")]).first?
                    .contextSubtitle,
                "IntentFan": IntentFanAppEntityQuery().entities(for: [id("fan.outlet_1")]).first?
                    .contextSubtitle,
                "IntentAutomation": IntentAutomationAppEntityQuery().entities(for: [id("automation.outlet_1")])
                    .first?.contextSubtitle,
                "IntentScene": IntentSceneAppEntityQuery().entities(for: [id("scene.outlet_1")]).first?
                    .contextSubtitle,
                "IntentScript": IntentScriptAppEntityQuery().entities(for: [id("script.outlet_1")]).first?
                    .contextSubtitle,
                "IntentSensors": IntentSensorsAppEntityQuery().entities(for: [id("sensor.outlet_1")]).first?
                    .contextSubtitle,
                "DimmableLight": DimmableLightAppEntityQuery().entities(for: [id("light.outlet_1")]).first?
                    .contextSubtitle,
                "Lock": LockAppEntityQuery().entities(for: [id("lock.outlet_1")]).first?.contextSubtitle,
                "Thermostat": ThermostatAppEntityQuery().entities(for: [id("climate.outlet_1")]).first?
                    .contextSubtitle,
                "Openable": OpenableEntityAppEntityQuery().entities(for: [id("cover.outlet_1")]).first?
                    .contextSubtitle,
                "Controllable": ControllableEntityAppEntityQuery().entities(for: [id("switch.outlet_1")]).first?
                    .contextSubtitle,
                "Readable": ReadableEntityAppEntityQuery().entities(for: [id("sensor.outlet_1")]).first?
                    .contextSubtitle,
                "ReadableOptions": readableOptions.first { $0.entityId == "sensor.outlet_1" }?.contextSubtitle,
                "WidgetEntities": WidgetEntitiesAppEntityQuery().entities(for: [id("light.outlet_1")]).first?
                    .contextSubtitle,
                "AnyEntity": HAAppEntityAppIntentEntityQuery().entities(for: [id("light.outlet_1")]).first?
                    .subtitle,
            ]

            for (picker, subtitle) in subtitles {
                #expect(subtitle == "Living room ▸ Power strip ▸ Outlet 1", "\(picker)")
            }
        }
    }

    @available(iOS 18, *)
    @Test func anOutletWithAnAreaOfItsOwnLeavesThePowerStripOut() async throws {
        try await withSeededDatabase {
            let outlet = try await IntentSwitchAppEntityQuery().entities(for: [id("switch.outlet_2")]).first

            #expect(outlet?.contextSubtitle == "Kitchen ▸ Outlet 2")
        }
    }

    @available(iOS 18, *)
    @Test func anEntityWithAnAreaOfItsOwnNamesNoneOfItsDevices() async throws {
        try await withSeededDatabase {
            let freezer = try await IntentSwitchAppEntityQuery().entities(for: [id("switch.freezer")]).first
            let anyEntity = try await HAAppEntityAppIntentEntityQuery().entities(for: [id("switch.freezer")]).first
            let provider = MagicItemProvider()
            _ = await provider.loadInformation()
            let info = provider.getInfo(for: .init(id: "switch.freezer", serverId: Self.serverId, type: .entity))
            let row = try HAAppEntity.config().first { $0.entityId == "switch.freezer" }

            #expect(freezer?.contextSubtitle == "Garage")
            #expect(anyEntity?.subtitle == "Garage")
            #expect(info?.contextSubtitle == "Garage")
            #expect(row?.contextualSubtitle == "Garage")
            #expect(anyEntity?.deviceName == "Outlet 1")
            #expect(anyEntity?.parentDeviceName == "Power strip")
        }
    }

    @Test func magicItemsNameThePowerStripAnOutletIsPartOf() async throws {
        try await withSeededDatabase {
            let provider = MagicItemProvider()
            _ = await provider.loadInformation()

            let info = provider.getInfo(for: .init(id: "light.outlet_1", serverId: Self.serverId, type: .entity))

            #expect(info?.contextSubtitle == "Living room ▸ Power strip ▸ Outlet 1")
        }
    }

    @Test func rowsOutsideThePickerNameThePowerStripAnOutletIsPartOf() async throws {
        try await withSeededDatabase {
            let outletLight = try HAAppEntity.config().first { $0.entityId == "light.outlet_1" }

            #expect(outletLight?.contextualSubtitle == "Living room ▸ Power strip ▸ Outlet 1")
        }
    }

    private func id(_ entityId: String) -> String {
        "\(Self.serverId)-\(entityId)"
    }

    private func withSeededDatabase(_ body: () async throws -> Void) async throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        let database = try DatabaseQueue(path: ":memory:")
        try HAppEntityTable().createIfNeeded(database: database)
        try AppAreaTable().createIfNeeded(database: database)
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        try AppDeviceRegistryTable().createIfNeeded(database: database)
        Current.database = { database }

        let servers = FakeServerManager()
        servers.add(identifier: .init(rawValue: Self.serverId), serverInfo: .fake())
        Current.servers = servers

        let outletEntityIds = [
            "light.outlet_1",
            "switch.outlet_1",
            "cover.outlet_1",
            "fan.outlet_1",
            "automation.outlet_1",
            "scene.outlet_1",
            "script.outlet_1",
            "sensor.outlet_1",
            "lock.outlet_1",
            "climate.outlet_1",
        ]

        try await database.write { db in
            try AppDeviceRegistry.makeTest(
                areaId: "living_room",
                deviceId: "strip",
                serverId: Self.serverId,
                name: "Strip 4000",
                nameByUser: "Power strip",
                nextNamePart: "area"
            ).insert(db)
            try AppDeviceRegistry.makeTest(
                areaId: nil,
                deviceId: "outlet_1",
                serverId: Self.serverId,
                name: "Outlet 1",
                nextNamePart: "parent_device",
                parentDeviceId: "strip"
            ).insert(db)
            try AppDeviceRegistry.makeTest(
                areaId: "kitchen",
                deviceId: "outlet_2",
                serverId: Self.serverId,
                name: "Outlet 2",
                nextNamePart: "area",
                parentDeviceId: "strip"
            ).insert(db)

            for entityId in outletEntityIds {
                try Self.entity(entityId, name: "Outlet 1 \(entityId.split(separator: ".")[0])").insert(db)
                try EntityRegistryListForDisplay.Entity(
                    serverId: Self.serverId,
                    entityId: entityId,
                    deviceId: "outlet_1",
                    nextNamePart: "device"
                ).insert(db)
            }
            try Self.entity("switch.outlet_2", name: "Outlet 2 switch").insert(db)
            try EntityRegistryListForDisplay.Entity(
                serverId: Self.serverId,
                entityId: "switch.outlet_2",
                deviceId: "outlet_2",
                nextNamePart: "device"
            ).insert(db)
            try Self.entity("switch.freezer", name: "Freezer").insert(db)
            try EntityRegistryListForDisplay.Entity(
                serverId: Self.serverId,
                entityId: "switch.freezer",
                deviceId: "outlet_1",
                areaId: "garage",
                nextNamePart: "area"
            ).insert(db)

            try Self.area("living_room", name: "Living room", entities: Set(outletEntityIds)).insert(db)
            try Self.area("kitchen", name: "Kitchen", entities: ["switch.outlet_2"]).insert(db)
            try Self.area("garage", name: "Garage", entities: ["switch.freezer"]).insert(db)
        }

        try await body()
    }

    private static func entity(_ entityId: String, name: String) -> HAAppEntity {
        HAAppEntity(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            domain: String(entityId.split(separator: ".")[0]),
            name: name,
            icon: nil,
            rawDeviceClass: nil
        )
    }

    private static func area(_ areaId: String, name: String, entities: Set<String>) -> AppArea {
        AppArea(
            id: "\(serverId)-\(areaId)",
            serverId: serverId,
            areaId: areaId,
            name: name,
            aliases: [],
            picture: nil,
            icon: nil,
            sortOrder: nil,
            entities: entities
        )
    }
}
