@testable import HomeAssistant

import Foundation
import GRDB
import HAKit
@testable import Shared
import SharedTesting
import Testing
import WidgetKit

/// The gauge widget's snapshot and timeline for each content source — an entity, a watch
/// complication and a template — plus the complication lookups the widget's pickers offer.
///
/// `.isolatedEnvironment`: the stub connection answers on the test's own task, so the servers,
/// API cache and database each test installs reach the provider without touching the globals.
@Suite(.isolatedEnvironment)
struct WidgetGaugeTimelineEntriesTests {
    @available(iOS 17, *)
    private var provider: WidgetGaugeAppIntentTimelineProvider { .init() }

    // MARK: - Gallery and failures

    // MARK: - Entity source

    // MARK: - Template source

    // MARK: - Complication source

    @available(iOS 17, *)
    @Test func aTemplateComplicationRendersEachTemplateOnce() async throws {
        let (server, connection) = try install { request in
            switch request.data["template"] as? String {
            case "{{ 21 }}": .success(.primitive("21"))
            case "{{ 0.5 }}": .success(.primitive("0.5"))
            case "{{ 'red' }}": .success(.primitive("#FF0000"))
            case "{{ 'bad' }}": .success(.dictionary(["unexpected": true]))
            case "{{ min }}": .success(.primitive("0"))
            default: .failure(widgetStubUnexpected)
            }
        }
        var config = WatchComplicationConfig(
            id: "template",
            serverId: server.identifier.rawValue,
            widgetFamily: .circular,
            kind: .customTemplate,
            iconName: "thermometer",
            customTextTemplate: "{{ 21 }}",
            customGaugeTemplate: "{{ 0.5 }}",
            customGaugeColorTemplate: "{{ 'red' }}",
            customIconColorTemplate: "{{ 'red' }}",
            customTextColorTemplate: "{{ 'bad' }}"
        )
        config.setOptions(
            .init(showGauge: true, minLabelTemplate: "{{ min }}", maxLabelTemplate: "{{ max }}"),
            for: .circular
        )
        try insert([config])

        let context = try await WidgetComplicationResolver.context(id: "template", family: .circular)
        #expect(context.value == "21")
        #expect(context.fraction == 0.5)
        #expect(context.renderedTemplates["{{ min }}"] == "0")
        #expect(context.renderedTemplates["{{ max }}"] == nil)
        #expect(connection.sentCommands.allSatisfy { $0 == "template" })
    }

