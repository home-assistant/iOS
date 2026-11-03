@testable import HomeAssistant

import AppIntents
import Foundation
import GRDB
import HAKit
import PromiseKit
@testable import Shared
import SharedTesting
import Testing
import UserNotifications

/// The App Intents that run something on the server through the webhook — a script, a scene, an
/// automation, a custom event — and the server, pipeline and attribute pickers the intents share.
///
/// `.isolatedEnvironment`: the servers, webhook manager, database and notification dispatcher are
/// read on the test's task before any PromiseKit hop, so each test installs its own.
@Suite(.isolatedEnvironment)
struct WidgetActionAppIntentsTests {
    // MARK: - Script, scene and automation

    @Test func aScriptRunsThroughTheWebhookAndReportsTheOutcome() async throws {
        let (webhooks, notifications) = install()
        let intent = ScriptAppIntent()
        intent.script = Self.script(serverId: "action-server")
        intent.showConfirmationNotification = true
        intent.hapticConfirmation = false
        let success = try await intent.perform()
        #expect(webhooks.sentTypes == ["call_service"])
        #expect(notifications.ids == [.scriptAppIntentRun])
        _ = success

        webhooks.fails = true
        intent.showConfirmationNotification = false
        _ = try await intent.perform()
        #expect(notifications.ids == [.scriptAppIntentRun])

        intent.script = Self.script(serverId: "gone")
        _ = try await intent.perform()
        #expect(webhooks.sentTypes.count == 2)
    }

    /// Running every script a scripts widget holds runs each one in turn; a widget without any does
    /// nothing.
    @available(iOS 17, *)
    @Test func theScriptsWidgetRunsEachOfItsScripts() async throws {
        let (webhooks, _) = install()
        let empty = WidgetScriptsAppIntent()
        empty.scripts = nil
        empty.showConfirmationDialog = false
        _ = try await empty.perform()
        #expect(webhooks.sentTypes.isEmpty)

        let intent = WidgetScriptsAppIntent()
        intent.scripts = [Self.script(serverId: "action-server"), Self.script(serverId: "action-server")]
        intent.showConfirmationDialog = false
        _ = try await intent.perform()
        #expect(webhooks.sentTypes == ["call_service", "call_service"])
        _ = WidgetScriptsAppIntent.parameterSummary
    }

    @Test func aSceneIsAppliedThroughTheWebhook() async throws {
        let (webhooks, notifications) = install()
        let intent = SceneAppIntent()
        intent.scene = IntentSceneEntity(
            id: "action-server-scene.movie",
            entityId: "scene.movie",
            serverId: "action-server",
            serverName: "Fake Server",
            displayString: "Movie",
            iconName: "movie"
        )
        intent.showConfirmationNotification = true
        intent.hapticConfirmation = false
        _ = try await intent.perform()
        webhooks.fails = true
        _ = try await intent.perform()
        #expect(webhooks.sentTypes == ["call_service", "call_service"])
        #expect(notifications.ids == [.sceneAppIntentRun, .sceneAppIntentRun])
    }

    @Test func anAutomationIsTriggeredThroughTheWebhook() async throws {
        let (webhooks, notifications) = install()
        let intent = AutomationAppIntent()
        intent.automation = IntentAutomationEntity(
            id: "action-server-automation.wake",
            entityId: "automation.wake",
            serverId: "action-server",
            serverName: "Fake Server",
            displayString: "Wake",
            iconName: "alarm"
        )
        intent.showConfirmationNotification = true
        intent.hapticConfirmation = false
        _ = try await intent.perform()
        webhooks.fails = true
        _ = try await intent.perform()
        #expect(webhooks.sentTypes == ["call_service", "call_service"])
        #expect(notifications.ids == [.automationAppIntentRun, .automationAppIntentRun])
    }

    // MARK: - Fire event

    @available(iOS 17, *)
    @Test func anEventIsFiredWithItsPayload() async throws {
        let (webhooks, _) = install()
        let intent = FireEventAppIntent()
        intent.server = .init(identifier: .init(rawValue: "action-server"))
        intent.eventName = "doorbell"

        for payload in ["", #"{"room": "hall"}"#, #"{"eventName": "renamed", "eventData": {"a": 1}}"#] {
            intent.eventData = payload
            _ = try await intent.perform()
        }
        #expect(webhooks.sentTypes == ["fire_event", "fire_event", "fire_event"])
        #expect(webhooks.eventTypes == ["doorbell", "doorbell", "renamed"])

        intent.eventData = "[1, 2]"
        await #expect(throws: ShortcutAppIntentError.self) { try await intent.perform() }

        webhooks.fails = true
        intent.eventData = "{}"
        await #expect(throws: (any Error).self) { try await intent.perform() }

        Current.servers = FakeServerManager()
        await #expect(throws: ShortcutAppIntentError.self) { try await intent.perform() }
        _ = FireEventAppIntent.parameterSummary
    }

    // MARK: - Shortcuts that need no server answer

    @Test func updatesWithoutServersSucceedTrivially() async throws {
        Current.servers = FakeServerManager()
        _ = try await UpdateSensorsAppIntent().perform()
        _ = try await UpdateLocationAppIntent().perform()
    }

    @Test func anAssistPromptNeedsARecentEnoughServer() async throws {
        Current.servers = FakeServerManager()
        let intent = AssistPromptAppIntent()
        intent.prompt = "Turn on the lights"
        intent.pipeline = nil
        await #expect(throws: ShortcutAppIntentError.self) { try await intent.perform() }

        intent.pipeline = AssistPipelineEntity(id: "p", serverId: "gone", name: "Pipeline")
        await #expect(throws: ShortcutAppIntentError.self) { try await intent.perform() }

        _ = install()
        intent.pipeline = nil
        await #expect(throws: ShortcutAppIntentError.self) { try await intent.perform() }
    }

