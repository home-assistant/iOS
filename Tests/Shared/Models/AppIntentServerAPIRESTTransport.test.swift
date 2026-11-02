import Foundation
import GRDB
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import SharedTesting
import Testing

/// The REST transport App Intents use on the watch, end to end against OHHTTPStubs: each operation's
/// request and the parsing of what comes back.
///
/// `.sharedState`: HTTP stubs are process-wide and the Assist test swaps `Current.database`.
@Suite(.sharedState)
struct AppIntentServerAPIRESTTransportTests {
    private static let host = "a5-intents-rest.example.com"

    private var server: Server {
        Server.fake(identifier: .init(rawValue: "rest-server")) { info in
            info.connection.set(address: URL(string: "http://\(Self.host):8123")!, for: .external)
        }
    }

    @Test func actionsAreCalledWithOrWithoutAResponse() async throws {
        var queries: [String?] = []
        try await withStub("/api/services/script/run", { request in
            queries.append(request.url?.query)
            return request.url?.query == "return_response"
                ? HTTPStubsResponse(
                    jsonObject: ["changed_states": [], "service_response": ["value": 42]],
                    statusCode: 200,
                    headers: nil
                )
                : HTTPStubsResponse(jsonObject: [[String: Any]](), statusCode: 200, headers: nil)
        }) {
            let withResponse = try await AppIntentServerAPI.callActionViaREST(
                server: server,
                domain: "script",
                service: "run",
                data: ["entity_id": "script.a"],
                returnResponse: true
            )
            #expect((withResponse.response as? [String: Any])?["value"] as? Int == 42)

            let without = try await AppIntentServerAPI.callActionViaREST(
                server: server,
                domain: "script",
                service: "run",
                data: [:],
                returnResponse: false
            )
            #expect(without.response == nil)
        }
        #expect(queries == ["return_response", nil])
    }

