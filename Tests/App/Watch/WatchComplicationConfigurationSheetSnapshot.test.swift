@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// Snapshots `WatchComplicationConfigurationSheet` for the corner family with its gauge enabled, so the
/// new Gauge/Progress segmented control — its localized titles and selected state — has UI coverage.
/// The builder-flow snapshot (`WatchComplicationBuilderEditViewSnapshotTests`) stops before this sheet,
/// and the on-face rendering is covered by the corner content-view snapshots; this guards the editor UI.
@MainActor
@Suite(.serialized)
struct WatchComplicationConfigurationSheetSnapshotTests {
    @Test func templateEndpointControls() {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)
        let config = WatchComplicationConfig(
            serverId: Current.servers.all.first!.identifier.rawValue,
            widgetFamily: .circular,
            kind: .customTemplate,
            customTextTemplate: "21.5°",
            customGaugeTemplate: "0.64",
            families: ["circular": .init(showGauge: true, minLabelTemplate: "12", maxLabelTemplate: "26")]
        )
        assertLightDarkSnapshots(
            of: WatchComplicationConfigurationSheet(
                viewModel: WatchComplicationBuilderEditViewModel(existing: config)
            ),
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 1800)
        )
    }

    @Test func endpointEditsStayIndependentAcrossFamilies() {
        let viewModel = WatchComplicationBuilderEditViewModel(existing: WatchComplicationConfig(
            serverId: "server",
            kind: .customTemplate,
            families: ["corner": .init(minLabelTemplate: "corner low", maxLabelTemplate: "corner high")]
        ))
        let sheet = WatchComplicationConfigurationSheet(viewModel: viewModel)
        let minimum = sheet.gaugeLabelTemplateBinding(\.minLabelTemplate)
        let maximum = sheet.gaugeLabelTemplateBinding(\.maxLabelTemplate)
        #expect(minimum.wrappedValue.isEmpty)
        minimum.wrappedValue = "{{ low }}"
        maximum.wrappedValue = "{{ high }}"
        #expect(minimum.wrappedValue == "{{ low }}")
        #expect(maximum.wrappedValue == "{{ high }}")
        minimum.wrappedValue = ""
        #expect(viewModel.config.options(for: .circular).minLabelTemplate == nil)
        #expect(maximum.wrappedValue == "{{ high }}")
        #expect(viewModel.config.options(for: .corner).minLabelTemplate == "corner low")
        #expect(viewModel.config.options(for: .corner).maxLabelTemplate == "corner high")
    }

    @Test func templatePreviewKeepsEndpointLabels() throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)
        let server = try #require(Current.servers.all.first)
        var config = WatchComplicationConfig(
            serverId: server.identifier.rawValue,
            kind: .customTemplate,
            customTextTemplate: "21.5°",
            customGaugeTemplate: "0.64"
        )
        for family in WatchComplicationConfig.Family.allCases {
            config.setOptions(
                .init(
                    showName: false,
                    showIcon: false,
                    showGauge: true,
                    minLabelTemplate: "12",
                    maxLabelTemplate: "26"
                ),
                for: family
            )
        }
        assertLightDarkSnapshots(
            of: AllFamiliesComplicationPreview(config: config, server: server, selectedFamily: .circular)
        )
    }

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
