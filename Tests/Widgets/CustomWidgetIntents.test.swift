@testable import HomeAssistant

import Foundation
import GRDB
import HAKit
@testable import Shared
import SharedTesting
import Testing
import UserNotifications

/// The intents a custom widget's tiles run: toggle, activate and perform an action, and the
/// confirmation state they set and reset on the stored widget.
///
/// `.isolatedEnvironment`: servers, the API cache, the database and the notification dispatcher are
/// installed per test, and the stub connection resolves every request before PromiseKit's `pipe`
/// returns, so its handlers still run on the test's task.
@Suite(.isolatedEnvironment)
struct CustomWidgetIntentsTests {
    // MARK: - Toggle

    @Test func toggleIgnoresIncompleteOrUnusableTaps() async throws {
        let (_, connection, notifications) = try install()

        _ = try await toggle(serverId: nil, domain: "light", entityId: "light.a").perform()
        _ = try await toggle(serverId: "custom-server", domain: "nope", entityId: "light.a").perform()
        _ = try await toggle(serverId: "gone", domain: "light", entityId: "light.a").perform()
        _ = try await toggle(serverId: "custom-server", domain: "sensor", entityId: "sensor.a").perform()

        #expect(connection.sent.isEmpty)
        #expect(notifications.ids.isEmpty)
    }

    @Test func toggleCallsTheDomainsServiceAndResetsConfirmations() async throws {
        let (_, connection, notifications) = try install(
            widgets: [CustomWidget(id: "w", name: "W", items: [], itemsStates: ["x": .pendingConfirmation])]
        ) { request in
            request.type.command == "states/light.a"
                ? .success(HAData(value: ["entity_id": "light.a", "state": "on", "attributes": [String: Any]()]))
                : .success(.empty)
        }

        _ = try await toggle(serverId: "custom-server", domain: "light", entityId: "light.a").perform()

        #expect(connection.sentCommands.contains("call_service"))
        #expect(notifications.ids.isEmpty)
        let afterToggle = try storedStates(of: "w")
        #expect(afterToggle.isEmpty)
    }

    @Test func aFailedToggleTellsTheUser() async throws {
        let (_, _, notifications) = try install { _ in .failure(widgetStubUnexpected) }
        _ = try await toggle(serverId: "custom-server", domain: "light", entityId: "light.a").perform()
        #expect(notifications.ids == [.intentToggleFailed])
    }

