@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// Snapshots `WatchComplicationConfigurationSheet` for the corner family with its gauge enabled, so the
/// new Gauge/Progress segmented control — its localized titles and selected state — has UI coverage.
/// The builder-flow snapshot (`WatchComplicationBuilderEditViewSnapshotTests`) stops before this sheet,
/// and the on-face rendering is covered by the corner content-view snapshots; this guards the editor UI.
@MainActor
struct WatchComplicationConfigurationSheetSnapshotTests {
    @Test func cornerGaugeDisplayPicker() {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)
        let serverId = Current.servers.all.first?.identifier.rawValue ?? ""
        // A corner entity gauge: the range turns the gauge on, so the Gauge/Progress segmented control
        // (corner-only) is shown, defaulting to the Gauge selection.
        let config = WatchComplicationConfig(
            serverId: serverId,
            widgetFamily: .corner,
            entityId: "sensor.battery",
            entityDisplayName: "Battery",
            iconName: "mdi:battery",
            gaugeMin: 0,
            gaugeMax: 100
        )
        assertLightDarkSnapshots(
            of: WatchComplicationConfigurationSheet(
                viewModel: WatchComplicationBuilderEditViewModel(existing: config)
            ),
            drawHierarchyInKeyWindow: true
        )
    }
}
