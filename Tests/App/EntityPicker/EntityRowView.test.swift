import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// The entity picker's row. A long list resolves every row's context line and glyph up front and
/// hands them over, so the rows here are drawn from given content rather than resolving their own.
struct EntityRowViewTests {
    @MainActor
    @Test func rowsShowTheirNameContextAndGlyph() async throws {
        let view = List {
            EntityRowView(
                entity: .make("switch.kettle_plug", name: "Kettle plug"),
                subtitle: "Kitchen ▸ Smart plug",
                icon: MaterialDesignIcons(named: "power_socket_eu")
            )
            // A child device's row says which hardware it belongs to, through the same context line.
            EntityRowView(
                entity: .make("sensor.outlet_energy", name: "Outlet energy"),
                subtitle: "Kitchen ▸ Power strip ▸ Outlet 2",
                icon: MaterialDesignIcons(named: "lightning_bolt")
            )
            // An entity the registry attributes to no area and no device has nothing to add.
            EntityRowView(
                entity: .make("input_boolean.guest_mode", name: "Guest mode"),
                subtitle: nil,
                icon: MaterialDesignIcons(named: "toggle_switch_variant")
            )
            EntityRowView(
                entity: .make("light.kitchen", name: "Kitchen light"),
                subtitle: "Kitchen",
                icon: MaterialDesignIcons(named: "lightbulb"),
                isSelected: true
            )
        }
        .listStyle(.plain)

        assertLightDarkSnapshots(of: view, drawHierarchyInKeyWindow: true)
    }

    /// The rows outside the picker keep resolving their own content: with nothing in the registry
    /// there is no context to add, and the glyph still falls back to the domain's.
    @MainActor
    @Test func rowResolvesItsOwnContentWhenNoneIsGiven() async throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        try AppDeviceRegistryTable().createIfNeeded(database: database)
        try AppAreaTable().createIfNeeded(database: database)
        Current.database = { database }
        defer { Current.database = previousDatabase }

        let view = List {
            EntityRowView(entity: .make("light.kitchen", name: "Kitchen light"))
            EntityRowView(optionalTitle: "Every entity")
        }
        .listStyle(.plain)

        assertLightDarkSnapshots(of: view, drawHierarchyInKeyWindow: true)
    }

    @MainActor
    @Test func rowsNameThePowerStripTheirOutletIsPartOf() async throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        try AppDeviceRegistryTable().createIfNeeded(database: database)
        try AppAreaTable().createIfNeeded(database: database)
        Current.database = { database }
        defer { Current.database = previousDatabase }

        try await database.write { db in
            try AppDeviceRegistry.makeTest(
                areaId: "living_room",
                deviceId: "strip",
                serverId: "1",
                name: "Power strip"
            ).insert(db)
            try AppDeviceRegistry.makeTest(
                areaId: nil,
                deviceId: "outlet_1",
                serverId: "1",
                name: "Outlet 1",
                parentDeviceId: "strip"
            ).insert(db)
            try AppDeviceRegistry.makeTest(
                areaId: "kitchen",
                deviceId: "outlet_2",
                serverId: "1",
                name: "Outlet 2",
                parentDeviceId: "strip"
            ).insert(db)
            for (entityId, deviceId) in [
                ("switch.strip_usb", "strip"),
                ("switch.outlet_1", "outlet_1"),
                ("switch.outlet_2", "outlet_2"),
            ] {
                try EntityRegistryListForDisplay.Entity(serverId: "1", entityId: entityId, deviceId: deviceId)
                    .insert(db)
            }
            try EntityRegistryListForDisplay.Entity(
                serverId: "1",
                entityId: "switch.outlet_1_freezer",
                deviceId: "outlet_1",
                areaId: "garage"
            ).insert(db)
            try AppArea.make("living_room", name: "Living room", entities: ["switch.strip_usb", "switch.outlet_1"])
                .insert(db)
            try AppArea.make("kitchen", name: "Kitchen", entities: ["switch.outlet_2"]).insert(db)
            try AppArea.make("garage", name: "Garage", entities: ["switch.outlet_1_freezer"]).insert(db)
        }

        let view = List {
            EntityRowView(entity: .make("switch.strip_usb", name: "USB ports"))
            EntityRowView(entity: .make("switch.outlet_1", name: "Coffee machine"))
            EntityRowView(entity: .make("switch.outlet_2", name: "Kettle"))
            EntityRowView(entity: .make("switch.outlet_1_freezer", name: "Freezer"))
        }
        .listStyle(.plain)

        assertLightDarkSnapshots(of: view, drawHierarchyInKeyWindow: true)
    }
}

private extension AppArea {
    static func make(_ areaId: String, name: String, entities: Set<String>) -> AppArea {
        .init(
            id: "1-\(areaId)",
            serverId: "1",
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

private extension HAAppEntity {
    static func make(_ entityId: String, name: String) -> HAAppEntity {
        .init(
            id: "1-\(entityId)",
            entityId: entityId,
            serverId: "1",
            domain: entityId.components(separatedBy: ".").first ?? "",
            name: name,
            icon: nil,
            rawDeviceClass: nil
        )
    }
}
