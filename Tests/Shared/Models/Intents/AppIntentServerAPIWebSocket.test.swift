import Foundation
import HAKit
import HAKit_Mocks
@testable import Shared
import XCTest

/// The WebSocket transport App Intents use on iOS, driven through a mock connection.
///
/// Each operation runs off the test's own execution context, so the tests wait for its request to
/// reach the mock connection before answering it.
final class AppIntentServerAPIWebSocketTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var server: Server!
    private var connection: HAMockConnection!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        previousCachedApis = Current.cachedApis

        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()

        let api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        // Keeps the mock from posting state transitions, which would restart the states cache.
        connection.automaticallyTransitionToConnecting = false
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
    }

    override func tearDown() {
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        connection = nil
        server = nil
        super.tearDown()
    }

    // MARK: - callAction

    func testCallActionSendsCallServiceAndReturnsTheResponse() async throws {
        let currentServer: Server = server
        let task = Task {
            try await AppIntentServerAPI.callAction(
                server: currentServer,
                domain: "calendar",
                service: "get_events",
                data: ["entity_id": "calendar.home"],
                returnResponse: true
            )
        }

        let request = try await pendingRequest(.webSocket("call_service"))
        XCTAssertEqual(request.request.data["domain"] as? String, "calendar")
        XCTAssertEqual(request.request.data["service"] as? String, "get_events")
        XCTAssertEqual(request.request.data["return_response"] as? Bool, true)
        let serviceData = try XCTUnwrap(request.request.data["service_data"] as? [String: Any])
        XCTAssertEqual(serviceData["entity_id"] as? String, "calendar.home")

        request.completion(.success(.dictionary([
            "context": ["id": "context-1"],
            "response": ["calendar.home": ["events": [["summary": "Standup"]]]],
        ])))

        let response = try await task.value
        XCTAssertTrue(response.hasResponse)
        XCTAssertEqual(response.jsonString(), #"{"calendar.home":{"events":[{"summary":"Standup"}]}}"#)
    }

    func testCallActionFailureCancelsTheRequestAndThrows() async throws {
        let currentServer: Server = server
        let task = Task {
            try await AppIntentServerAPI.callAction(
                server: currentServer,
                domain: "light",
                service: "turn_on",
                data: [:],
                returnResponse: false
            )
        }

        let request = try await pendingRequest(.webSocket("call_service"))
        XCTAssertEqual(request.request.data["return_response"] as? Bool, false)
        let failure = HAError.external(.init(code: "service_validation_error", message: "Bad target"))
        request.completion(.failure(failure))

        do {
            _ = try await task.value
            XCTFail("Expected the action to fail")
        } catch {
            XCTAssertEqual(error as? HAError, failure)
        }
        XCTAssertEqual(connection.cancelledRequests.count, 1)
    }

    func testCallActionThatNeverAnswersTimesOut() async throws {
        do {
            _ = try await AppIntentServerAPI.callActionViaWebSocket(
                on: connection,
                domain: "light",
                service: "turn_on",
                data: [:],
                returnResponse: false,
                timeout: 0.05
            )
            XCTFail("Expected a timeout")
        } catch {
            XCTAssertTrue(error is ShortcutAppIntentError, "\(error)")
        }
        XCTAssertEqual(connection.cancelledRequests.count, 1)
    }

    // MARK: - renderTemplate

    func testRenderTemplateReturnsTheFirstRenderAndUnsubscribes() async throws {
        let currentServer: Server = server
        let task = Task {
            try await AppIntentServerAPI.renderTemplate(server: currentServer, template: "{{ 1 + 1 }}")
        }

        let subscription = try await pendingSubscription(.webSocket("render_template"))
        XCTAssertEqual(subscription.request.data["template"] as? String, "{{ 1 + 1 }}")
        subscription.initiated(.success(.empty))
        subscription.handler(subscription.cancellable, .dictionary([
            "result": "2",
            "listeners": ["all": false, "time": false],
        ]))

        let rendered = try await task.value
        XCTAssertEqual(rendered, "2")
        XCTAssertEqual(connection.cancelledSubscriptions.count, 1)
    }

    func testRenderTemplateRejectedByTheServerThrows() async throws {
        let currentServer: Server = server
        let task = Task {
            try await AppIntentServerAPI.renderTemplate(server: currentServer, template: "{{ states(")
        }

        let subscription = try await pendingSubscription(.webSocket("render_template"))
        let failure = HAError.external(.init(code: "template_error", message: "unexpected end of template"))
        subscription.initiated(.failure(failure))

        do {
            _ = try await task.value
            XCTFail("Expected the render to fail")
        } catch {
            XCTAssertEqual(error as? HAError, failure)
        }
    }

    // MARK: - actionDefinitions

    func testActionDefinitionsCombineServicesIconsAndTranslations() async throws {
        let currentServer: Server = server
        let task = Task {
            try await AppIntentServerAPI.actionDefinitions(server: currentServer)
        }

        let services: [String: [String: [String: Any]]] = [
            "light": [
                "turn_on": [
                    "name": "Turn on",
                    "description": "Turns {thing} on",
                    "description_placeholders": ["thing": "a light"],
                    "translation_key": "turn_on",
                ],
                "toggle": [
                    "name": "Toggle",
                    "description": "Toggles a light",
                ],
            ],
            "calendar": [
                "get_events": [
                    "name": "Get events",
                    "icon": "mdi:calendar",
                    "response": ["optional": true],
                ],
            ],
        ]
        let iconResources: [String: [String: [String: Any]]] = [
            "light": ["turn_on": ["service": "mdi:lightbulb-on"]],
        ]

        try await pendingRequest(.getServices).completion(.success(.dictionary(services)))
        try await pendingRequest(.webSocket("frontend/get_icons")).completion(.success(.dictionary([
            "resources": iconResources,
        ])))
        try await pendingRequest(.webSocket("frontend/get_user_data")).completion(.success(.dictionary([
            "value": ["language": "nl"],
        ])))

        let translationsRequest = try await pendingRequest(.webSocket("frontend/get_translations"))
        XCTAssertEqual(translationsRequest.request.data["language"] as? String, "nl")
        XCTAssertEqual(translationsRequest.request.data["category"] as? String, "services")
        translationsRequest.completion(.success(.dictionary([
            "resources": [
                "component.light.services.turn_on.name": "Aanzetten",
                "component.light.services.turn_on.description": "Zet {thing} aan",
            ],
        ])))

        let definitions = try await task.value
        XCTAssertEqual(definitions.map(\.actionId), ["calendar.get_events", "light.toggle", "light.turn_on"])

        let getEvents = definitions[0]
        XCTAssertTrue(getEvents.supportsResponse)
        XCTAssertEqual(getEvents.icon, "mdi:calendar")
        XCTAssertEqual(getEvents.displayName, "Get events")

        let toggle = definitions[1]
        XCTAssertFalse(toggle.supportsResponse)
        XCTAssertNil(toggle.icon)
        XCTAssertEqual(toggle.displayName, "Toggle")
        XCTAssertEqual(toggle.displayDescription, "Toggles a light")

        let turnOn = definitions[2]
        XCTAssertEqual(turnOn.icon, "mdi:lightbulb-on")
        XCTAssertEqual(turnOn.translationKey, "turn_on")
        XCTAssertEqual(turnOn.descriptionPlaceholders, ["thing": "a light"])
        XCTAssertEqual(turnOn.displayName, "Aanzetten")
        XCTAssertEqual(turnOn.displayDescription, "Zet a light aan")
    }

    /// Icons and translations only decorate the list, so failing to fetch them must not lose it.
    func testActionDefinitionsSurviveFailedFrontendLookups() async throws {
        let currentServer: Server = server
        let task = Task {
            try await AppIntentServerAPI.actionDefinitions(server: currentServer)
        }

        let services: [String: [String: [String: Any]]] = [
            "script": ["reload": ["name": "Reload", "icon": "mdi:reload"]],
        ]
        let failure = HAError.internal(debugDescription: "offline")

        try await pendingRequest(.getServices).completion(.success(.dictionary(services)))
        try await pendingRequest(.webSocket("frontend/get_icons")).completion(.failure(failure))
        try await pendingRequest(.webSocket("frontend/get_user_data")).completion(.failure(failure))

        // Without the user's language the device's own is used instead.
        let translationsRequest = try await pendingRequest(.webSocket("frontend/get_translations"))
        let language = try XCTUnwrap(translationsRequest.request.data["language"] as? String)
        XCTAssertFalse(language.isEmpty)
        translationsRequest.completion(.failure(failure))

        let definitions = try await task.value
        XCTAssertEqual(definitions.map(\.actionId), ["script.reload"])
        XCTAssertEqual(definitions.first?.icon, "mdi:reload")
        XCTAssertEqual(definitions.first?.displayName, "Reload")
    }

    func testActionDefinitionsIgnoreUnexpectedPayloads() async throws {
        let currentServer: Server = server
        let task = Task {
            try await AppIntentServerAPI.actionDefinitions(server: currentServer)
        }

        try await pendingRequest(.getServices).completion(.success(.primitive("unexpected")))
        try await pendingRequest(.webSocket("frontend/get_icons")).completion(.success(.empty))
        // No language stored for the user: falls back to the device's language.
        try await pendingRequest(.webSocket("frontend/get_user_data")).completion(.success(.dictionary([
            "value": NSNull(),
        ])))
        try await pendingRequest(.webSocket("frontend/get_translations")).completion(.success(.empty))

        let definitions = try await task.value
        XCTAssertTrue(definitions.isEmpty)
    }

    // MARK: - entities

    func testEntitiesForADomainAreFilteredAndSortedByName() async throws {
        let currentServer: Server = server
        let task = Task {
            try await AppIntentServerAPI.entities(server: currentServer, domain: .light)
        }

        try await deliverStates()

        let entities = try await task.value
        XCTAssertEqual(entities.map(\.entityId), ["light.attic", "light.kitchen"])
    }

    func testEntitiesForSeveralDomains() async throws {
        let currentServer: Server = server
        let task = Task {
            try await AppIntentServerAPI.entities(server: currentServer, domains: [.light, .switch])
        }

        try await deliverStates()

        let entities = try await task.value
        XCTAssertEqual(entities.map(\.entityId), ["light.attic", "switch.fan", "light.kitchen"])
    }

    // MARK: - entityState

    func testEntityStateReadsTheStateOverTheSocket() async throws {
        let currentServer: Server = server
        let task = Task {
            try await AppIntentServerAPI.entityState(server: currentServer, entityId: "light.kitchen")
        }

        let request = try await pendingRequest(.rest(.get, "states/light.kitchen"))
        XCTAssertTrue(request.request.shouldRetry)
        request.completion(.success(.dictionary([
            "entity_id": "light.kitchen",
            "state": "on",
            "attributes": ["friendly_name": "Kitchen", "brightness": 255],
            "last_changed": "2026-07-28T10:00:00.000000+00:00",
            "last_updated": "2026-07-28T10:00:00.000000+00:00",
            "context": ["id": "context", "parent_id": NSNull(), "user_id": NSNull()],
        ])))

        let entity = try await task.value
        XCTAssertEqual(entity.entityId, "light.kitchen")
        XCTAssertEqual(entity.state, "on")
        XCTAssertEqual(entity.attributes.friendlyName, "Kitchen")
    }

    func testEntityStateThatCannotBeDecodedThrows() async throws {
        let currentServer: Server = server
        let task = Task {
            try await AppIntentServerAPI.entityState(server: currentServer, entityId: "light.kitchen")
        }

        try await pendingRequest(.rest(.get, "states/light.kitchen")).completion(.success(.dictionary([
            "message": "Entity not found.",
        ])))

        do {
            _ = try await task.value
            XCTFail("Expected decoding to fail")
        } catch {
            XCTAssertTrue(error is HADataError, "\(error)")
        }
    }

    // MARK: - assist

    func testAssistReturnsTheSpokenAnswer() async throws {
        let currentServer: Server = server
        let task = Task {
            try await AppIntentServerAPI.assist(
                server: currentServer,
                prompt: "turn on the lights",
                pipelineId: "pipeline-1"
            )
        }

        let subscription = try await pendingSubscription(.webSocket("assist_pipeline/run"))
        let input = try XCTUnwrap(subscription.request.data["input"] as? [String: Any])
        XCTAssertEqual(input["text"] as? String, "turn on the lights")
        XCTAssertEqual(subscription.request.data["pipeline"] as? String, "pipeline-1")
        XCTAssertEqual(subscription.request.data["end_stage"] as? String, "intent")

        subscription.initiated(.success(.empty))
        for type in ["run-start", "intent-start", "intent-progress", "stt-end"] {
            subscription.handler(subscription.cancellable, assistEvent(type))
        }
        subscription.handler(subscription.cancellable, assistEvent("intent-end", data: [
            "intent_output": ["response": ["speech": ["plain": ["speech": "Turned on the lights"]]]],
        ]))

        let answer = try await task.value
        XCTAssertEqual(answer, "Turned on the lights")
    }

    func testAssistPipelineErrorThrows() async throws {
        let currentServer: Server = server
        let task = Task {
            try await AppIntentServerAPI.assist(server: currentServer, prompt: "hello", pipelineId: nil)
        }

        let subscription = try await pendingSubscription(.webSocket("assist_pipeline/run"))
        subscription.handler(subscription.cancellable, assistEvent("error", data: [
            "code": "intent-failed",
            "message": "Unexpected error during intent recognition",
        ]))

        do {
            _ = try await task.value
            XCTFail("Expected the prompt to fail")
        } catch {
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                "intent-failed - Unexpected error during intent recognition"
            )
        }
    }

    // MARK: - No connection

    func testEveryOperationFailsWithoutAReachableServer() async throws {
        let unreachable = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
        let expected = L10n.AppIntents.Error.noServer

        await assertNoServer(expected) {
            _ = try await AppIntentServerAPI.callAction(
                server: unreachable,
                domain: "light",
                service: "turn_on",
                data: [:],
                returnResponse: false
            )
        }
        await assertNoServer(expected) {
            _ = try await AppIntentServerAPI.renderTemplate(server: unreachable, template: "{{ 1 }}")
        }
        await assertNoServer(expected) {
            _ = try await AppIntentServerAPI.actionDefinitions(server: unreachable)
        }
        await assertNoServer(expected) {
            _ = try await AppIntentServerAPI.entities(server: unreachable, domain: .light)
        }
        await assertNoServer(expected) {
            _ = try await AppIntentServerAPI.entityState(server: unreachable, entityId: "light.kitchen")
        }
        XCTAssertTrue(connection.pendingRequests.isEmpty)
        XCTAssertTrue(connection.pendingSubscriptions.isEmpty)
    }

    // MARK: - Helpers

    private func assertNoServer(
        _ expected: String,
        _ operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected the operation to fail", file: file, line: line)
        } catch {
            XCTAssertEqual((error as? ShortcutAppIntentError)?.errorDescription, expected, file: file, line: line)
        }
    }

    private func deliverStates() async throws {
        let subscription = try await pendingSubscription(.subscribeEntities)
        subscription.handler(subscription.cancellable, .dictionary([
            "a": [
                "light.kitchen": ["s": "on", "a": ["friendly_name": "Kitchen"]],
                "light.attic": ["s": "off", "a": ["friendly_name": "Attic"]],
                "switch.fan": ["s": "on", "a": ["friendly_name": "Fan"]],
                "sensor.temperature": ["s": "21", "a": ["friendly_name": "A temperature"]],
            ],
        ]))
    }

    private func assistEvent(_ type: String, data: [String: Any]? = nil) -> HAData {
        var value: [String: Any] = [
            "type": type,
            "timestamp": "2026-09-22T16:59:52.000000+00:00",
        ]
        if let data {
            value["data"] = data
        }
        return .dictionary(value)
    }

    private func pendingRequest(_ type: HARequestType) async throws -> HAMockConnection.PendingRequest {
        for _ in 0 ..< 500 {
            if let pending = connection.pendingRequests.first(where: { $0.request.type == type }) {
                return pending
            }
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        throw NeverSent(command: type.command)
    }

    private func pendingSubscription(_ type: HARequestType) async throws -> HAMockConnection.PendingSubscription {
        for _ in 0 ..< 500 {
            if let pending = connection.pendingSubscriptions.last(where: { $0.request.type == type }) {
                return pending
            }
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        throw NeverSent(command: type.command)
    }

    private struct NeverSent: Error {
        let command: String
    }
}
