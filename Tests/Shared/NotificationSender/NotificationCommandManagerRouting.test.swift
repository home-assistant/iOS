import Foundation
import PromiseKit
@testable import Shared
import SharedTesting
import Testing

/// How `NotificationCommandManager` routes a push's `homeassistant` payload to its command handlers.
/// The location command reads the shared settings, so the suite serializes with other shared-state tests.
@Suite(.sharedState)
struct NotificationCommandManagerRoutingTests {
    private final class RecordingHandler: NotificationCommandHandler {
        var payloads: [[String: Any]] = []
        func handle(_ payload: [String: Any]) -> Promise<Void> {
            payloads.append(payload)
            return .value(())
        }
    }

    private func settle(_ promise: Promise<Void>) async -> Error? {
        do {
            try await promise.asyncValue()
            return nil
        } catch {
            return error
        }
    }

    @Test func payloadsWithoutACommandAreRejected() async {
        let manager = NotificationCommandManager()
        let missing = await settle(manager.handle(["aps": [:]]))
        #expect((missing as? NotificationCommandManager.CommandError) == .notCommand)

        let noCommand = await settle(manager.handle(["homeassistant": ["tag": "x"]]))
        #expect((noCommand as? NotificationCommandManager.CommandError) == .notCommand)

        let unknown = await settle(manager.handle(["homeassistant": ["command": "make_coffee"]]))
        #expect((unknown as? NotificationCommandManager.CommandError) == .unknownCommand)
    }

    @Test func registeredHandlersReceiveTheWebhookAndConfirmIDs() async {
        let manager = NotificationCommandManager()
        let handler = RecordingHandler()
        manager.register(command: "custom", handler: handler)

        let error = await settle(manager.handle([
            "homeassistant": ["command": "custom", "value": 1],
            "webhook_id": "hook",
            LocalPushManager.confirmIDUserInfoKey: "confirm-1",
        ]))
        #expect(error == nil)
        let payload = handler.payloads.first
        #expect(payload?["webhook_id"] as? String == "hook")
        #expect(payload?[LocalPushManager.confirmIDUserInfoKey] as? String == "confirm-1")
        #expect(payload?["value"] as? Int == 1)
    }

    @Test func locationRequestsHonorTheNotificationLocationSource() async {
        let store = Current.settingsStore
        let previous = store.locationSources
        defer { store.locationSources = previous }
        var sources = previous
        sources.pushNotifications = false
        store.locationSources = sources

        let error = await settle(NotificationCommandManager().handle([
            "homeassistant": ["command": "request_location_update"],
        ]))
        #expect(error != nil)
    }

    @Test func widgetAndComplicationCommandsComplete() async {
        let manager = NotificationCommandManager()
        let widgets = await settle(manager.handle(["homeassistant": ["command": "update_widgets"]]))
        #expect(widgets == nil)

        // Without a paired watch the transfer fails; either way the command has to finish.
        _ = await settle(manager.handle(["homeassistant": ["command": "update_complications"]]))
        _ = await settle(manager.updateComplications())
        #expect(
            NotificationCommandManager.didUpdateComplicationsNotification.rawValue
                == "didUpdateComplicationsNotification"
        )
    }
}
