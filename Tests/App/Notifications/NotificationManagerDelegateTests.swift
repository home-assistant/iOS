import Foundation
import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import Testing
import UIKit
import UserNotifications

/// The notification center delegate callbacks and the kiosk push commands of `NotificationManager`:
/// which presentation a foreground notification gets, what a tap, dismissal or snooze does, and how
/// each kiosk command reads its payload.
///
/// iOS has no public initializer for `UNNotification` or `UNNotificationResponse`, so these tests
/// build them through the long-standing class factories UserNotifications itself uses
/// (`notificationWithRequest:date:`, `responseWithNotification:actionIdentifier:`), checking first
/// that the class answers to them.
///
/// `.sharedState`: the tests swap `Current.database`, `Current.kiosk`, `Current.servers` and the
/// notification dispatcher, which the manager reads from promise callbacks on the main queue.
@Suite(.sharedState)
@MainActor
struct NotificationManagerDelegateTests {
    private final class FakeCommandHandler: NotificationCommandHandler {
        var payloads: [[String: Any]] = []
        var error: Error?

        func handle(_ payload: [String: Any]) -> Promise<Void> {
            payloads.append(payload)
            if let error {
                return .init(error: error)
            }
            return .value(())
        }
    }

    private struct World {
        let manager: NotificationManager
        let dispatcher: MockLocalNotificationDispatcher
        let handler: FakeCommandHandler
        let database: DatabaseQueue
    }

    private enum TestError: Error {
        case failed
    }

    private func withWorld(
        kiosk: KioskSettings = KioskSettings(showRemoteCommandConfirmations: false),
        servers: FakeServerManager = FakeServerManager(),
        _ body: (World) async throws -> Void
    ) async throws {
        let previousDatabase = Current.database
        let previousKiosk = Current.kiosk
        let previousSensors = Current.sensors
        let previousServers = Current.servers
        let previousDispatcher = Current.notificationDispatcher
        defer {
            Current.database = previousDatabase
            Current.kiosk = previousKiosk
            Current.sensors = previousSensors
            Current.servers = previousServers
            Current.notificationDispatcher = previousDispatcher
        }

        Current.sensors = SensorContainer()
        let database = try SettingsTestDatabase.make()
        try await database.write { db in
            try kiosk.insert(db, onConflict: .replace)
        }
        Current.database = { database }
        Current.kiosk = KioskModeManager()
        Current.servers = servers
        let dispatcher = MockLocalNotificationDispatcher()
        Current.notificationDispatcher = dispatcher

        let manager = NotificationManager()
        let handler = FakeCommandHandler()
        manager.commandManager.register(command: "test_command", handler: handler)
        try await body(World(manager: manager, dispatcher: dispatcher, handler: handler, database: database))
    }

    // MARK: - Building notifications

    private func content(
        body: String = "Something happened",
        userInfo: [AnyHashable: Any] = [:],
        sound: Bool = false
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Title"
        content.body = body
        content.userInfo = userInfo
        if sound {
            content.sound = .default
        }
        return content
    }

    private func notification(_ content: UNNotificationContent) throws -> UNNotification {
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        let factory: AnyObject = UNNotification.self
        let selector = NSSelectorFromString("notificationWithRequest:date:")
        try #require(factory.responds(to: selector))
        let made = factory.perform(selector, with: request, with: Date())?.takeUnretainedValue()
        return try #require(made as? UNNotification)
    }

    private func response(_ content: UNNotificationContent, action: String) throws -> UNNotificationResponse {
        let notification = try notification(content)
        let factory: AnyObject = UNNotificationResponse.self
        let selector = NSSelectorFromString("responseWithNotification:actionIdentifier:")
        try #require(factory.responds(to: selector))
        let made = factory.perform(selector, with: notification, with: action)?.takeUnretainedValue()
        return try #require(made as? UNNotificationResponse)
    }

