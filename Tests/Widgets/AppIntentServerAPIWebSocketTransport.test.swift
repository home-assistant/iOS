import Foundation
import GRDB
import HAKit
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// The WebSocket transport App Intents use on iOS: template renders, the action list with its icons
/// and translations, single states, and an Assist prompt run through `AssistService` to its answer.
///
/// `.isolatedEnvironment`: the server, API cache and database are installed per test and read on the
/// test's task before any PromiseKit hop; the stub connection answers everything synchronously.
@Suite(.isolatedEnvironment)
struct AppIntentServerAPIWebSocketTransportTests {
    // MARK: - Template

    @Test func aTemplateRendersFromItsFirstEvent() async throws {
        let (server, connection) = try install(subscriptions: { _ in
            (.success(.empty), [
                HAData(value: ["result": "21", "listeners": [String: Any]()]),
                HAData(value: ["result": "22", "listeners": [String: Any]()]),
            ])
        })
        let rendered = try await AppIntentServerAPI.renderTemplate(server: server, template: "{{ 21 }}")
        #expect(rendered == "21")
        #expect(connection.subscriptions.first?.data["template"] as? String == "{{ 21 }}")
    }

    @Test func aRejectedTemplateThrows() async throws {
        let (server, _) = try install(subscriptions: { _ in (.failure(widgetStubUnexpected), []) })
        await #expect(throws: HAError.self) {
            try await AppIntentServerAPI.renderTemplate(server: server, template: "{{ bad }")
        }
    }

    @Test func withoutAnAPIEveryOperationFails() async throws {
        let server = Server.fake { info in info.connection.set(address: nil, for: .external) }
        Current.servers = FakeServerManager()
        await #expect(throws: ShortcutAppIntentError.self) {
            try await AppIntentServerAPI.renderTemplate(server: server, template: "x")
        }
        await #expect(throws: ShortcutAppIntentError.self) {
            try await AppIntentServerAPI.entityState(server: server, entityId: "light.a")
        }
    }

    // MARK: - Actions and states

    /// The services list is enriched with the frontend's icons and the translations for the user's
    /// language.
    @Test func actionDefinitionsCarryIconsAndTranslations() async throws {
        let (server, connection) = try install { request in
            switch request.type.command {
            case "get_services":
                .success(HAData(value: [
                    "light": [
                        "turn_on": [
                            "name": "Turn on",
                            "description_placeholders": ["url": "https://example.com", "count": 3],
                            "response": ["optional": true],
                        ],
                        "toggle": ["icon": "mdi:legacy"],
                    ],
                ]))
            case "frontend/get_icons":
                .success(HAData(value: ["resources": ["light": ["toggle": ["service": "mdi:toggle-switch"]]]]))
            case "frontend/get_user_data":
                .success(HAData(value: ["value": ["language": "nl"]]))
            case "frontend/get_translations":
                .success(HAData(value: ["resources": [
                    "component.light.services.turn_on.name": "Aanzetten",
                    "component.light.services.count": 2,
                ]]))
            default:
                .failure(widgetStubUnexpected)
            }
        }

        let definitions = try await actionDefinitions(server: server)
        #expect(definitions.map(\.actionId) == ["light.toggle", "light.turn_on"])
        #expect(definitions.first?.icon == "mdi:toggle-switch")
        #expect(definitions.last?.supportsResponse == true)
        #expect(definitions.last?.descriptionPlaceholders["count"] == "3")
        #expect(definitions.last?.translations["component.light.services.count"] == "2")
        let translations = try #require(connection.sent.first { $0.type.command == "frontend/get_translations" })
        #expect(translations.data["language"] as? String == "nl")
    }

    /// The icons and translations are extras: when they fail, or the user has no language set, the
    /// raw services list still comes back.
    @Test func actionDefinitionsSurviveMissingExtras() async throws {
        let (server, connection) = try install { request in
            switch request.type.command {
            case "get_services": .success(HAData(value: ["scene": ["turn_on": [String: Any]()]]))
            case "frontend/get_user_data": .success(HAData(value: ["value": ["language": ""]]))
            case "frontend/get_icons": .success(HAData(value: ["unexpected": true]))
            default: .failure(widgetStubUnexpected)
            }
        }
        let definitions = try await actionDefinitions(server: server)
        #expect(definitions.map(\.actionId) == ["scene.turn_on"])
        #expect(definitions.first?.translations.isEmpty == true)
        #expect(connection.sentCommands.contains("frontend/get_translations"))

        let (other, _) = try install { request in
            request.type
                .command == "get_services" ? .success(HAData(value: ["unexpected"])) : .failure(widgetStubUnexpected)
        }
        let none = try await actionDefinitions(server: other)
        #expect(none.isEmpty)
    }

    @Test func oneEntitysStateIsReadOverTheSocket() async throws {
        let (server, connection) = try install { request in
            request.type.command == "states/light.kitchen"
                ? .success(HAData(value: [
                    "entity_id": "light.kitchen",
                    "state": "on",
                    "attributes": ["friendly_name": "Kitchen"],
                    "last_changed": "2026-01-01T00:00:00+00:00",
                    "last_updated": "2026-01-01T00:00:00+00:00",
                    "context": ["id": "1", "user_id": NSNull(), "parent_id": NSNull()],
                ]))
                : .failure(widgetStubUnexpected)
        }
        let entity = try await AppIntentServerAPI.entityState(server: server, entityId: "light.kitchen")
        #expect(entity.state == "on")
        #expect(connection.sentCommands == ["states/light.kitchen"])
    }

    // MARK: - Assist

    /// A text prompt runs a pipeline whose events stream the transcript, the reply and its audio
    /// before the intent's answer arrives — which is what the prompt returns.
    @Test func anAssistPromptReturnsTheIntentsAnswer() async throws {
        let (server, connection) = try install(subscriptions: { _ in
            (.success(.empty), [
                Self.event("run-start", ["runner_data": ["stt_binary_handler_id": 1]]),
                Self.event("wake_word-start", [:]),
                Self.event("a-future-event", [:]),
                Self.event("stt-end", ["stt_output": ["text": "lights on"]]),
                Self.event("intent-progress", ["chat_log_delta": ["role": "assistant", "content": "Tu"]]),
                Self.event("intent-progress", ["chat_log_delta": ["content": "rning on"]]),
                Self.event("tts-end", ["tts_output": ["url": "/api/tts_proxy/reply.mp3"]]),
                Self.event("run-end", [:]),
                Self.event("intent-end", ["intent_output": [
                    "conversation_id": "conversation",
                    "continue_conversation": true,
                    "response": ["speech": ["plain": ["speech": "Turned on"]]],
                ]]),
            ])
        })
        let answer = try await AppIntentServerAPI.assist(server: server, prompt: "Lights on", pipelineId: nil)
        #expect(answer == "Turned on")
        #expect(connection.subscriptions.count == 1)
    }

    @Test func assistErrorsBecomeIntentErrors() async throws {
        let (pipelineError, _) = try install(subscriptions: { _ in
            (.success(.empty), [Self.event("error", ["code": "intent-failed", "message": "No"])])
        })
        await #expect(throws: ShortcutAppIntentError.self) {
            try await AppIntentServerAPI.assist(server: pipelineError, prompt: "x", pipelineId: "p")
        }

        let (missingAudio, _) = try install(subscriptions: { _ in
            (.success(.empty), [Self.event("tts-end", [:])])
        })
        await #expect(throws: ShortcutAppIntentError.self) {
            try await AppIntentServerAPI.assist(server: missingAudio, prompt: "x", pipelineId: nil)
        }

        let (rejected, _) = try install(subscriptions: { _ in
            (.failure(.external(.init(code: "stt-provider-missing", message: "No STT"))), [])
        })
        await #expect(throws: ShortcutAppIntentError.self) {
            try await AppIntentServerAPI.assist(server: rejected, prompt: "x", pipelineId: nil)
        }

        let (broken, _) = try install(subscriptions: { _ in (.failure(widgetStubUnexpected), []) })
        await #expect(throws: ShortcutAppIntentError.self) {
            try await AppIntentServerAPI.assist(server: broken, prompt: "x", pipelineId: nil)
        }
    }

    /// The Assist prompt shortcut runs its pipeline on the server that owns it and returns the
    /// answer.
    @Test func theAssistPromptShortcutReturnsTheAnswer() async throws {
        let (server, connection) = try install(version: Version(major: 2026, minor: 1), subscriptions: { _ in
            (.success(.empty), [Self.event("intent-end", ["intent_output": [
                "response": ["speech": ["plain": ["speech": "It is 21 degrees"]]],
            ]])])
        })
        let intent = AssistPromptAppIntent()
        intent.prompt = "Temperature?"
        intent.pipeline = AssistPipelineEntity(id: "cloud", serverId: server.identifier.rawValue, name: "Cloud")
        _ = try await intent.perform()
        intent.pipeline = nil
        _ = try await intent.perform()
        #expect(connection.subscriptions.count == 2)
        #expect(connection.subscriptions.first?.data["pipeline"] as? String == "cloud")
    }

    // MARK: - Helpers

    /// The definitions are assembled in PromiseKit `map`s and `then`s, each a hop onto the main queue,
    /// which other suites keep busy on a loaded runner: the transport's 10 s timeout fired there
    /// while the stub's answers were still queued. The test's subject is the assembly, so the
    /// timeout is lifted for the call; an answer that never comes still fails the test, well inside
    /// the per-test execution allowance.
    private func actionDefinitions(server: Server) async throws -> [IntentActionDefinition] {
        try await AppIntentServerAPI.$requestTimeout.withValue(120) {
            try await AppIntentServerAPI.actionDefinitions(server: server)
        }
    }

    private static func event(_ type: String, _ data: [String: Any]) -> HAData {
        HAData(value: ["type": type, "timestamp": "2026-01-01T00:00:00.000000+00:00", "data": data])
    }

    private func install(
        version: Version? = nil,
        _ respond: @escaping WidgetStubConnection.Responder = { _ in .failure(widgetStubUnexpected) },
        subscriptions: @escaping WidgetStubConnection.SubscriptionResponder = { _ in (nil, []) }
    ) throws -> (Server, WidgetStubConnection) {
        let database = try DatabaseQueue()
        try AssistPipelinesTable().createIfNeeded(database: database)
        Current.database = { database }
        let servers = FakeServerManager()
        var info = ServerInfo.fake()
        if let version {
            info.version = version
        }
        let server = servers.add(identifier: .init(rawValue: UUID().uuidString), serverInfo: info)
        Current.servers = servers
        let connection = WidgetStubConnection(respond: respond, subscriptions: subscriptions)
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        return (server, connection)
    }
}
