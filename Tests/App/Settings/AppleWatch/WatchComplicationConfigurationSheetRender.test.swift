import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the complication configuration sheet out in each shape it takes: an entity complication with
/// every value option (attributes, decimals, unit), customized slot formulas and per-slot colors, the
/// circular gauge with its style picker, a template complication driving its colors from templates,
/// and the gauge-less inline family. Templates are plain text so nothing reaches for a server.
@MainActor
@Suite(.serialized)
struct WatchComplicationConfigurationSheetRenderTests {
    @Test func rendersARectangularEntityComplicationWithEveryOption() throws {
        try withWorld { serverId in
            var config = WatchComplicationConfig(
                serverId: serverId,
                widgetFamily: .rectangular,
                entityId: "sensor.battery",
                entityDisplayName: "Battery",
                iconName: "mdi:battery",
                iconColor: "#34C759",
                valueAttribute: "battery_level",
                valuePrecision: 1,
                unitOverride: "pct",
                gaugeMin: 0,
                gaugeMax: 100,
                showMin: true,
                showMax: true
            )
            config.setSlotConfig(
                ComplicationSlotConfig(
                    isVisible: true,
                    formula: ComplicationFormula(parts: [
                        .text("Level "),
                        .entityName,
                        .attribute("battery_level"),
                        .state,
                    ])
                ),
                slot: .title,
                for: .rectangular
            )
            config.setSlotConfig(
                ComplicationSlotConfig(isVisible: true, color: "#FF0000"),
                slot: .bottomText,
                for: .rectangular
            )
            config.setSlotConfig(
                ComplicationSlotConfig(isVisible: true, formula: ComplicationFormula(parts: [.text("Only")])),
                slot: .subtitle,
                for: .rectangular
            )

            let viewModel = WatchComplicationBuilderEditViewModel(existing: config)
            viewModel.entityAttributeKeys = ["battery_level", "friendly_name"]
            viewModel.valueIsNumeric = true
            viewModel.entityUnit = "%"

            #expect(viewModel.config.isSlotVisible(.bottomText, for: .rectangular))
            #expect(viewModel.config.slotColor(.bottomText, for: .rectangular) == "#FF0000")
            #expect(render(WatchComplicationConfigurationSheet(viewModel: viewModel)))
        }
    }

    @Test func rendersTheCircularGaugeWithItsStylePicker() throws {
        try withWorld { serverId in
            var config = WatchComplicationConfig(
                serverId: serverId,
                widgetFamily: .circular,
                entityId: "sensor.humidity",
                gaugeMin: 0,
                gaugeMax: 100
            )
            config.setOptions(
                WatchComplicationConfig.FamilyOptions(
                    showIcon: true,
                    showGauge: true,
                    tint: "#64D2FF",
                    gaugeStyle: WatchComplicationConfig.GaugeStyle.capacity.rawValue
                ),
                for: .circular
            )
            let viewModel = WatchComplicationBuilderEditViewModel(existing: config)

            #expect(viewModel.config.showsGauge(for: .circular))
            #expect(viewModel.config.gaugeStyle(for: .circular) == .capacity)
            #expect(render(WatchComplicationConfigurationSheet(viewModel: viewModel)))
        }
    }

    @Test func rendersATemplateComplicationWithTemplateColors() throws {
        try withWorld { serverId in
            var config = WatchComplicationConfig(
                serverId: serverId,
                widgetFamily: .corner,
                kind: .customTemplate,
                iconName: "mdi:solar-power",
                customTextTemplate: "Solar",
                customGaugeTemplate: "0.5",
                customGaugeColorTemplate: "#FF9500",
                customIconColorTemplate: "#FFD60A",
                customTextColorTemplate: "#FFFFFF"
            )
            config.setSlotConfig(
                ComplicationSlotConfig(
                    isVisible: true,
                    formula: ComplicationFormula(parts: [.template("Solar"), .text(" kW")])
                ),
                slot: .value,
                for: .corner
            )
            var cornerOptions = config.options(for: .corner)
            cornerOptions.showIcon = true
            cornerOptions.showGauge = true
            config.setOptions(cornerOptions, for: .corner)
            let viewModel = WatchComplicationBuilderEditViewModel(existing: config)

            #expect(viewModel.useTemplateColor)
            #expect(render(WatchComplicationConfigurationSheet(viewModel: viewModel)))
        }
    }

    @Test func rendersTheInlineFamilyWithoutAGauge() throws {
        try withWorld { serverId in
            let config = WatchComplicationConfig(
                serverId: serverId,
                widgetFamily: .inline,
                kind: .customTemplate,
                customTextTemplate: "Inline"
            )
            let viewModel = WatchComplicationBuilderEditViewModel(existing: config)

            #expect(!viewModel.useTemplateColor)
            #expect(render(WatchComplicationConfigurationSheet(viewModel: viewModel)))
        }
    }

    @Test func rendersANewComplicationWithoutAnEntity() throws {
        try withWorld { _ in
            let viewModel = WatchComplicationBuilderEditViewModel(existing: nil)
            #expect(viewModel.config.entityId == nil)
            #expect(render(WatchComplicationConfigurationSheet(viewModel: viewModel)))
        }
    }

    @Test func everySlotHasALocalizedEditorTitle() {
        let titles = ComplicationSlot.allCases.map(\.editorTitle)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == ComplicationSlot.allCases.count)
    }

    // MARK: - Helpers

    private func withWorld(_ work: (String) throws -> Void) throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        let servers = FakeServerManager(initial: 1)
        Current.database = { database }
        Current.servers = servers
        try work(servers.all.first?.identifier.rawValue ?? "")
    }

    /// Deliberately never becomes the key window, so it can't leak into snapshot tests. Returns
    /// whether the hosted view was laid out in the window.
    private func render(_ view: some View) -> Bool {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 2400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let laidOut = controller.view.window === window

        window.isHidden = true
        window.rootViewController = nil
        return laidOut
    }
}
