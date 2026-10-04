import Foundation
import GRDB
import HAKit
import HAKit_Mocks
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import XCTest

/// The REST transport App Intents use on watchOS, run end to end against stubbed HTTP responses.
/// It is compiled on every platform, so the iOS test target can drive it directly.
final class AppIntentServerAPIRESTTransportTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var server: Server!
    private var database: DatabaseQueue!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousCachedApis = Current.cachedApis
        previousDatabase = Current.database

        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()

        let api = HomeAssistantAPI(server: server)
        api.connection = HAMockConnection()
        Current.setCachedApi(api, for: server.identifier)

        let database = try DatabaseQueue()
        try AssistPipelinesTable().createIfNeeded(database: database)
        self.database = database
        Current.database = { database }
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        Current.database = previousDatabase
        database = nil
        server = nil
        super.tearDown()
    }

    // MARK: - Stubbed round trips

    func testCallActionAsksForTheResponseAndMapsIt() async throws {
        stub(condition: { request in
            request.url?.path == "/api/services/calendar/get_events"
                && request.url?.query == "return_response"
                && request.httpMethod == "POST"
        }, response: { _ in
            HTTPStubsResponse(jsonObject: [
                "changed_states": [Any](),
                "service_response": ["calendar.home": ["events": [["summary": "Standup"]]]],
            ], statusCode: 200, headers: ["Content-Type": "application/json"])
        })

        let response = try await AppIntentServerAPI.callActionViaREST(
            server: server,
            domain: "calendar",
            service: "get_events",
            data: ["entity_id": "calendar.home"],
            returnResponse: true
        )

        XCTAssertTrue(response.hasResponse)
        XCTAssertEqual(response.jsonString(), #"{"calendar.home":{"events":[{"summary":"Standup"}]}}"#)
    }

    func testCallActionWithoutResponseSendsNoQuery() async throws {
        stub(condition: { request in
            request.url?.path == "/api/services/light/turn_on" && request.url?.query == nil
        }, response: { _ in
            HTTPStubsResponse(
                jsonObject: [["entity_id": "light.kitchen"]],
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        })

        let response = try await AppIntentServerAPI.callActionViaREST(
            server: server,
            domain: "light",
            service: "turn_on",
            data: [:],
            returnResponse: false
        )

        XCTAssertFalse(response.hasResponse)
    }

    func testRenderTemplateReturnsTheRawBody() async throws {
        stub(condition: { $0.url?.path == "/api/template" }, response: { _ in
            HTTPStubsResponse(data: Data("21.5".utf8), statusCode: 200, headers: [:])
        })

        let rendered = try await AppIntentServerAPI.renderTemplateViaREST(
            server: server,
            template: "{{ states('sensor.temperature') }}"
        )

        XCTAssertEqual(rendered, "21.5")
    }

    func testActionDefinitionsAreReadFromTheServicesEndpoint() async throws {
        stub(condition: { $0.url?.path == "/api/services" }, response: { _ in
            HTTPStubsResponse(jsonObject: [
                ["domain": "light", "services": ["turn_on": ["name": "Turn on", "icon": "mdi:lightbulb"]]],
            ], statusCode: 200, headers: ["Content-Type": "application/json"])
        })

        let definitions = try await AppIntentServerAPI.actionDefinitionsViaREST(server: server)

        XCTAssertEqual(definitions.map(\.actionId), ["light.turn_on"])
        XCTAssertEqual(definitions.first?.icon, "mdi:lightbulb")
        XCTAssertEqual(definitions.first?.displayName, "Turn on")
    }

    func testEntitiesAreFilteredByDomain() async throws {
        stubStates()

        let lights = try await AppIntentServerAPI.entitiesViaREST(server: server, domain: .light)
        XCTAssertEqual(lights.map(\.entityId), ["light.attic", "light.kitchen"])

        let lightsAndSwitches = try await AppIntentServerAPI.entitiesViaREST(
            server: server,
            domains: [.light, .switch]
        )
        XCTAssertEqual(lightsAndSwitches.map(\.entityId), ["light.attic", "switch.fan", "light.kitchen"])
    }

    func testEntityStateIsReadFromItsOwnEndpoint() async throws {
        stub(condition: { $0.url?.path == "/api/states/light.kitchen" }, response: { _ in
            HTTPStubsResponse(
                jsonObject: Self.state("light.kitchen", "on", name: "Kitchen"),
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        })

        let entity = try await AppIntentServerAPI.entityStateViaREST(server: server, entityId: "light.kitchen")

        XCTAssertEqual(entity.entityId, "light.kitchen")
        XCTAssertEqual(entity.state, "on")
    }

    func testAssistUsesTheStoredPipelinesAgentAndReturnsTheAnswer() async throws {
        try database.write { db in
            try AssistPipelines(
                serverId: server.identifier.rawValue,
                preferredPipeline: "pipeline-1",
                pipelines: [
                    Pipeline(
                        conversationEngine: "conversation.openai",
                        conversationLanguage: "nl",
                        id: "pipeline-1",
                        language: "nl-NL",
                        name: "OpenAI"
                    ),
                ]
            ).insert(db)
        }
        stubConversation(answer: "De lampen zijn aan")

        let answer = try await AppIntentServerAPI.assistViaREST(
            server: server,
            prompt: "doe de lampen aan",
            pipelineId: "pipeline-1"
        )

        XCTAssertEqual(answer, "De lampen zijn aan")
    }

    func testAssistWithPreferredPipelineReturnsTheAnswer() async throws {
        stubConversation(answer: "Turned on the lights")

        let answer = try await AppIntentServerAPI.assistViaREST(
            server: server,
            prompt: "turn on the lights",
            pipelineId: nil
        )

        XCTAssertEqual(answer, "Turned on the lights")
    }

    func testAssistWithAnUnknownPipelineStillAsksTheServer() async throws {
        try database.write { db in
            try AssistPipelines(
                serverId: server.identifier.rawValue,
                preferredPipeline: "pipeline-1",
                pipelines: [Pipeline(id: "pipeline-1", language: "en", name: "Default")]
            ).insert(db)
        }
        stubConversation(answer: "Done")

        let answer = try await AppIntentServerAPI.assistViaREST(
            server: server,
            prompt: "hello",
            pipelineId: "pipeline-unknown"
        )

        XCTAssertEqual(answer, "Done")
    }

    // MARK: - No reachable server

    func testEveryOperationFailsWithoutAnActiveURL() async throws {
        let unreachable = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })

        await assertNoActiveURL {
            _ = try await AppIntentServerAPI.callActionViaREST(
                server: unreachable,
                domain: "light",
                service: "turn_on",
                data: [:],
                returnResponse: true
            )
        }
        await assertNoActiveURL {
            _ = try await AppIntentServerAPI.renderTemplateViaREST(server: unreachable, template: "{{ 1 }}")
        }
        await assertNoActiveURL {
            _ = try await AppIntentServerAPI.actionDefinitionsViaREST(server: unreachable)
        }
        await assertNoActiveURL {
            _ = try await AppIntentServerAPI.entitiesViaREST(server: unreachable, domain: .light)
        }
        await assertNoActiveURL {
            _ = try await AppIntentServerAPI.entitiesViaREST(server: unreachable, domains: [.light])
        }
        await assertNoActiveURL {
            _ = try await AppIntentServerAPI.entityStateViaREST(server: unreachable, entityId: "light.kitchen")
        }
        await assertNoActiveURL {
            _ = try await AppIntentServerAPI.assistViaREST(server: unreachable, prompt: "hi", pipelineId: "p")
        }
    }

    // MARK: - Response parsing

    func testEntityStateRejectsANonObjectBody() {
        XCTAssertThrowsError(try AppIntentServerAPI.entityState(fromRESTState: [Any]())) { error in
            XCTAssertEqual(error as? HomeAssistantRESTError, .invalidResponse)
        }
    }

    func testEntitiesIgnoreANonArrayBody() {
        XCTAssertTrue(AppIntentServerAPI.entities(fromRESTStates: ["entity_id": "light.a"], domains: [.light]).isEmpty)
    }

    func testAssistAnswerErrorWithoutSpeechUsesTheGenericMessage() {
        let payload: [String: Any] = ["response": ["response_type": "error"]]

        XCTAssertThrowsError(try AppIntentServerAPI.assistAnswer(from: payload)) { error in
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Error.invalidResponse
            )
        }
    }

    func testAssistAnswerWithoutSpeechIsInvalid() {
        let payload: [String: Any] = ["response": ["response_type": "action_done"]]

        XCTAssertThrowsError(try AppIntentServerAPI.assistAnswer(from: payload)) { error in
            XCTAssertEqual(error as? HomeAssistantRESTError, .invalidResponse)
        }
    }

    // MARK: - Helpers

    private func assertNoActiveURL(
        _ operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected the operation to fail", file: file, line: line)
        } catch {
            XCTAssertTrue(error is ServerConnectionError, "\(error)", file: file, line: line)
        }
    }

    private func stubStates() {
        stub(condition: { $0.url?.path == "/api/states" }, response: { _ in
            HTTPStubsResponse(jsonObject: [
                Self.state("light.kitchen", "on", name: "Kitchen"),
                Self.state("light.attic", "off", name: "Attic"),
                Self.state("switch.fan", "on", name: "Fan"),
                Self.state("sensor.temperature", "21", name: "A temperature"),
            ], statusCode: 200, headers: ["Content-Type": "application/json"])
        })
    }

    private func stubConversation(answer: String) {
        stub(condition: { request in
            request.url?.path == "/api/conversation/process" && request.httpMethod == "POST"
        }, response: { _ in
            HTTPStubsResponse(jsonObject: [
                "response": [
                    "speech": ["plain": ["speech": answer]],
                    "response_type": "action_done",
                ],
                "conversation_id": "01JD",
            ], statusCode: 200, headers: ["Content-Type": "application/json"])
        })
    }

    private static func state(_ entityId: String, _ state: String, name: String) -> [String: Any] {
        [
            "entity_id": entityId,
            "state": state,
            "attributes": ["friendly_name": name],
            "last_changed": "2026-07-28T10:00:00.000000+00:00",
            "last_updated": "2026-07-28T10:00:00.000000+00:00",
            "context": ["id": "context", "parent_id": NSNull(), "user_id": NSNull()],
        ]
    }
}
