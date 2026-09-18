import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import Testing

/// Perform action shortcuts that iCloud-sync between devices keep the originating server id. On a
/// one-server device that id still has to reach the local connection, including the action query
/// that hydrates `serverId::domain.service` identifiers.
///
/// Serialized because every test swaps the process-wide servers, APIs and connectivity.
@Suite(.serialized)
struct PerformActionAppIntentTests {
    private static let payload = #"{"entity_id":"fan.office"}"#

    @available(iOS 17.0, *)
    private func withMockedServer(
        id: String,
        extraServers: Int = 0,
        _ body: (Server, HAMockConnection) async throws -> Void
    ) async throws {
        let previousServers = Current.servers
        let previousApis = Current.cachedApis
        let previousRefresh = Current.connectivity.refreshNetworkInformation
        defer {
            Current.servers = previousServers
            Current.cachedApis = previousApis
            Current.connectivity.refreshNetworkInformation = previousRefresh
        }

        let manager = FakeServerManager(initial: 0)
        var info = ServerInfo.fake()
        info.remoteName = "Local Home"
        let server = manager.add(identifier: .init(rawValue: id), serverInfo: info)
        for _ in 0 ..< extraServers {
            _ = manager.addFake()
        }

        let connection = HAMockConnection()
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.servers = manager
        Current.cachedApis = [server.identifier: api]
        Current.connectivity.refreshNetworkInformation = {}

        try await body(server, connection)
    }

    @available(iOS 17.0, *)
    private func intent(
        serverId: String,
        actionServerId: String? = nil,
        actionId: String = "fan.turn_on",
        payload: String = Self.payload,
        supportsResponse: Bool = false
    ) -> PerformActionAppIntent {
        let intent = PerformActionAppIntent()
        intent.server = IntentServerAppEntity(identifier: .init(rawValue: serverId))
        let actionServerId = actionServerId ?? serverId
        if actionId.contains(".") {
            let components = actionId.split(separator: ".", maxSplits: 1).map(String.init)
            intent.action = IntentActionEntity(
                serverId: actionServerId,
                definition: IntentActionDefinition(
                    domain: components[0],
                    service: components[1],
                    name: "Turn on",
                    actionDescription: "Turn a fan on",
                    supportsResponse: supportsResponse
                )
            )
        } else {
            intent.action = IntentActionEntity(identifier: "\(actionServerId)::\(actionId)")!
        }
        intent.payload = payload
        return intent
    }

    /// Starts `perform()` and answers the call_service it sends, returning that request.
    @available(iOS 17.0, *)
    private func performAndCaptureRequest(
        _ intent: PerformActionAppIntent,
        connection: HAMockConnection,
        response: HAData = .dictionary(["context": ["id": "ok"]])
    ) async throws -> HARequest? {
        let task = Task { try await intent.perform() }
        var waited = 0
        while connection.pendingRequests.isEmpty, waited < 200 {
            try await Task.sleep(nanoseconds: 5_000_000)
            waited += 1
        }
        let request = connection.pendingRequests.first?.request
        for pending in connection.pendingRequests {
            pending.completion(.success(response))
        }
        _ = try await task.value
        return request
    }

    @available(iOS 17.0, *)
    private func performAndExpectNoRequest(
        _ intent: PerformActionAppIntent,
        connection: HAMockConnection
    ) async {
        do {
            _ = try await intent.perform()
            Issue.record("expected the action not to run")
        } catch {
            #expect((error as? ShortcutAppIntentError)?.errorDescription == L10n.AppIntents.Error.noServer)
        }
        #expect(connection.pendingRequests.isEmpty)
    }

    /// Answers get_services with a response-capable fan.turn_on and fails the icon/translation
    /// requests, which recover to empty metadata.
    @available(iOS 17.0, *)
    private func answerActionDefinitionRequests(on connection: HAMockConnection) async throws {
        var answered = 0
        var idle = 0
        while idle < 80 {
            if connection.pendingRequests.count > answered {
                let pending = connection.pendingRequests[answered]
                if pending.request.type.command == "get_services" {
                    pending.completion(.success(.init(value: [
                        "fan": [
                            "turn_on": [
                                "name": "Turn on",
                                "description": "Turn a fan on",
                                "response": ["optional": true],
                            ],
                        ],
                    ])))
                } else {
                    pending.completion(.failure(.internal(debugDescription: "unused")))
                }
                answered += 1
                idle = 0
                continue
            }
            try await Task.sleep(nanoseconds: 5_000_000)
            idle += 1
        }
    }

    // MARK: - Query hydration

    /// A foreign server id and its matching `foreign::fan.turn_on` action pick up the local
    /// definitions, keep the persisted id, and keep supportsResponse rather than degrading to the
    /// identifier-only fallback.
    @available(iOS 17.0, *)
    @Test func hydratesAForeignActionIdFromLocalDefinitions() async throws {
        try await withMockedServer(id: "phone") { _, connection in
            let selectedServer = IntentServerAppEntity(identifier: .init(rawValue: "mac"))
            let task = Task {
                try await IntentActionEntityQuery().entities(
                    for: ["mac::fan.turn_on"],
                    selectedServer: selectedServer
                )
            }
            try await answerActionDefinitionRequests(on: connection)
            let entities = try await task.value
            let entity = try #require(entities.first)

            #expect(entities.count == 1)
            #expect(entity.id == "mac::fan.turn_on")
            #expect(entity.serverId == "mac")
            #expect(entity.actionId == "fan.turn_on")
            #expect(entity.displayName == "Turn on")
            #expect(entity.actionDescription == "Turn a fan on")
            #expect(entity.supportsResponse)
        }
    }

