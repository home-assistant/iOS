import GRDB
import HAKit
import HAKit_Mocks
import HAWatchComplications
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Resolving one of the user's watch complications for a lock-screen widget: which configs are
/// offered, the errors for a complication or server that no longer exists, and the entity and
/// template paths against a mock connection.
@available(iOS 17, *)
final class WidgetComplicationResolverTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var database: DatabaseQueue!
    private var server: Server!
    private var connection: HAMockConnection!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        previousCachedApis = Current.cachedApis

        let database = try DatabaseQueue(path: ":memory:")
        try WatchComplicationConfigTable().createIfNeeded(database: database)
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        Current.database = { database }
        self.database = database

        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()
        let api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
    }

    override func tearDown() {
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        Current.database = previousDatabase
        database = nil
        connection = nil
        server = nil
        super.tearDown()
    }

    func testConfigsAreFilteredByFamilyInSortOrder() throws {
        try insert([
            WatchComplicationConfig(id: "b", serverId: "s", widgetFamily: .circular, sortOrder: 2),
            WatchComplicationConfig(id: "rect", serverId: "s", widgetFamily: .rectangular, sortOrder: 0),
            WatchComplicationConfig(id: "a", serverId: "s", widgetFamily: .circular, sortOrder: 1),
        ])

        XCTAssertEqual(WidgetComplicationResolver.configs(family: .circular).map(\.id), ["a", "b"])
        XCTAssertEqual(WidgetComplicationResolver.configs(family: .rectangular).map(\.id), ["rect"])
        XCTAssertTrue(WidgetComplicationResolver.configs(family: .inline).isEmpty)
    }

    func testMissingComplicationThrows() async {
        do {
            _ = try await WidgetComplicationResolver.context(id: "gone", family: .circular)
            XCTFail("Expected noComplication")
        } catch WidgetComplicationResolver.ResolveError.noComplication {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testComplicationOfAnotherFamilyIsNotFound() async throws {
        try insert([WatchComplicationConfig(id: "rect", serverId: serverId, widgetFamily: .rectangular)])

        do {
            _ = try await WidgetComplicationResolver.context(id: "rect", family: .circular)
            XCTFail("Expected noComplication")
        } catch WidgetComplicationResolver.ResolveError.noComplication {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testComplicationOfARemovedServerThrows() async throws {
        try insert([WatchComplicationConfig(id: "c", serverId: "removed", widgetFamily: .circular)])

        do {
            _ = try await WidgetComplicationResolver.context(id: "c", family: .circular)
            XCTFail("Expected noServer")
        } catch WidgetComplicationResolver.ResolveError.noServer {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testEntityComplicationWithoutAnEntityThrows() async throws {
        try insert([WatchComplicationConfig(id: "c", serverId: serverId, widgetFamily: .circular, kind: .entity)])

        do {
            _ = try await WidgetComplicationResolver.context(id: "c", family: .circular)
            XCTFail("Expected noComplication")
        } catch WidgetComplicationResolver.ResolveError.noComplication {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    func testEntityComplicationWhoseStateFailsThrowsUnavailable() async throws {
        try insert([entityConfig()])

        let task = Task { try await WidgetComplicationResolver.context(id: "entity", family: .circular) }
        try await waitForRequest(index: 0)
        connection.pendingRequests[0].completion(.failure(.internal(debugDescription: "offline")))

        do {
            _ = try await task.value
            XCTFail("Expected unavailable")
        } catch WidgetComplicationResolver.ResolveError.unavailable {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testEntityComplicationResolvesValueAndGauge() async throws {
        try insert([entityConfig()])

        let task = Task { try await WidgetComplicationResolver.context(id: "entity", family: .circular) }
        try await waitForRequest(index: 0)
        connection.pendingRequests[0].completion(.success(.init(value: [
            "state": "25",
            "attributes": ["unit_of_measurement": "%"],
        ])))

        let context = try await task.value
        XCTAssertEqual(context.config.id, "entity")
        XCTAssertEqual(context.config.widgetFamily, .circular)
        XCTAssertEqual(try XCTUnwrap(context.fraction), 0.25, accuracy: 0.0001)
        XCTAssertTrue(context.value.contains("25"))
        XCTAssertEqual(context.attributes["unit_of_measurement"] as? String, "%")

        let model = context.circularRenderModel
        XCTAssertEqual(model.valueText, context.valueText)
        XCTAssertEqual(model.showsValue, context.showsValue)
        XCTAssertEqual(model.fraction, context.showsGauge ? context.fraction : nil)
        XCTAssertEqual(model.isCapacityGauge, context.gaugeStyle == .capacity)
        XCTAssertEqual(model.minLabel, context.showsMin ? "0" : nil)
        XCTAssertEqual(model.maxLabel, context.showsMax ? "100" : nil)
        XCTAssertEqual(model.showsIcon, context.iconImage != nil)
    }

    /// A template complication renders its text, gauge and color templates one by one; a color
    /// that doesn't parse or fails keeps the static one, and slot templates are rendered too.
    func testTemplateComplicationRendersEveryTemplate() async throws {
        let slot = ComplicationSlotConfig(formula: ComplicationFormula(parts: [.template("{{ extra }}")]))
        try insert([WatchComplicationConfig(
            id: "template",
            serverId: serverId,
            widgetFamily: .circular,
            kind: .customTemplate,
            iconColor: "#00FF00",
            customTextTemplate: "{{ value }}",
            customGaugeTemplate: "{{ gauge }}",
            customGaugeColorTemplate: "{{ gauge_color }}",
            customIconColorTemplate: "{{ icon_color }}",
            customTextColorTemplate: "{{ text_color }}",
            families: [
                WatchComplicationConfig.Family.circular.rawValue: .init(slots: [
                    ComplicationSlot.subtitle.rawValue: slot,
                ]),
            ]
        )])

        let task = Task { try await WidgetComplicationResolver.context(id: "template", family: .circular) }

        try await answer(index: 0, expecting: "{{ value }}", with: "Hello")
        try await answer(index: 1, expecting: "{{ gauge }}", with: "0.5")
        try await answer(index: 2, expecting: "{{ icon_color }}", with: "#ff0000")
        try await answer(index: 3, expecting: "{{ gauge_color }}", with: "not a color")
        try await waitForRequest(index: 4)
        XCTAssertEqual(connection.pendingRequests[4].request.data["template"] as? String, "{{ text_color }}")
        connection.pendingRequests[4].completion(.failure(.internal(debugDescription: "template error")))
        try await answer(index: 5, expecting: "{{ extra }}", with: "Extra")

        let context = try await task.value
        XCTAssertEqual(context.value, "Hello")
        XCTAssertEqual(try XCTUnwrap(context.fraction), 0.5, accuracy: 0.0001)
        XCTAssertEqual(context.config.iconColor, "#FF0000")
        XCTAssertNil(context.config.options(for: .circular).tint)
        XCTAssertNil(context.config.options(for: .circular).textColor)
        XCTAssertEqual(context.config.options(for: .circular).showGauge, true)
        XCTAssertEqual(context.renderedTemplates["{{ value }}"], "Hello")
        XCTAssertEqual(context.renderedTemplates["{{ extra }}"], "Extra")
        XCTAssertEqual(connection.pendingRequests.count, 6)
    }

    /// A gauge template that renders something non-numeric draws no gauge, and a response that
    /// isn't a string leaves the text empty.
    func testTemplateComplicationWithUnusableRendersHasNoGauge() async throws {
        try insert([WatchComplicationConfig(
            id: "template",
            serverId: serverId,
            widgetFamily: .circular,
            kind: .customTemplate,
            customTextTemplate: "{{ value }}",
            customGaugeTemplate: "{{ gauge }}",
            customGaugeColorTemplate: "{{ gauge_color }}"
        )])

        let task = Task { try await WidgetComplicationResolver.context(id: "template", family: .circular) }

        try await waitForRequest(index: 0)
        connection.pendingRequests[0].completion(.success(.init(value: ["not": "a string"])))
        try await answer(index: 1, expecting: "{{ gauge }}", with: "n/a")
        try await answer(index: 2, expecting: "{{ gauge_color }}", with: "#123456")

        let context = try await task.value
        XCTAssertEqual(context.value, "")
        XCTAssertNil(context.fraction)
        XCTAssertEqual(context.config.options(for: .circular).showGauge, false)
        XCTAssertEqual(context.config.options(for: .circular).tint, "#123456")
        XCTAssertEqual(context.renderedTemplates["{{ value }}"], "")
    }

    /// The rectangular mapping mirrors the in-app editor field for field.
    func testRectangularRenderModelMirrorsTheContext() {
        let config = WatchComplicationConfig(
            id: "rect",
            serverId: serverId,
            widgetFamily: .rectangular,
            entityId: "sensor.battery",
            entityDisplayName: "Battery",
            gaugeMin: 0,
            gaugeMax: 200
        )
        let context = ComplicationRenderContext.entity(
            config: config,
            family: .rectangular,
            state: "50",
            attributes: [:]
        )

        let model = context.rectangularRenderModel
        XCTAssertEqual(model.title, context.titleText)
        XCTAssertEqual(model.showsName, context.showsName)
        XCTAssertEqual(model.subtitle, context.subtitleText)
        XCTAssertEqual(model.showsSubtitle, context.showsSubtitle)
        XCTAssertEqual(model.valueText, context.valueText)
        XCTAssertEqual(model.showsValue, context.showsValue)
        XCTAssertEqual(model.bottomText, context.bottomText)
        XCTAssertEqual(model.showsBottomText, context.showsBottomText)
        XCTAssertEqual(model.fraction, context.showsGauge ? context.fraction : nil)
        XCTAssertEqual(model.minLabel, context.showsMin ? "0" : nil)
        XCTAssertEqual(model.maxLabel, context.showsMax ? "200" : nil)
        XCTAssertEqual(model.showsIcon, context.iconImage != nil)
        XCTAssertNil(model.textColor)
        XCTAssertEqual(try XCTUnwrap(context.fraction), 0.25, accuracy: 0.0001)
    }

    // MARK: - Helpers

    private var serverId: String { server.identifier.rawValue }

    private func entityConfig() -> WatchComplicationConfig {
        WatchComplicationConfig(
            id: "entity",
            serverId: serverId,
            widgetFamily: .circular,
            kind: .entity,
            entityId: "sensor.battery",
            entityDisplayName: "Battery",
            gaugeMin: 0,
            gaugeMax: 100
        )
    }

    private func insert(_ configs: [WatchComplicationConfig]) throws {
        try database.write { db in
            for config in configs {
                try config.insert(db)
            }
        }
    }

    private func answer(index: Int, expecting template: String, with rendered: String) async throws {
        try await waitForRequest(index: index)
        let pending = connection.pendingRequests[index]
        XCTAssertEqual(pending.request.data["template"] as? String, template)
        pending.completion(.success(.init(value: rendered)))
    }

    /// The resolver sends from its own task, so wait for the request to reach the mock connection.
    private func waitForRequest(index: Int) async throws {
        for _ in 0 ..< 300 {
            if connection.pendingRequests.count > index {
                return
            }
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        throw RequestNeverSent(index: index)
    }

    private struct RequestNeverSent: Error {
        let index: Int
    }
}
