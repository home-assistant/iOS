import Foundation
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Renders the live complication previews against a stubbed REST states API and a mock websocket
/// that answers every template subscription.
/// Shared state: a process-wide HTTP stub, `Current.servers` and the API cache, all read from the
/// main run loop.
@Suite(.sharedState)
@MainActor
struct WatchComplicationLivePreviewTests {
    private static let stateJSON = """
    {"entity_id": "sensor.outside", "state": "21.456",
     "attributes": {"unit_of_measurement": "°C", "humidity": 40, "friendly_name": "Outside"}}
    """

    // MARK: - REST

    @Test func fetchesTheEntityStateOverREST() async throws {
        try await withWorld(status: 200, body: Self.stateJSON) { server, _ in
            let state = try await #require(WatchComplicationLivePreview.fetchState(
                entityId: "sensor.outside",
                server: server
            ))
            #expect(state.state == "21.456")
            #expect(state.attributes["unit_of_measurement"] as? String == "°C")
            await #expect(WatchComplicationLivePreview.bearerToken(for: server) == "FakeAccessToken")
        }
    }

    @Test(arguments: [(Int32(500), "{}"), (401, "{}"), (200, "not json"), (200, "{\"attributes\": {}}")])
    func rejectedOrUnreadableResponsesGiveNoState(status: Int32, body: String) async throws {
        try await withWorld(status: status, body: body) { server, _ in
            await #expect(WatchComplicationLivePreview.fetchState(entityId: "sensor.outside", server: server) == nil)
        }
    }

    @Test func serverWithoutAURLGivesNoState() async {
        let offline = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
        await #expect(WatchComplicationLivePreview.fetchState(entityId: "sensor.outside", server: offline) == nil)
    }

    @Test func formatsValuesWithUnitAndPrecision() {
        // Rounded to one decimal in the current locale, with the unit appended.
        let formatted = WatchComplicationLivePreview.formatValue("21.456", unit: "°C", precision: 1)
        #expect(formatted.hasSuffix("°C"))
        #expect(!formatted.contains("456"))
        #expect(WatchComplicationLivePreview.formatValue("on", unit: nil, precision: nil) == "on")
    }

    // MARK: - Rendering

    @Test(arguments: WatchComplicationConfig.Family.allCases)
    func rendersAnEntityPreview(family: WatchComplicationConfig.Family) async throws {
        try await withWorld(status: 200, body: Self.stateJSON) { server, _ in
            var units: [String?] = []
            var attributes: [[String]] = []
            let driver = await SwiftUIScreenDriver.show(
                WatchComplicationLivePreview(
                    config: entityConfig(family: family, serverId: server.identifier.rawValue),
                    server: server,
                    onUnit: { units.append($0) },
                    onAttributes: { attributes.append($0) }
                ),
                size: CGSize(width: 320, height: 200),
                inNavigationStack: false
            )
            defer { driver.close() }
            await #expect(driver.waitUntil { !units.isEmpty })
            #expect(units.last == "°C")
            #expect(attributes.last?.contains("humidity") == true)
        }
    }

    @Test(arguments: WatchComplicationConfig.Family.allCases)
    func rendersATemplatePreview(family: WatchComplicationConfig.Family) async throws {
        try await withWorld(status: 200, body: Self.stateJSON) { server, connection in
            let driver = await SwiftUIScreenDriver.show(
                WatchComplicationLivePreview(
                    config: templateConfig(family: family, serverId: server.identifier.rawValue),
                    server: server
                ),
                size: CGSize(width: 320, height: 200),
                inNavigationStack: false
            )
            defer { driver.close() }
            await #expect(driver.waitUntil { connection.pendingSubscriptions.count >= 2 })
            answer(connection, with: "0.5")
            await driver.settle()
        }
    }

    @Test(arguments: [false, true])
    func rendersAllFamilies(onlySelected: Bool) async throws {
        try await withWorld(status: 200, body: Self.stateJSON) { server, connection in
            for family in WatchComplicationConfig.Family.allCases {
                var numeric: [Bool] = []
                let entity = await SwiftUIScreenDriver.show(
                    AllFamiliesComplicationPreview(
                        config: entityConfig(family: family, serverId: server.identifier.rawValue),
                        server: server,
                        selectedFamily: family,
                        showsOnlySelectedFamily: onlySelected,
                        onValueIsNumeric: { numeric.append($0) }
                    ),
                    size: CGSize(width: 390, height: 900),
                    inNavigationStack: false
                )
                await #expect(entity.waitUntil { !numeric.isEmpty })
                entity.close()

                let template = await SwiftUIScreenDriver.show(
                    AllFamiliesComplicationPreview(
                        config: templateConfig(family: family, serverId: server.identifier.rawValue),
                        server: server,
                        selectedFamily: family,
                        showsOnlySelectedFamily: onlySelected
                    ),
                    size: CGSize(width: 390, height: 900),
                    inNavigationStack: false
                )
                await #expect(template.waitUntil { !connection.pendingSubscriptions.isEmpty })
                answer(connection, with: "#FF0000")
                await template.settle()
                template.close()
                connection.pendingSubscriptions.removeAll()
            }

            // Nothing picked yet: the placeholder state.
            let empty = await SwiftUIScreenDriver.show(
                AllFamiliesComplicationPreview(
                    config: WatchComplicationConfig(serverId: server.identifier.rawValue, kind: .entity),
                    server: server,
                    selectedFamily: .circular,
                    showsOnlySelectedFamily: onlySelected
                ),
                size: CGSize(width: 390, height: 900),
                inNavigationStack: false
            )
            empty.close()
        }
    }

    @Test func rendersEachFamilyPlaceholder() async {
        for family in WatchComplicationConfig.Family.allCases {
            let driver = await SwiftUIScreenDriver.show(
                ComplicationFamilyPreview(family: family),
                size: CGSize(width: 120, height: 120),
                inNavigationStack: false
            )
            driver.close()
        }
    }

    // MARK: - Value sources

    /// The SwiftUI-preview sample contexts, with and without a gauge.
    @Test func buildsTheSampleContexts() {
        for family in WatchComplicationConfig.Family.allCases {
            #expect(ComplicationRenderContext.preview(family).fraction == 0.68)
            #expect(ComplicationRenderContext.preview(family, gauge: false).fraction == nil)
        }
        #expect(ComplicationRenderContext.previewCorner().iconImage != nil)
        #expect(ComplicationRenderContext.previewCorner(showIcon: false, gauge: false).iconImage == nil)
    }

    /// An entity whose value comes from an attribute shows that attribute with the unit override and
    /// precision; switching only the value source reuses the fetched attributes instead of fetching
    /// again. (The refresh reads the config of the render before the change, so the unit it reports
    /// trails by one change; the test only checks that a report arrives.)
    @Test func valueSourcesReuseTheFetchedState() async throws {
        try await withWorld(status: 200, body: Self.stateJSON) { server, _ in
            var config = entityConfig(family: .rectangular, serverId: server.identifier.rawValue)
            config.valueAttribute = "humidity"
            config.unitOverride = "pct"
            config.valuePrecision = 0
            let box = ConfigBox(config)
            var units: [String?] = []
            let driver = await SwiftUIScreenDriver.show(
                LivePreviewHost(box: box, server: server, onUnit: { units.append($0) }),
                size: CGSize(width: 320, height: 200),
                inNavigationStack: false
            )
            defer { driver.close() }
            await #expect(driver.waitUntil { !units.isEmpty })
            await driver.settle()

            // Back to the state: same fetch inputs, so the unit is re-derived without a new request.
            let reported = units.count
            box.config.valueAttribute = nil
            box.config.unitOverride = nil
            box.config.valuePrecision = nil
            await #expect(driver.waitUntil { units.count > reported })
        }
    }

    /// The all-families preview reads an attribute's unit; switching to a template and back to the
    /// same entity re-derives it from the state already fetched instead of fetching again. Built
    /// without a numeric-value callback, so its default is the one called.
    @Test func allFamiliesValueSourcesReuseTheFetchedState() async throws {
        try await withWorld(status: 200, body: Self.stateJSON) { server, _ in
            var config = entityConfig(family: .rectangular, serverId: server.identifier.rawValue)
            config.valueAttribute = "humidity"
            let box = ConfigBox(config)
            var units: [String?] = []
            let driver = await SwiftUIScreenDriver.show(
                AllFamiliesPreviewHost(box: box, server: server, onUnit: { units.append($0) }),
                size: CGSize(width: 390, height: 900),
                inNavigationStack: false
            )
            defer { driver.close() }
            await #expect(driver.waitUntil { !units.isEmpty })
            await driver.settle()

            let reported = units.count
            box.config.kind = .customTemplate
            await driver.settle()
            box.config.kind = .entity
            await #expect(driver.waitUntil { units.count > reported })
        }
    }

    /// A config without an entity has nothing to fetch and reports no unit and no attributes.
    @Test func anEntityLessConfigReportsNothing() async throws {
        try await withWorld(status: 200, body: Self.stateJSON) { server, _ in
            var config = entityConfig(family: .inline, serverId: server.identifier.rawValue)
            config.entityId = nil
            var units: [String?] = []
            var attributes: [[String]] = []
            let driver = await SwiftUIScreenDriver.show(
                WatchComplicationLivePreview(
                    config: config,
                    server: server,
                    onUnit: { units.append($0) },
                    onAttributes: { attributes.append($0) }
                ),
                size: CGSize(width: 320, height: 200),
                inNavigationStack: false
            )
            defer { driver.close() }
            await #expect(driver.waitUntil { !units.isEmpty })
            #expect(units == [nil])
            #expect(attributes == [[]])
        }
    }

    /// A corner complication can draw its gauge as a progress arc instead.
    @Test func cornerDrawsTheProgressDisplay() async {
        var config = WatchComplicationConfig(serverId: "preview", widgetFamily: .corner, name: "Battery")
        config.gaugeMin = 0
        config.gaugeMax = 100
        config.setOptions(
            .init(showGauge: true, cornerGaugeDisplay: WatchComplicationConfig.CornerGaugeDisplay.progress.rawValue),
            for: .corner
        )
        let context = ComplicationRenderContext(config: config, value: "68%", fraction: 0.68, iconImage: nil)
        let driver = await SwiftUIScreenDriver.show(
            CornerComplicationPreview(context: context),
            size: CGSize(width: 200, height: 200),
            inNavigationStack: false
        )
        defer { driver.close() }
        #expect(config.cornerGaugeDisplay(for: .corner) == .progress)
    }

    /// Without callbacks, the preview reports into the default no-op closures.
    @Test func reportsWithoutCallbacks() async throws {
        try await withWorld(status: 200, body: Self.stateJSON) { server, _ in
            let driver = await SwiftUIScreenDriver.show(
                WatchComplicationLivePreview(
                    config: entityConfig(family: .circular, serverId: server.identifier.rawValue),
                    server: server
                ),
                size: CGSize(width: 320, height: 200),
                inNavigationStack: false
            )
            defer { driver.close() }
            for _ in 0 ..< 20 {
                await driver.settle(1)
            }
        }
    }

    // MARK: - Helpers

    private func entityConfig(family: WatchComplicationConfig.Family, serverId: String) -> WatchComplicationConfig {
        var config = WatchComplicationConfig(
            serverId: serverId,
            widgetFamily: family,
            kind: .entity,
            entityId: "sensor.outside",
            entityDisplayName: "Outside",
            iconName: "thermometer",
            iconColor: "#FF0000",
            gaugeMin: 0,
            gaugeMax: 40,
            showUnit: true
        )
        config.setOptions(.init(showGauge: true, showMin: true, showMax: true, gaugeMin: 0, gaugeMax: 40), for: family)
        return config
    }

    private func templateConfig(family: WatchComplicationConfig.Family, serverId: String) -> WatchComplicationConfig {
        var config = WatchComplicationConfig(
            serverId: serverId,
            widgetFamily: family,
            kind: .customTemplate,
            iconName: "thermometer",
            customTextTemplate: "{{ 21 }}",
            customGaugeTemplate: "{{ 0.5 }}",
            customGaugeColorTemplate: "{{ '#FF0000' }}",
            customIconColorTemplate: "{{ '#00FF00' }}",
            customTextColorTemplate: "{{ '#0000FF' }}"
        )
        config.setOptions(
            .init(showGauge: true, minLabelTemplate: "{{ 0 }}", maxLabelTemplate: "{{ 1 }}"),
            for: family
        )
        return config
    }

    private func answer(_ connection: HAMockConnection, with result: String) {
        for subscription in connection.pendingSubscriptions {
            subscription.handler(subscription.cancellable, HAData(value: ["result": result]))
        }
    }

    private func withWorld(
        status: Int32,
        body: String,
        _ test: (Server, HAMockConnection) async throws -> Void
    ) async throws {
        let previous = Current.servers
        let servers = FakeServerManager(initial: 1)
        let server = servers.all[0]
        let api = HomeAssistantAPI(server: server)
        let connection = HAMockConnection()
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        Current.servers = servers
        let descriptor = stub(
            condition: { $0.url?.path.hasPrefix("/api/states/") == true },
            response: { _ in .init(data: Data(body.utf8), statusCode: status, headers: nil) }
        )
        defer {
            HTTPStubs.removeStub(descriptor)
            Current.resetAPICache(for: [server.identifier])
            Current.servers = previous
        }
        try await test(server, connection)
    }
}

/// Holds the previewed config so a test can change it while the preview is on screen.
@MainActor
private final class ConfigBox: ObservableObject {
    @Published var config: WatchComplicationConfig

    init(_ config: WatchComplicationConfig) {
        self.config = config
    }
}

private struct LivePreviewHost: View {
    @ObservedObject var box: ConfigBox
    let server: Server
    let onUnit: (String?) -> Void

    var body: some View {
        WatchComplicationLivePreview(config: box.config, server: server, onUnit: onUnit)
    }
}

private struct AllFamiliesPreviewHost: View {
    @ObservedObject var box: ConfigBox
    let server: Server
    let onUnit: (String?) -> Void

    var body: some View {
        AllFamiliesComplicationPreview(
            config: box.config,
            server: server,
            selectedFamily: box.config.widgetFamily,
            onUnit: onUnit
        )
    }
}