    @Test(arguments: [true, false])
    func optimisticTapsSetAnExplicitStateWithoutReadingOrReversingIt(target: Bool) async throws {
        let (_, connection, notifications) = try install { _ in .success(.empty) }
        let intent = toggle(serverId: "custom-server", domain: "light", entityId: "light.a")
        intent.targetValue = target

        _ = try await intent.perform()
        _ = try await intent.perform()

        #expect(connection.sentCommands == ["call_service", "call_service"])
        #expect(connection.sent.allSatisfy {
            $0.data["service"] as? String == (target ? "turn_on" : "turn_off")
                && $0.data["domain"] as? String == "light"
                && ($0.data["service_data"] as? [String: String])?["entity_id"] == "light.a"
        })
        #expect(notifications.ids.isEmpty)
    }

    @Test func optimisticFailuresAndUnsupportedTargetsAreReported() async throws {
        let (_, connection, notifications) = try install { _ in .failure(widgetStubUnexpected) }
        let light = toggle(serverId: "custom-server", domain: "light", entityId: "light.a")
        light.targetValue = true
        _ = try await light.perform()
        #expect(notifications.ids == [.intentToggleFailed])

        let lock = toggle(serverId: "custom-server", domain: "lock", entityId: "lock.a")
        lock.targetValue = true
        _ = try await lock.perform()
        #expect(connection.sentCommands == ["call_service"])
        #expect(notifications.ids == [.intentToggleFailed, .intentToggleFailed])
    }

    /// A server with no usable URL can't be reached, and the tap says so instead of doing nothing.
    @Test func anUnreachableServerTellsTheUser() async throws {
        let (_, connection, notifications) = try install(offline: true)
        _ = try await toggle(serverId: "custom-server", domain: "light", entityId: "light.a").perform()
        #expect(notifications.ids == [.serverUnreachable])
        #expect(connection.sent.isEmpty)
    }

    // MARK: - Activate

    @Test func activateIgnoresIncompleteOrUnsupportedTaps() async throws {
        let (_, connection, _) = try install()

        _ = try await activate(serverId: "custom-server", domain: nil, entityId: "scene.a").perform()
        _ = try await activate(serverId: "custom-server", domain: "nope", entityId: "scene.a").perform()
        _ = try await activate(serverId: "gone", domain: "scene", entityId: "scene.a").perform()
        _ = try await activate(serverId: "custom-server", domain: "light", entityId: "light.a").perform()

        #expect(connection.sent.isEmpty)
    }

    @Test func activateRunsTheMainActionAndReportsFailures() async throws {
        let (_, connection, notifications) = try install { _ in .success(.empty) }
        _ = try await activate(serverId: "custom-server", domain: "scene", entityId: "scene.a").perform()
        #expect(connection.sentCommands == ["call_service"])
        #expect(notifications.ids.isEmpty)

        let failing = WidgetStubConnection { _ in .failure(widgetStubUnexpected) }
        try Current.api(for: #require(Current.servers.all.first))?.connection = failing
        _ = try await activate(serverId: "custom-server", domain: "scene", entityId: "scene.a").perform()
        #expect(notifications.ids == [.intentActivateFailed])
    }

    // MARK: - Perform action

    @available(iOS 17, *)
    @Test func performActionIgnoresIncompleteTaps() async throws {
        let (_, connection, notifications) = try install()
        let missing = CustomWidgetPerformActionAppIntent()
        missing.serverId = "custom-server"
        missing.actionId = nil
        missing.payload = nil
        _ = try await missing.perform()

        let unusable = CustomWidgetPerformActionAppIntent()
        unusable.serverId = "custom-server"
        unusable.actionId = "a::b"
        unusable.payload = nil
        _ = try await unusable.perform()

        #expect(connection.sent.isEmpty)
        #expect(notifications.ids.isEmpty)
    }

    @available(iOS 17, *)
    @Test func performActionCallsTheServiceAndReportsFailures() async throws {
        let (_, connection, notifications) = try install { _ in .success(.empty) }
        let intent = CustomWidgetPerformActionAppIntent()
        intent.serverId = "custom-server"
        intent.actionId = "light.turn_on"
        intent.payload = #"{"entity_id": "light.a"}"#
        _ = try await intent.perform()
        #expect(connection.sentCommands == ["call_service"])
        #expect(notifications.ids.isEmpty)

        let invalid = CustomWidgetPerformActionAppIntent()
        invalid.serverId = "custom-server"
        invalid.actionId = "not-an-action"
        invalid.payload = nil
        _ = try await invalid.perform()
        #expect(notifications.ids == [.intentPerformActionFailed])
    }

    // MARK: - Confirmation state

    @Test func aTapThatNeedsConfirmationMarksItsItem() async throws {
        let item = MagicItem(id: "light.a", serverId: "custom-server", type: .entity)
        _ = try install(widgets: [
            CustomWidget(id: "w", name: "W", items: [item]),
            CustomWidget(id: "other", name: "Other", items: [], itemsStates: ["y": .pendingConfirmation]),
        ])

        let incomplete = UpdateWidgetItemConfirmationStateAppIntent()
        incomplete.widgetId = nil
        incomplete.serverUniqueId = item.serverUniqueId
        incomplete.confirmsTapAction = nil
        _ = try await incomplete.perform()
        let untouched = try storedStates(of: "other")
        #expect(untouched == ["y": .pendingConfirmation])

        let intent = UpdateWidgetItemConfirmationStateAppIntent()
        intent.widgetId = "w"
        intent.serverUniqueId = item.serverUniqueId
        intent.confirmsTapAction = nil
        _ = try await intent.perform()
        let pending = try storedStates(of: "w")
        #expect(pending == [item.serverUniqueId: .pendingConfirmation])
        let othersReset = try storedStates(of: "other")
        #expect(othersReset.isEmpty)

        intent.confirmsTapAction = true
        _ = try await intent.perform()
        let tapPending = try storedStates(of: "w")
        #expect(tapPending == [item.serverUniqueId: .pendingTapConfirmation])
    }

    @Test func resettingWithoutWidgetsOrDatabaseDoesNothing() async throws {
        _ = try install()
        _ = try await ResetAllCustomWidgetConfirmationAppIntent().perform()

        let database = try DatabaseQueue()
        Current.database = { database }
        _ = try await ResetAllCustomWidgetConfirmationAppIntent().perform()
        #expect(CustomWidgetIntentHelper.resolveConnection(serverId: "gone", intentName: "Test") == nil)
    }

    // MARK: - Helpers

    private func toggle(serverId: String?, domain: String?, entityId: String?) -> CustomWidgetToggleAppIntent {
        let intent = CustomWidgetToggleAppIntent()
        intent.serverId = serverId
        intent.domain = domain
        intent.entityId = entityId
        intent.widgetShowingStates = false
        return intent
    }

    private func activate(serverId: String?, domain: String?, entityId: String?) -> CustomWidgetActivateAppIntent {
        let intent = CustomWidgetActivateAppIntent()
        intent.serverId = serverId
        intent.domain = domain
        intent.entityId = entityId
        return intent
    }

    private func storedStates(of widgetId: String) throws -> [String: CustomWidget.ItemState] {
        try Current.database().read { db in
            try CustomWidget.filter(Column("id") == widgetId).fetchOne(db)?.itemsStates ?? [:]
        }
    }

    private func install(
        widgets: [CustomWidget] = [],
        offline: Bool = false,
        _ respond: @escaping WidgetStubConnection.Responder = { _ in .failure(widgetStubUnexpected) }
    ) throws -> (Server, WidgetStubConnection, RecordingDispatcher) {
        let database = try SettingsTestDatabase.make()
        try database.write { db in
            for widget in widgets {
                try widget.insert(db)
            }
        }
        Current.database = { database }
        let notifications = RecordingDispatcher()
        Current.notificationDispatcher = notifications
        let servers = FakeServerManager()
        var info = ServerInfo.fake()
        if offline {
            info.connection.set(address: nil, for: .external)
        }
        let server = servers.add(identifier: .init(rawValue: "custom-server"), serverInfo: info)
        Current.servers = servers
        let connection = WidgetStubConnection(respond: respond)
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        return (server, connection, notifications)
    }

    private final class RecordingDispatcher: LocalNotificationDispatcherProtocol, @unchecked Sendable {
        private let lock = NSLock()
        private var sent: [NotificationIdentifier] = []

        var ids: [NotificationIdentifier] {
            lock.lock()
            defer { lock.unlock() }
            return sent
        }

        func send(_ notification: LocalNotificationDispatcher.Notification) {
            lock.lock()
            sent.append(notification.id)
            lock.unlock()
        }

        func reschedule(_ content: UNNotificationContent, after delay: TimeInterval) {}
    }
}
