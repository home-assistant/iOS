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
                entity: .make("switch.outlet_power", name: "Outlet power"),
                subtitle: "Kitchen • Outlet 2",
                icon: MaterialDesignIcons(named: "power_socket_eu")
            )
            // A child device's row says which hardware it belongs to, through the same context line.
            EntityRowView(
                entity: .make("sensor.outlet_energy", name: "Outlet energy"),
                subtitle: "Kitchen • Outlet 2 • Power strip",
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