    /// Without the parent intent's server, unmatched identifiers still rebuild from
    /// `serverId::domain.service` so a saved shortcut keeps a name even when the server cannot
    /// describe it. That fallback does not claim to support a response.
    @available(iOS 17.0, *)
    @Test func unmatchedActionIdentifiersRebuildFromThePersistedId() async throws {
        let entities = try await IntentActionEntityQuery().entities(for: ["mac::fan.turn_on"])
        let entity = try #require(entities.first)

        #expect(entity.id == "mac::fan.turn_on")
        #expect(entity.serverId == "mac")
        #expect(entity.actionId == "fan.turn_on")
        #expect(entity.supportsResponse == false)
    }

    // MARK: - Runtime

    @available(iOS 17.0, *)
    @Test func equalForeignIdsReachTheLocalConnection() async throws {
        try await withMockedServer(id: "phone") { _, connection in
            let request = try await performAndCaptureRequest(
                intent(serverId: "mac"),
                connection: connection
            )

            #expect(request?.data["domain"] as? String == "fan")
            #expect(request?.data["service"] as? String == "turn_on")
            #expect((request?.data["service_data"] as? [String: Any])?["entity_id"] as? String == "fan.office")
            #expect(request?.data["return_response"] as? Bool == false)
        }
    }

    /// The other direction of the same sync: this device's id is the one the shortcut stored.
    @available(iOS 17.0, *)
    @Test func equalForeignIdsReachALocalServerRegisteredUnderADifferentId() async throws {
        try await withMockedServer(id: "mac") { _, connection in
            let request = try await performAndCaptureRequest(
                intent(serverId: "phone"),
                connection: connection
            )

            #expect(request?.data["domain"] as? String == "fan")
            #expect(request?.data["service"] as? String == "turn_on")
            #expect((request?.data["service_data"] as? [String: Any])?["entity_id"] as? String == "fan.office")
        }
    }

    @available(iOS 17.0, *)
    @Test func mismatchedServerAndActionIdsSendNothing() async throws {
        try await withMockedServer(id: "phone") { _, connection in
            await performAndExpectNoRequest(
                intent(serverId: "mac", actionServerId: "phone"),
                connection: connection
            )
        }
    }

    @available(iOS 17.0, *)
    @Test func unknownIdsWithSeveralServersSendNothing() async throws {
        try await withMockedServer(id: "phone", extraServers: 1) { _, connection in
            await performAndExpectNoRequest(
                intent(serverId: "mac"),
                connection: connection
            )
        }
    }

    @available(iOS 17.0, *)
    @Test func anInvalidPayloadIsRefusedBeforeSending() async throws {
        try await withMockedServer(id: "phone") { _, connection in
            let intent = intent(serverId: "phone", payload: "[]")
            do {
                _ = try await intent.perform()
                Issue.record("expected an invalid payload to be refused")
            } catch {
                #expect(
                    (error as? ShortcutAppIntentError)?.errorDescription
                        == L10n.AppIntents.PerformAction.Error.invalidPayload
                )
            }
            #expect(connection.pendingRequests.isEmpty)
        }
    }

    @available(iOS 17.0, *)
    @Test func aMalformedActionIsRefusedBeforeSending() async throws {
        try await withMockedServer(id: "phone") { _, connection in
            let intent = intent(serverId: "phone", actionId: "turn_on")
            do {
                _ = try await intent.perform()
                Issue.record("expected a malformed action to be refused")
            } catch {
                #expect(
                    (error as? ShortcutAppIntentError)?.errorDescription
                        == L10n.AppIntents.PerformAction.Error.invalidAction
                )
            }
            #expect(connection.pendingRequests.isEmpty)
        }
    }

    /// A response-capable action hydrated under a synced alias still asks for the response and
    /// returns it as JSON.
    @available(iOS 17.0, *)
    @Test func aResponseCapableActionReturnsTheResponseAfterAliasHydration() async throws {
        try await withMockedServer(id: "phone") { _, connection in
            let intent = intent(serverId: "mac", supportsResponse: true)
            let task = Task { try await intent.perform() }
            var waited = 0
            while connection.pendingRequests.isEmpty, waited < 200 {
                try await Task.sleep(nanoseconds: 5_000_000)
                waited += 1
            }
            let request = try #require(connection.pendingRequests.first)
            #expect(request.request.data["return_response"] as? Bool == true)
            request.completion(.success(.dictionary([
                "context": ["id": "ok"],
                "response": ["turned_on": ["fan.office"]],
            ])))

            let result = try await task.value
            #expect(result.value == #"{"turned_on":["fan.office"]}"#)
        }
    }
}
