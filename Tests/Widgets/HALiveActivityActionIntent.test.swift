#if os(iOS) && !targetEnvironment(macCatalyst)
@testable import HomeAssistant

import AppIntents
import Foundation
import os
import PromiseKit
@testable import Shared
import SharedTesting
import Testing

@MainActor
@Suite(.isolatedEnvironment)
struct HALiveActivityActionIntentTests {
    @available(iOS 17.2, *)
    @Test(arguments: [false, true])
    func aTapSendsItsActionAndTagToTheOwningServer(withoutAuthentication: Bool) async throws {
        let servers = FakeServerManager()
        _ = servers.addFake()
        let owner = servers.addFake()
        owner.info.connection.webhookID = "activity-owner"
        Current.servers = servers
        let webhooks = RecordingWebhooks()
        Current.webhooks = webhooks
        let attributes = HALiveActivityAttributes(
            tag: "music",
            title: "Music",
            serverWebhookId: owner.info.connection.webhookID
        )
        let state = HALiveActivityAttributes.ContentState(message: "Track", actions: [
            .init(id: "PAUSE", title: "Pause", authenticationRequired: !withoutAuthentication),
        ])
        try await HALiveActivityActionIntent.sendAction(
            actionID: "PAUSE",
            attributes: attributes,
            state: state,
            withoutAuthentication: withoutAuthentication
        )

        let sent = try #require(webhooks.sent.first)
        let data = try #require(sent.request.data as? [String: Any])
        let event = try #require(data["event_data"] as? [String: Any])
        #expect(webhooks.sent.count == 1)
        #expect(sent.server.identifier == owner.identifier)
        #expect(sent.request.type == "fire_event")
        #expect(data["event_type"] as? String == "mobile_app_notification_action")
        #expect(event["action"] as? String == "PAUSE")
        #expect(event["action_data"] as? [String: String] == ["tag": "music"])
    }

    @available(iOS 17.2, *)
    @Test(arguments: [false, true])
    func aRemovedButtonCannotDispatchAnEvent(withoutAuthentication: Bool) async {
        let servers = FakeServerManager()
        let owner = servers.addFake()
        Current.servers = servers
        let webhooks = RecordingWebhooks()
        Current.webhooks = webhooks
        let attributes = HALiveActivityAttributes(
            tag: "music",
            title: "Music",
            serverWebhookId: owner.info.connection.webhookID
        )
        await #expect(throws: ShortcutAppIntentError.self) {
            try await HALiveActivityActionIntent.sendAction(
                actionID: "PLAY",
                attributes: attributes,
                state: state,
                withoutAuthentication: withoutAuthentication
            )
        }
        #expect(webhooks.sent.isEmpty)
    }

    @available(iOS 17.2, *)
    @Test(arguments: [false, true])
    func anUnknownOwnerDoesNotFallBackToAnotherServer(withoutAuthentication: Bool) async {
        Current.servers = FakeServerManager(initial: 1)
        let webhooks = RecordingWebhooks()
        Current.webhooks = webhooks
        let attributes = HALiveActivityAttributes(tag: "music", title: "Music", serverWebhookId: "missing-owner")
        let state = HALiveActivityAttributes.ContentState(message: "Track", actions: [
            .init(id: "PAUSE", title: "Pause", authenticationRequired: !withoutAuthentication),
        ])

        await #expect(throws: ShortcutAppIntentError.self) {
            try await HALiveActivityActionIntent.sendAction(
                actionID: "PAUSE",
                attributes: attributes,
                state: state,
                withoutAuthentication: withoutAuthentication
            )
        }
        #expect(webhooks.sent.isEmpty)
    }

    @available(iOS 17.2, *)
    @Test func aTapWithoutAuthenticationIsRejectedWhenTheLatestStateRequiresIt() async {
        let servers = FakeServerManager()
        let owner = servers.addFake()
        Current.servers = servers
        let webhooks = RecordingWebhooks()
        Current.webhooks = webhooks
        let attributes = HALiveActivityAttributes(
            tag: "music",
            title: "Music",
            serverWebhookId: owner.info.connection.webhookID
        )

        await #expect(throws: ShortcutAppIntentError.self) {
            try await HALiveActivityActionIntent.sendAction(
                actionID: "PAUSE",
                attributes: attributes,
                state: state,
                withoutAuthentication: true
            )
        }
        #expect(webhooks.sent.isEmpty)
    }

    @available(iOS 17.2, *)
    @Test func intentsUseSeparateAuthenticationPolicies() {
        #expect(HALiveActivityActionIntent.authenticationPolicy == .requiresAuthentication)
        #expect(HALiveActivityUnauthenticatedActionIntent.authenticationPolicy == .alwaysAllowed)
    }

    @available(iOS 17.2, *)
    @Test func anActivityThatNoLongerExistsCannotDispatchAnEvent() async {
        let webhooks = RecordingWebhooks()
        Current.webhooks = webhooks
        let intent = HALiveActivityActionIntent(activityID: UUID().uuidString, actionID: "PAUSE")
        let unauthenticatedIntent = HALiveActivityUnauthenticatedActionIntent(
            activityID: UUID().uuidString,
            actionID: "PAUSE"
        )

        await #expect(throws: ShortcutAppIntentError.self) { try await intent.perform() }
        await #expect(throws: ShortcutAppIntentError.self) { try await unauthenticatedIntent.perform() }
        #expect(webhooks.sent.isEmpty)
    }

    @available(iOS 17.2, *)
    private var state: HALiveActivityAttributes.ContentState {
        .init(message: "Track", actions: [.init(id: "PAUSE", title: "Pause")])
    }

    private final class RecordingWebhooks: WebhookManager {
        private let requests = OSAllocatedUnfairLock(
            uncheckedState: [(server: Server, request: WebhookRequest)]()
        )
        var sent: [(server: Server, request: WebhookRequest)] {
            requests.withLockUnchecked { $0 }
        }

        override func sendEphemeral(server: Server, request: WebhookRequest) -> Promise<Void> {
            requests.withLockUnchecked { $0.append((server, request)) }
            return .value(())
        }
    }
}
#endif
