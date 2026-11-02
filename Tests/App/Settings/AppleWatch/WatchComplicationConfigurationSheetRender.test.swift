import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Drives the complication customization sheet through every size, both kinds of complication and
/// custom slot content, flipping its toggles and segmented pickers so their bindings run.
/// Shared state: the sheet resolves its server through `Current.servers` and its template previews
/// look their API up through `Current.api(for:)` from the main run loop.
@Suite(.sharedState)
@MainActor
struct WatchComplicationConfigurationSheetRenderTests {
    private static let customFormula = ComplicationFormula(parts: [
        .text("Now "),
        .entityName,
        .state,
        .attribute("temperature"),
        .template("{{ 1 }}"),
    ])

    private func config(kind: WatchComplicationConfig.Kind, serverId: String) -> WatchComplicationConfig {
        var config = WatchComplicationConfig(
            serverId: serverId,
            kind: kind,
            entityId: kind == .entity ? "sensor.outside" : nil,
            entityDisplayName: "Outside",
            iconName: "thermometer",
            iconColor: "#ff0000",
            textColor: "#ffffff",
            unitOverride: kind == .entity ? "°C" : nil,
            gaugeMin: 0,
            gaugeMax: 40,
            showUnit: true,
            showMin: true,
            showMax: true,
            customTextTemplate: kind == .customTemplate ? "{{ 21 }}" : nil,
            customGaugeTemplate: kind == .customTemplate ? "{{ 0.5 }}" : nil,
            customGaugeColorTemplate: kind == .customTemplate ? "{{ 'red' }}" : nil,
            customIconColorTemplate: kind == .customTemplate ? "{{ 'blue' }}" : nil,
            customTextColorTemplate: kind == .customTemplate ? "{{ 'white' }}" : nil
        )
        for family in WatchComplicationConfig.Family.allCases {
            config.setOptions(
                .init(
                    showName: true,
                    showValue: true,
                    showIcon: true,
                    showGauge: true,
                    showMin: true,
                    showMax: true,
                    minLabelTemplate: "{{ 0 }}",
                    maxLabelTemplate: "{{ 40 }}",
                    gaugeMin: 0,
                    gaugeMax: 40,
                    tint: "#00ff00",
                    gaugeStyle: "capacity",
                    cornerGaugeDisplay: "progress",
                    textColor: "#ffffff"
                ),
                for: family
            )
            for slot in ComplicationSlot.slots(for: family) {
                config.setSlotConfig(
                    ComplicationSlotConfig(isVisible: true, formula: Self.customFormula, color: "#123456"),
                    slot: slot,
                    for: family
                )
            }
        }
        return config
    }

    @Test(arguments: WatchComplicationConfig.Kind.allCases)
    func drivesEverySize(kind: WatchComplicationConfig.Kind) async throws {
        try await withServer { server in
            let viewModel = WatchComplicationBuilderEditViewModel(
                existing: config(kind: kind, serverId: server.identifier.rawValue)
            )
            viewModel.entityAttributeKeys = ["temperature", "humidity"]
            viewModel.valueIsNumeric = true
            viewModel.entityUnit = "°C"
            viewModel.useTemplateColor = kind == .customTemplate

            let driver = await SwiftUIScreenDriver.show(
                WatchComplicationConfigurationSheet(viewModel: viewModel),
                inNavigationStack: false
            )
            defer { driver.close() }

            for (index, family) in WatchComplicationConfig.Family.allCases.enumerated() {
                await driver.selectSegment(index, control: 0)
                await #expect(driver.waitUntil { viewModel.config.widgetFamily == family })
                // Every other segmented picker (content, gauge style, corner display) to its other side.
                let pickers = driver.views(of: UISegmentedControl.self, in: driver.topView).count
                for control in 1 ..< max(pickers, 1) {
                    await driver.selectSegment(0, control: control)
                }
                await driver.type("12")
                await driver.toggleSwitches()
                await driver.toggleSwitches()
            }
        }
    }

    /// Default content, nothing customized: the plain state of every slot.
    @Test func rendersAFreshEntityComplication() async throws {
        try await withServer { server in
            let viewModel = WatchComplicationBuilderEditViewModel(existing: WatchComplicationConfig(
                serverId: server.identifier.rawValue,
                kind: .entity,
                entityId: "light.kitchen"
            ))
            let driver = await SwiftUIScreenDriver.show(
                WatchComplicationConfigurationSheet(viewModel: viewModel),
                inNavigationStack: false
            )
            defer { driver.close() }
            for index in WatchComplicationConfig.Family.allCases.indices {
                await driver.selectSegment(index, control: 0)
                await driver.toggleSwitches()
            }
            #expect(driver.sectionCount > 1)
        }
    }

    private func withServer(_ body: (Server) async throws -> Void) async throws {
        let previous = Current.servers
        let servers = FakeServerManager(initial: 1)
        let server = servers.all[0]
        let api = HomeAssistantAPI(server: server)
        api.connection = HAMockConnection()
        Current.setCachedApi(api, for: server.identifier)
        Current.servers = servers
        defer {
            Current.resetAPICache(for: [server.identifier])
            Current.servers = previous
        }
        try await body(server)
    }
}