    @available(iOS 17, *)
    @Test func complicationsThatCannotBeResolvedSayWhy() async throws {
        let (server, _) = try install { _ in .failure(widgetStubUnexpected) }
        try insert([
            WatchComplicationConfig(id: "orphan", serverId: "gone", widgetFamily: .circular, kind: .entity),
            WatchComplicationConfig(
                id: "no-entity",
                serverId: server.identifier.rawValue,
                widgetFamily: .circular,
                kind: .entity
            ),
            WatchComplicationConfig(
                id: "offline",
                serverId: server.identifier.rawValue,
                widgetFamily: .circular,
                kind: .entity,
                entityId: "sensor.offline"
            ),
        ])

        await #expect(throws: WidgetComplicationResolver.ResolveError.noComplication) {
            try await WidgetComplicationResolver.context(id: "missing", family: .circular)
        }
        await #expect(throws: WidgetComplicationResolver.ResolveError.noServer) {
            try await WidgetComplicationResolver.context(id: "orphan", family: .circular)
        }
        await #expect(throws: WidgetComplicationResolver.ResolveError.noComplication) {
            try await WidgetComplicationResolver.context(id: "no-entity", family: .circular)
        }
        await #expect(throws: WidgetComplicationResolver.ResolveError.unavailable) {
            try await WidgetComplicationResolver.context(id: "offline", family: .circular)
        }
    }

    // MARK: - Pickers

    @available(iOS 17, *)
    @Test func thePickersOfferTheComplicationsOfTheirFamily() async throws {
        _ = try install { _ in .failure(widgetStubUnexpected) }
        try insert([
            WatchComplicationConfig(id: "c1", serverId: "s", widgetFamily: .circular, kind: .entity, name: "Ring"),
            WatchComplicationConfig(id: "r1", serverId: "s", widgetFamily: .rectangular, kind: .entity, name: "Card"),
        ])

        let circular = try await WidgetCircularComplicationAppEntityQuery().suggestedEntities()
        #expect(circular.sections.flatMap(\.items).map(\.value.id) == ["c1"])
        let circularById = try await WidgetCircularComplicationAppEntityQuery().entities(for: ["c1", "r1"])
        #expect(circularById.map(\.name) == ["Ring"])
        #expect(circularById.first.map { String(describing: $0.displayRepresentation.title) }?.isEmpty == false)

        let rectangular = try await WidgetRectangularComplicationAppEntityQuery().suggestedEntities()
        #expect(rectangular.sections.flatMap(\.items).map(\.value.id) == ["r1"])
        let rectangularById = try await WidgetRectangularComplicationAppEntityQuery().entities(for: ["r1"])
        #expect(rectangularById.map(\.name) == ["Card"])
        #expect(rectangularById.first.map { String(describing: $0.displayRepresentation.title) }?.isEmpty == false)
    }

    /// Without a configured entity there are no attributes to offer, and a picked one round-trips.
    @available(iOS 17, *)
    @Test func theAttributePickerEchoesItsIdentifiers() async throws {
        let query = WidgetGaugeAttributeAppEntityQuery()
        let suggested = try await query.suggestedEntities()
        #expect(suggested.sections.flatMap(\.items).isEmpty)
        let picked = try await query.entities(for: ["battery", "temperature"])
        #expect(picked.map(\.id) == ["battery", "temperature"])
        #expect(!String(describing: picked[0].displayRepresentation.title).isEmpty)
        _ = WidgetGaugeAppIntent.parameterSummary
        #expect(!GaugeTypeAppEnum.caseDisplayRepresentations.isEmpty)
    }

    // MARK: - Helpers

    /// Registers one server whose API answers through `respond`, over a fresh in-memory database.
    private func install(
        _ respond: @escaping WidgetStubConnection.Responder
    ) throws -> (Server, WidgetStubConnection) {
        let database = try SettingsTestDatabase.make()
        Current.database = { database }
        let servers = FakeServerManager()
        let server = servers.add(identifier: .init(rawValue: "gauge-server"), serverInfo: .fake())
        Current.servers = servers
        let connection = WidgetStubConnection(respond: respond)
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        return (server, connection)
    }

    private func insert(_ configs: [WatchComplicationConfig]) throws {
        try Current.database().write { db in
            for config in configs {
                try config.insert(db)
            }
        }
    }

    @available(iOS 17, *)
    private static func configuration(source: WidgetContentSourceAppEnum, serverId: String) -> WidgetGaugeAppIntent {
        let configuration = WidgetGaugeAppIntent()
        configuration.source = source
        configuration.server = .init(identifier: .init(rawValue: serverId))
        configuration.gaugeType = .normal
        return configuration
    }

    @available(iOS 17, *)
    private static func entity(serverId: String, entityId: String) -> HAAppEntityAppIntentEntity {
        HAAppEntityAppIntentEntity(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            serverName: "Fake Server",
            displayString: "Power",
            iconName: "bolt"
        )
    }

    /// Answers each request with the next canned response, then fails.
    private final class ResponseQueue: @unchecked Sendable {
        private let lock = NSLock()
        private var responses: [Result<HAData, HAError>]

        init(_ responses: [Result<HAData, HAError>]) {
            self.responses = responses
        }

        func next() -> Result<HAData, HAError> {
            lock.lock()
            defer { lock.unlock() }
            return responses.isEmpty ? .failure(widgetStubUnexpected) : responses.removeFirst()
        }
    }
}
