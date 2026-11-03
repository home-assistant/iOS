import Foundation
import HAKit
import HAKit_Mocks
import ObjectMapper
import PromiseKit
@testable import Shared
import SharedTesting
import Testing
import UserNotifications

@Suite(.sharedState)
struct HomeAssistantAPIActionsTests {
    private enum TestError: Error {
        case failed
    }

    private func value<T>(_ promise: Promise<T>) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            promise.pipe { result in
                switch result {
                case let .fulfilled(value): continuation.resume(returning: value)
                case let .rejected(error): continuation.resume(throwing: error)
                }
            }
        }
    }

    private func withAPI(
        _ body: (HomeAssistantAPI, FakeWebhookManager, HAMockConnection) async throws -> Void
    ) async throws {
        let previousWebhooks = Current.webhooks
        let webhooks = FakeWebhookManager()
        Current.webhooks = webhooks
        defer { Current.webhooks = previousWebhooks }

        let api = HomeAssistantAPI(server: .fake())
        let connection = HAMockConnection()
        api.connection = connection
        try await body(api, webhooks, connection)
    }

    private func waitForRequest(_ connection: HAMockConnection) async throws -> HAMockConnection.PendingRequest {
        let deadline = Date().addingTimeInterval(10)
        while connection.pendingRequests.isEmpty, Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        return try #require(connection.pendingRequests.last)
    }

    // MARK: - Errors

    @Test func everyAPIErrorHasADescription() {
        let errors: [HomeAssistantAPI.APIError] = [
            .managerNotAvailable,
            .invalidResponse,
            .cantBuildURL,
            .notConfigured,
            .updateNotPossible,
            .mobileAppComponentNotLoaded,
            .mustUpgradeHomeAssistant(
                current: Version(major: 2020, minor: 1, patch: 0),
                minimum: Version(major: 2021, minor: 3, patch: 0)
            ),
            .noAPIAvailable,
            .unknown,
        ]
        let descriptions = errors.map(\.localizedDescription)
        #expect(descriptions.allSatisfy { !$0.isEmpty })
        #expect(Set(descriptions).count == errors.count)
        #expect(descriptions[6].contains("2020"))
    }

    // MARK: - Event payloads

    @Test func shareEventCarriesWhatWasShared() async throws {
        try await withAPI { api, _, _ in
            let url = URL(string: "https://example.com/page")
            let full = api.shareEvent(entered: "kitchen", url: url, text: "hello")
            #expect(full.eventType == "mobile_app.share")
            #expect(full.eventData["entered"] == "kitchen")
            #expect(full.eventData["url"] == "https://example.com/page")
            #expect(full.eventData["text"] == "hello")

            let bare = api.shareEvent(entered: "x", url: nil, text: nil)
            #expect(bare.eventData["url"] == nil)
            #expect(bare.eventData["text"] == nil)
        }
    }

    @Test func notificationActionEventsIncludeOptionalFields() async throws {
        try await withAPI { api, _, _ in
            let legacy = api.legacyNotificationActionEvent(
                identifier: "REPLY",
                category: "MESSAGE",
                actionData: ["key": "value"],
                textInput: "typed"
            )
            #expect(legacy.eventType == "ios.notification_action_fired")
            #expect(legacy.eventData["categoryName"] as? String == "MESSAGE")
            #expect(legacy.eventData["response_info"] as? String == "typed")
            #expect(legacy.eventData["textInput"] as? String == "typed")
            #expect(legacy.eventData["action_data"] != nil)

            let modern = api.mobileAppNotificationActionEvent(
                identifier: "REPLY",
                category: nil,
                actionData: ["key": "value"],
                textInput: "typed"
            )
            #expect(modern.eventData["action"] as? String == "REPLY")
            #expect(modern.eventData["reply_text"] as? String == "typed")
            #expect(modern.eventData["action_data"] != nil)

            let minimal = api.mobileAppNotificationActionEvent(
                identifier: "OPEN",
                category: nil,
                actionData: nil,
                textInput: nil
            )
            #expect(minimal.eventData["reply_text"] == nil)
            #expect(minimal.eventData["action_data"] == nil)
        }
    }

    @Test func pushActionInfoRoundTripsThroughJSON() throws {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "ALARM"
        content.userInfo = ["homeassistant": ["tag": "a"]]
        let info = HomeAssistantAPI.PushActionInfo(content: content, actionIdentifier: "SNOOZE", textInput: "later")
        #expect(info.identifier == "SNOOZE")
        #expect(info.category == "ALARM")
        #expect(info.textInput == "later")

        let json = info.toJSON()
        let decoded = try HomeAssistantAPI.PushActionInfo(JSON: json)
        #expect(decoded.identifier == "SNOOZE")
        #expect(decoded.category == "ALARM")
        #expect(decoded.textInput == "later")
        #expect(decoded.actionData != nil)
    }

    @Test func handlePushActionFiresBothEvents() async throws {
        try await withAPI { api, webhooks, _ in
            var firedTypes: [String] = []
            webhooks.sendEphemeralHandler = { _, request in
                if let data = request.data as? [String: Any], let type = data["event_type"] as? String {
                    firedTypes.append(type)
                }
                return [String: Any]()
            }
            let content = UNMutableNotificationContent()
            content.categoryIdentifier = "ALARM"
            let info = HomeAssistantAPI.PushActionInfo(content: content, actionIdentifier: "OK", textInput: nil)

            try await value(api.handlePushAction(for: info))
            #expect(Set(firedTypes) == ["ios.notification_action_fired", "mobile_app_notification_action"])
        }
    }

    @Test func createEventSendsFireEvent() async throws {
        try await withAPI { api, webhooks, _ in
            var sentType: String?
            webhooks.sendEphemeralHandler = { _, request in
                sentType = request.type
                return [String: Any]()
            }
            try await value(api.CreateEvent(eventType: "custom", eventData: ["a": 1]))
            #expect(sentType == "fire_event")
        }
    }

    @Test func streamCameraMapsTheResponse() async throws {
        try await withAPI { api, webhooks, _ in
            webhooks.sendEphemeralHandler = { _, request in
                #expect(request.type == "stream_camera")
                return ["hls_path": "/api/hls/abc/master.m3u8", "mjpeg_path": "/api/camera_proxy_stream/camera.x"]
            }
            let response = try await value(api.StreamCamera(entityId: "camera.x"))
            #expect(response.hlsPath == "/api/hls/abc/master.m3u8")
        }
    }

    @Test func streamCameraRejectsAnEmptyResponse() async throws {
        try await withAPI { api, webhooks, _ in
            webhooks.sendEphemeralHandler = { _, _ in [String: Any]() }
            await #expect(throws: (any Error).self) {
                try await value(api.StreamCamera(entityId: "camera.x"))
            }
        }
    }

    @Test func turnOnScriptCallsTheScriptService() async throws {
        try await withAPI { api, webhooks, _ in
            var sent: (WebhookResponseIdentifier, WebhookRequest)?
            webhooks.sendRequestHandler = { identifier, _, request, seal in
                sent = (identifier, request)
                seal.fulfill(())
            }
            try await value(api.turnOnScript(scriptEntityId: "script.go", triggerSource: .AppShortcut))
            #expect(sent?.0 == .serviceCall)
            let data = try #require(sent?.1.data as? [String: Any])
            #expect(data["domain"] as? String == "script")
            #expect(data["service"] as? String == "turn_on")
        }
    }

    // MARK: - WebSocket actions

    @Test func lockStatesMapToTheOppositeAction() async throws {
        try await withAPI { api, _, connection in
            for (state, service) in [
                ("unlocked", "lock"),
                ("unlocking", "lock"),
                ("opening", "lock"),
                ("locked", "unlock"),
                ("locking", "unlock"),
            ] {
                let before = connection.pendingRequests.count
                let promise = api.executeActionForDomainType(domain: .lock, entityId: "lock.door", state: state)
                if connection.pendingRequests.count > before {
                    let request = connection.pendingRequests[connection.pendingRequests.count - 1]
                    #expect(request.request.data["service"] as? String == service, "\(state)")
                    request.completion(.success(.empty))
                }
                try await value(promise)
            }
        }
    }

    @Test func lockWithUnknownOrJammedStateSendsNothing() async throws {
        try await withAPI { api, _, connection in
            try await value(api.executeActionForDomainType(domain: .lock, entityId: "lock.door", state: "garbage"))
            try await value(api.executeActionForDomainType(domain: .lock, entityId: "lock.door", state: "jammed"))
            #expect(connection.pendingRequests.isEmpty)
        }
    }

    @Test func otherDomainsRunTheirMainAction() async throws {
        try await withAPI { api, _, connection in
            let promise = api.executeActionForDomainType(domain: .light, entityId: "light.kitchen", state: "on")
            let request = try await waitForRequest(connection)
            #expect(request.request.data["domain"] as? String == "light")
            request.completion(.success(.empty))
            try await value(promise)
        }
    }

    @Test func callServiceWithResponseSendsReturnResponse() async throws {
        try await withAPI { api, _, connection in
            let promise = api.callServiceWithResponse(
                domain: "weather",
                service: "get_forecasts",
                serviceData: ["entity_id": "weather.home"],
                returnResponse: true
            )
            let request = try await waitForRequest(connection)
            #expect(request.request.data["return_response"] as? Bool == true)
            request.completion(.failure(.internal(debugDescription: "nope")))
            await #expect(throws: (any Error).self) { try await value(promise) }
        }
    }

    // MARK: - RetryAwareHAConnection

    @Test func retryAwareConnectionForwardsToItsUnderlyingConnection() {
        let underlying = HAMockConnection()
        let connection = RetryAwareHAConnection(underlying: underlying)

        #expect(connection.state == underlying.state)
        _ = connection.caches
        connection.callbackQueue = .global()
        #expect(underlying.callbackQueue === connection.callbackQueue)
        let configuration = connection.configuration
        connection.configuration = configuration

        connection.send(HARequest(type: .rest(.get, "states")), completion: { _ in })
        #expect(underlying.pendingRequests.count == 1)

        connection.send(HARequest(type: .webSocket("ping")), completion: { _ in })
        #expect(underlying.pendingRequests.count == 2)

        connection.send(HATypedRequest<HAResponseVoid>(request: .init(type: .webSocket("x"))), completion: { _ in })
        connection.subscribe(to: HARequest(type: .webSocket("sub")), handler: { _, _ in })
        connection.subscribe(
            to: HARequest(type: .webSocket("sub2")),
            initiated: { _ in },
            handler: { _, _ in }
        )
        connection.subscribe(
            to: HATypedSubscription<HAResponseEvent>(request: .init(type: .webSocket("sub3"))),
            handler: { _, _ in }
        )
        connection.subscribe(
            to: HATypedSubscription<HAResponseEvent>(request: .init(type: .webSocket("sub4"))),
            initiated: { _ in },
            handler: { _, _ in }
        )
        #expect(underlying.pendingSubscriptions.count == 4)

        connection.connect()
        connection.disconnect()
    }

    @Test func retryAwareConnectionForwardsStateTransitionsToItsDelegate() {
        final class Delegate: HAConnectionDelegate {
            var states: [HAConnectionState] = []
            func connection(_ connection: HAConnection, didTransitionTo state: HAConnectionState) {
                states.append(state)
            }
        }
        let underlying = HAMockConnection()
        let connection = RetryAwareHAConnection(underlying: underlying)
        let delegate = Delegate()
        connection.delegate = delegate

        connection.connection(underlying, didTransitionTo: .connecting)
        #expect(delegate.states == [.connecting])
    }

    @Test func automaticConnectOnlyFromIdleStates() {
        #expect(HomeAssistantAPI.shouldAttemptAutomaticWebSocketConnect(for: .disconnected(reason: .disconnected)))
        #expect(HomeAssistantAPI.shouldAttemptAutomaticWebSocketConnect(for: .connecting))
        #expect(!HomeAssistantAPI.shouldAttemptAutomaticWebSocketConnect(for: .authenticating))
        #expect(!HomeAssistantAPI.shouldAttemptAutomaticWebSocketConnect(for: .disconnected(reason: .rejected)))
    }

    // MARK: - Convenience init

    @Test func convenienceInitNeedsAServer() {
        let previous = Current.servers
        defer { Current.servers = previous }

        Current.servers = FakeServerManager()
        #expect(HomeAssistantAPI() == nil)

        let servers = FakeServerManager(initial: 1)
        Current.servers = servers
        #expect(HomeAssistantAPI()?.server.identifier == servers.all.first?.identifier)
    }
}
