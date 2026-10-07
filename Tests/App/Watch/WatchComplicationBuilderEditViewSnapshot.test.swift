@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// Snapshots the watch-complication builder, which is only the source flow — name, source, entity or
/// template — with the live preview on top; the rendering options now live behind the Customize row in
/// `WatchComplicationConfigurationSheet`. The flow reveals itself step by step, so two states are
/// captured: the initial screen (source picker + live preview) and an existing rectangular entity
/// complication, whose source is already set so the Customize row is reachable.
///
/// Only the first screenful is captured — the form is scrollable — so these guard the top of the flow
/// and the preview; the on-face rendering itself is covered by the complication content-view snapshots.
@MainActor
struct WatchComplicationBuilderEditViewSnapshotTests {
    @Test func newComplicationBuilder() {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)
        assertLightDarkSnapshots(
            of: NavigationView { WatchComplicationBuilderEditView(existing: nil) },
            drawHierarchyInKeyWindow: true
        )
    }

    @Test func editingRectangularEntity() {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)
        let serverId = Current.servers.all.first?.identifier.rawValue ?? ""
        let config = WatchComplicationConfig(
            serverId: serverId,
            widgetFamily: .rectangular,
            entityId: "sensor.battery",
            entityDisplayName: "Battery",
            iconName: "mdi:battery",
            gaugeMin: 0,
            gaugeMax: 100
        )
        assertSnapshot(
            of: NavigationView { WatchComplicationBuilderEditView(existing: config) },
            drawHierarchyInKeyWindow: true,
            named: "rectangular-entity"
        )
    }
}