    @Test func templatesComeBackAsText() async throws {
        try await withStub("/api/template", { _ in
            HTTPStubsResponse(data: Data("21 °C".utf8), statusCode: 200, headers: nil)
        }) {
            let rendered = try await AppIntentServerAPI.renderTemplateViaREST(server: server, template: "{{ 21 }}")
            #expect(rendered == "21 °C")
        }
        await withStub("/api/template", { _ in
            HTTPStubsResponse(data: Data([0xFF, 0xFE, 0xFD]), statusCode: 200, headers: nil)
        }) {
            await #expect(throws: HomeAssistantRESTError.self) {
                try await AppIntentServerAPI.renderTemplateViaREST(server: server, template: "x")
            }
        }
    }

    @Test func actionDefinitionsAreReadFromTheServicesList() async throws {
        try await withStub("/api/services", { _ in
            HTTPStubsResponse(jsonObject: [
                ["domain": "light", "services": [
                    "turn_on": ["name": "Turn on", "description": "Turns it on", "response": ["optional": true]],
                    "toggle": ["icon": "mdi:toggle"],
                ]],
                ["domain": "broken"],
            ], statusCode: 200, headers: nil)
        }) {
            let definitions = try await AppIntentServerAPI.actionDefinitionsViaREST(server: server)
            #expect(definitions.map(\.actionId) == ["light.toggle", "light.turn_on"])
            #expect(definitions.last?.supportsResponse == true)
            #expect(definitions.first?.icon == "mdi:toggle")
        }
        #expect(AppIntentServerAPI.actionDefinitions(fromRESTServices: ["not": "a list"]).isEmpty)
    }

    @Test func entitiesAreFilteredToTheirDomains() async throws {
        try await withStub("/api/states", { _ in
            HTTPStubsResponse(jsonObject: [
                Self.state("light.kitchen", name: "Kitchen"),
                Self.state("switch.fan", name: "Fan"),
                Self.state("sensor.power", name: "Power"),
                ["state": "missing id"],
            ], statusCode: 200, headers: nil)
        }) {
            let lights = try await AppIntentServerAPI.entitiesViaREST(server: server, domain: .light)
            #expect(lights.map(\.entityId) == ["light.kitchen"])
            let controls = try await AppIntentServerAPI.entitiesViaREST(server: server, domains: [.light, .switch])
            #expect(Set(controls.map(\.entityId)) == ["light.kitchen", "switch.fan"])
        }
        #expect(AppIntentServerAPI.entities(fromRESTStates: "nope", domains: [.light]).isEmpty)
    }

    @Test func oneEntitysStateIsDecoded() async throws {
        try await withStub("/api/states/light.kitchen", { _ in
            HTTPStubsResponse(jsonObject: Self.state("light.kitchen", name: "Kitchen"), statusCode: 200, headers: nil)
        }) {
            let entity = try await AppIntentServerAPI.entityStateViaREST(server: server, entityId: "light.kitchen")
            #expect(entity.state == "on")
        }
        #expect(throws: HomeAssistantRESTError.self) {
            try AppIntentServerAPI.entityState(fromRESTState: ["not", "a", "dictionary"])
        }
    }

    /// A stored pipeline sends its own agent and language; "Preferred" sends neither.
    @Test func assistUsesTheStoredPipelinesAgent() async throws {
        let previousDatabase = Current.database
        defer { Current.database = previousDatabase }
        let database = try DatabaseQueue()
        try AssistPipelinesTable().createIfNeeded(database: database)
        try await database.write { db in
            try AssistPipelines(serverId: "rest-server", preferredPipeline: "local", pipelines: [
                Pipeline(conversationEngine: "conversation.local", id: "local", language: "nl", name: "Local"),
            ]).insert(db)
        }
        Current.database = { database }

        var bodies: [[String: Any]] = []
        try await withStub("/api/conversation/process", { request in
            if let body = request.ohhttpStubs_httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                bodies.append(json)
            }
            return HTTPStubsResponse(jsonObject: [
                "response": ["response_type": "action_done", "speech": ["plain": ["speech": "Done"]]],
            ], statusCode: 200, headers: nil)
        }) {
            let local = try await AppIntentServerAPI.assistViaREST(server: server, prompt: "Hi", pipelineId: "local")
            #expect(local == "Done")
            _ = try await AppIntentServerAPI.assistViaREST(server: server, prompt: "Hi", pipelineId: nil)
            _ = try await AppIntentServerAPI.assistViaREST(server: server, prompt: "Hi", pipelineId: "unknown")
        }
        #expect(bodies.first?["agent_id"] as? String == "conversation.local")
        #expect(bodies.first?["language"] as? String == "nl")
        #expect(bodies.dropFirst().allSatisfy { $0["agent_id"] == nil })
    }

    @Test func assistAnswersAndErrorsAreParsed() throws {
        #expect(throws: HomeAssistantRESTError.self) { try AppIntentServerAPI.assistAnswer(from: "nope") }
        #expect(throws: ShortcutAppIntentError.self) {
            try AppIntentServerAPI.assistAnswer(from: ["response": ["response_type": "error"]])
        }
        #expect(throws: HomeAssistantRESTError.self) {
            try AppIntentServerAPI.assistAnswer(from: ["response": ["response_type": "action_done"]])
        }
    }

    // MARK: - Helpers

    private static func state(_ entityId: String, name: String) -> [String: Any] {
        [
            "entity_id": entityId,
            "state": "on",
            "attributes": ["friendly_name": name],
            "last_changed": "2026-01-01T00:00:00+00:00",
            "last_updated": "2026-01-01T00:00:00+00:00",
            "context": ["id": "1", "user_id": NSNull(), "parent_id": NSNull()],
        ]
    }

    private func withStub(
        _ path: String,
        _ response: @escaping (URLRequest) -> HTTPStubsResponse,
        _ body: () async throws -> Void
    ) async rethrows {
        let descriptor = stub(condition: isHost(Self.host) && isPath(path), response: response)
        defer { HTTPStubs.removeStub(descriptor) }
        try await body()
    }
}