    private final class Box<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: Value?
        var value: Value? { lock.withLock { stored } }
        func set(_ value: Value) { lock.withLock { stored = value } }
    }

    /// Polls (at most ten seconds) for a completion handler that may run on a later main-queue turn.
    private func wait<Value>(for box: Box<Value>) async -> Value? {
        let deadline = Date().addingTimeInterval(10)
        while box.value == nil, Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return box.value
    }

    private func presentation(
        _ world: World,
        for content: UNNotificationContent
    ) async throws -> UNNotificationPresentationOptions? {
        let box = Box<UNNotificationPresentationOptions>()
        try world.manager.userNotificationCenter(
            .current(),
            willPresent: notification(content),
            withCompletionHandler: { box.set($0) }
        )
        return await wait(for: box)
    }

    private func respond(_ world: World, to content: UNNotificationContent, action: String) async throws -> Bool {
        let box = Box<Bool>()
        try world.manager.userNotificationCenter(
            .current(),
            didReceive: response(content, action: action),
            withCompletionHandler: { box.set(true) }
        )
        return await wait(for: box) == true
    }

    // MARK: - Foreground presentation

    @Test func commandsRunWithoutABanner() async throws {
        try await withWorld { world in
            let silent = try await presentation(
                world,
                for: content(userInfo: ["homeassistant": ["command": "test_command"]])
            )
            #expect(silent == [])
            let withSound = try await presentation(
                world,
                for: content(userInfo: ["homeassistant": ["command": "test_command"]], sound: true)
            )
            #expect(withSound == [.sound])
            #expect(world.handler.payloads.count == 2)

            world.handler.error = TestError.failed
            let failed = try await presentation(
                world,
                for: content(userInfo: ["homeassistant": ["command": "test_command"]])
            )
            #expect(failed == [])
        }
    }

    @Test func unknownCommandsFallBackToABanner() async throws {
        try await withWorld { world in
            let options = try await presentation(
                world,
                for: content(userInfo: ["homeassistant": ["command": "not_a_command"]])
            )
            #expect(options == [.badge, .sound, .list, .banner])
        }
    }

    @Test func loggerNotificationsAreNotShownInTheForeground() async throws {
        try await withWorld { world in
            let options = try await presentation(
                world,
                for: content(userInfo: ["is_xcglogger_notify_category": true])
            )
            if UIApplication.shared.applicationState != .background {
                #expect(options == [])
            }
        }
    }

    @Test func kioskCommandsAreNotShown() async throws {
        try await withWorld { world in
            let options = try await presentation(
                world,
                for: content(body: "kiosk_set_screensaver_mode", userInfo: ["mode": "dim"])
            )
            #expect(options == [])
            let stored = try storedKiosk(world)
            #expect(stored?.screensaver.mode == .dim)
        }
    }

    @Test func presentationOptionsComeFromThePayload() async throws {
        try await withWorld { world in
            let all = try await presentation(
                world,
                for: content(userInfo: ["presentation_options": ["sound", "badge", "list", "banner"]])
            )
            #expect(all == [.sound, .badge, .list, .banner])

            let bannerOnly = try await presentation(world, for: content(userInfo: ["presentation_options": ["banner"]]))
            #expect(bannerOnly == [.banner])

            let soundFromContent = try await presentation(
                world,
                for: content(userInfo: ["presentation_options": [String]()], sound: true)
            )
            #expect(soundFromContent == [.sound])

            let defaults = try await presentation(world, for: content())
            #expect(defaults == [.badge, .sound, .list, .banner])
        }
    }

    // MARK: - Responses

    @Test func dismissingIsIgnored() async throws {
        try await withWorld { world in
            let completed = try await respond(
                world,
                to: content(userInfo: ["homeassistant": ["command": "test_command"]]),
                action: UNNotificationDismissActionIdentifier
            )
            #expect(completed)
            #expect(world.handler.payloads.isEmpty)
        }
    }

    @Test func snoozingReschedulesLocally() async throws {
        try await withWorld { world in
            let completed = try await respond(world, to: content(), action: "HA_SNOOZE_15")
            #expect(completed)
            let delay = try #require(world.dispatcher.lastRescheduledDelay)
            #expect(Int(delay) == 900)
            #expect(world.dispatcher.lastRescheduledContent?.body == "Something happened")
        }
    }

    @Test func aTapRunsTheCommandEvenWithoutAServer() async throws {
        try await withWorld { world in
            let completed = try await respond(
                world,
                to: content(userInfo: ["homeassistant": ["command": "test_command"]]),
                action: UNNotificationDefaultActionIdentifier
            )
            #expect(completed)
            #expect(world.handler.payloads.count == 1)
        }
    }

    @Test func aTapWithNothingToOpenCompletes() async throws {
        let servers = FakeServerManager()
        _ = servers.addFake()
        try await withWorld(servers: servers) { world in
            let completed = try await respond(world, to: content(), action: UNNotificationDefaultActionIdentifier)
            #expect(completed)
        }
    }

    /// An action button is forwarded to the server; without a reachable URL there is no API, and the
    /// handler still completes.
    @Test func anActionWithoutAnAPICompletes() async throws {
        let servers = FakeServerManager()
        var info = ServerInfo.fake()
        info.connection.set(address: nil, for: .external)
        _ = servers.add(identifier: .init(rawValue: "offline"), serverInfo: info)
        try await withWorld(servers: servers) { world in
            let completed = try await respond(
                world,
                to: content(userInfo: ["homeassistant": ["action_data": "value"]]),
                action: "CUSTOM_ACTION"
            )
            #expect(completed)
        }
    }

    // MARK: - Kiosk commands

    private func runKioskCommand(_ world: World, _ body: String, userInfo: [AnyHashable: Any] = [:]) -> Bool {
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content(body: body, userInfo: userInfo),
            trigger: nil
        )
        return world.manager.kioskPushPresentationOptions(for: request) == []
    }

    /// What the kiosk commands wrote; `Current.kiosk.settings` only catches up through an observation.
    private func storedKiosk(_ world: World) throws -> KioskSettings? {
        try world.database.read { try KioskSettings.fetchOne($0) }
    }

    @Test func screensaverCommandsUpdateTheKioskSettings() async throws {
        try await withWorld { world in
            #expect(runKioskCommand(
                world,
                "kiosk_set_screensaver_mode",
                userInfo: ["homeassistant": ["mode": "Blank "]]
            ))
            let blank = try storedKiosk(world)
            #expect(blank?.screensaver.mode == .blank)
            #expect(runKioskCommand(world, "kiosk_set_screensaver_mode", userInfo: ["mode": "disco"]))
            let unchanged = try storedKiosk(world)
            #expect(unchanged?.screensaver.mode == .blank)

            #expect(runKioskCommand(world, "kiosk_set_screensaver_brightness", userInfo: ["level": 40]))
            let dimmed = try storedKiosk(world)
            let dimLevel = try #require(dimmed?.screensaver.dimLevel)
            #expect(abs(dimLevel - 0.4) < 0.001)
            #expect(runKioskCommand(world, "kiosk_set_screensaver_brightness"))
            let stillDimmed = try storedKiosk(world)
            #expect(stillDimmed?.screensaver.dimLevel == dimLevel)
        }
    }

    @Test func commandsWithoutTheirPayloadAreIgnored() async throws {
        try await withWorld { world in
            let previousBrightness = Current.setScreenBrightness
            defer { Current.setScreenBrightness = previousBrightness }
            var brightness: CGFloat?
            Current.setScreenBrightness = { brightness = $0 }

            #expect(runKioskCommand(world, "kiosk_set_brightness"))
            #expect(runKioskCommand(world, "kiosk_set_volume"))
            // Camera commands need a camera entity.
            #expect(runKioskCommand(world, "kiosk_show_camera"))
            #expect(runKioskCommand(world, "kiosk_show_camera", userInfo: ["entity_id": "light.kitchen"]))
            #expect(runKioskCommand(world, "kiosk_show_camera", userInfo: ["homeassistant": ["entity_id": "switch.x"]]))
            #expect(runKioskCommand(world, "kiosk_hide_camera"))
            #expect(runKioskCommand(world, "kiosk_hide_screensaver"))
            #expect(brightness == nil)
        }
    }

    // MARK: - Remote notification registration

    @Test func registrationCallbacksDoNotRequireFirebase() async throws {
        try await withWorld { world in
            world.manager.didFailToRegisterForRemoteNotifications(error: TestError.failed)
            world.manager.didRegisterForRemoteNotifications(deviceToken: Data([0x01, 0xAB, 0xFF]))

            let handled = Box<UIBackgroundFetchResult>()
            world.manager.didReceiveRemoteNotification(
                userInfo: ["homeassistant": ["command": "test_command"]],
                fetchCompletionHandler: { handled.set($0) }
            )
            await #expect(wait(for: handled) == .newData)
            #expect(world.handler.payloads.count == 1)

            let notACommand = Box<UIBackgroundFetchResult>()
            world.manager.didReceiveRemoteNotification(
                userInfo: ["aps": ["alert": "Hi"]],
                fetchCompletionHandler: { notACommand.set($0) }
            )
            await #expect(wait(for: notACommand) == .failed)
        }
    }
}