    // MARK: - Pickers

    @Test func thePipelinePickerListsEachServersPipelines() async throws {
        _ = install()
        let database = try SettingsTestDatabase.make()
        try await database.write { db in
            try AssistPipelines(
                serverId: "action-server",
                preferredPipeline: "cloud",
                pipelines: [Pipeline(id: "cloud", name: "Cloud"), Pipeline(id: "local", name: "Local")]
            ).insert(db)
            try AssistPipelines(serverId: "gone", preferredPipeline: "x", pipelines: [Pipeline(id: "x", name: "X")])
                .insert(db)
        }
        Current.database = { database }
        let query = AssistPipelineEntityQuery()

        let suggested = try await query.suggestedEntities()
        #expect(suggested.sections.count == 2)
        #expect(suggested.sections.first?.items.map(\.value.id).contains("local") == true)

        let matching = try await query.entities(matching: "loc")
        #expect(matching.sections.first?.items.map(\.value.name) == ["Local"])

        let byId = try await query.entities(for: [
            "local",
            AssistPipelineEntity.preferredIdPrefix + "action-server",
            "",
            "missing",
        ])
        #expect(byId.map(\.serverId) == ["action-server", "action-server", "action-server"])
        #expect(byId[1].isPreferred)
        #expect(!String(describing: byId[0].displayRepresentation.title).isEmpty)

        let preferred = await query.defaultResult()
        #expect(preferred?.isPreferred == true)

        Current.servers = FakeServerManager()
        let none = await query.defaultResult()
        #expect(none == nil)

        Current.database = { (try? DatabaseQueue()) ?? database }
        await #expect(throws: (any Error).self) { try await query.suggestedEntities() }
    }

    @Test func theServerPickerResolvesAndSearchesServers() async throws {
        let servers = FakeServerManager()
        let home = servers.add(identifier: .init(rawValue: "home"), serverInfo: .fake())
        Current.servers = servers
        let query = IntentServerAppEntity.IntentServerAppEntityQuery()

        let byId = try await query.entities(for: ["home", "elsewhere"])
        #expect(byId.map(\.id) == ["home", "elsewhere"])
        let matching = try await query.entities(matching: String(home.info.remoteName.prefix(4)))
        #expect(matching.map(\.id) == ["home"])
        let suggested = try await query.suggestedEntities()
        #expect(suggested.map(\.id) == ["home"])
        let defaultResult = await query.defaultResult()
        #expect(defaultResult?.id == "home")
        #expect(!String(describing: IntentServerAppEntity(from: home).displayRepresentation.title).isEmpty)

        _ = servers.add(identifier: .init(rawValue: "second"), serverInfo: .fake())
        let ambiguous = try await query.entities(for: ["elsewhere"])
        #expect(ambiguous.isEmpty)
        #expect(IntentServerAppEntity(identifier: .init(rawValue: "elsewhere")).getInfo() == nil)

        Current.servers = FakeServerManager()
        let noDefault = await query.defaultResult()
        #expect(noDefault == nil)
    }

    @available(iOS 17, *)
    @Test func theDetailsAttributePickerEchoesItsIdentifiers() async throws {
        let query = WidgetDetailsAttributeAppEntityQuery()
        let suggested = try await query.suggestedEntities()
        #expect(suggested.sections.flatMap(\.items).isEmpty)
        let picked = try await query.entities(for: ["temperature"])
        #expect(picked.map(\.id) == ["temperature"])
        #expect(!String(describing: picked[0].displayRepresentation.title).isEmpty)
        _ = WidgetDetailsAppIntent.parameterSummary
    }

    // MARK: - Helpers

    private static func script(serverId: String) -> IntentScriptEntity {
        IntentScriptEntity(
            id: "\(serverId)-script.morning",
            entityId: "script.morning",
            serverId: serverId,
            serverName: "Fake Server",
            displayString: "Morning",
            iconName: "sun"
        )
    }

    private func install() -> (RecordingWebhooks, RecordingDispatcher) {
        let servers = FakeServerManager()
        _ = servers.add(identifier: .init(rawValue: "action-server"), serverInfo: .fake())
        Current.servers = servers
        let webhooks = RecordingWebhooks()
        Current.webhooks = webhooks
        let notifications = RecordingDispatcher()
        Current.notificationDispatcher = notifications
        return (webhooks, notifications)
    }

    private final class RecordingWebhooks: WebhookManager {
        private let lock = NSLock()
        private var types: [String] = []
        private var events: [String] = []
        private var shouldFail = false

        var fails: Bool {
            get { lock.lock(); defer { lock.unlock() }; return shouldFail }
            set { lock.lock(); shouldFail = newValue; lock.unlock() }
        }

        var sentTypes: [String] {
            lock.lock()
            defer { lock.unlock() }
            return types
        }

        var eventTypes: [String] {
            lock.lock()
            defer { lock.unlock() }
            return events
        }

        override func send(
            identifier: WebhookResponseIdentifier = .unhandled,
            server: Server,
            request: WebhookRequest
        ) -> Promise<Void> {
            record(request)
        }

        override func sendEphemeral(server: Server, request: WebhookRequest) -> Promise<Void> {
            record(request)
        }

        private func record(_ request: WebhookRequest) -> Promise<Void> {
            lock.lock()
            types.append(request.type)
            if let event = (request.data as? [String: Any])?["event_type"] as? String {
                events.append(event)
            }
            let fail = shouldFail
            lock.unlock()
            return fail ? .init(error: ShortcutAppIntentError("webhook failed")) : .value(())
        }
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
