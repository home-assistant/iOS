#if canImport(ActivityKit)
import Foundation
import PromiseKit
@testable import Shared
import XCTest

/// Tests for the two live-activity routing paths in `NotificationCommandManager`:
///   1. `homeassistant.command == "live_activity"` — explicit command key
///   2. `homeassistant.live_update == true` — data flag (Android-compat pattern)
///   3. `homeassistant.command == "end_live_activity"` — end command
///   4. `homeassistant.command == "clear_notification"` with a `tag` — dismisses live activity
@available(iOS 17.2, *)
final class NotificationsCommandManagerLiveActivityTests: XCTestCase {
    private var sut: NotificationCommandManager!
    private var mockRegistry: MockLiveActivityRegistry!

    override func setUp() {
        super.setUp()
        mockRegistry = MockLiveActivityRegistry()
        Current.liveActivityRegistry = mockRegistry
        Current.isAppExtension = false
        sut = NotificationCommandManager()
    }

    override func tearDown() {
        sut = nil
        mockRegistry = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Wraps a `homeassistant` sub-dictionary in the outer notification payload structure.
    private func makePayload(_ hadict: [String: Any]) -> [AnyHashable: Any] {
        ["homeassistant": hadict]
    }

    // MARK: - live_activity command routing

    func testHandle_liveActivityCommand_callsStartOrUpdate() {
        let payload = makePayload([
            "command": "live_activity",
            "tag": "cmd-tag",
            "title": "Command Title",
            "message": "Hello",
        ])
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.startOrUpdateCalls.count, 1)
        XCTAssertEqual(mockRegistry.startOrUpdateCalls[0].tag, "cmd-tag")
        XCTAssertEqual(mockRegistry.startOrUpdateCalls[0].title, "Command Title")
    }

    // MARK: - live_update: true data flag routing (Android-compat)

    func testHandle_liveActivityFlag_callsStartOrUpdate() {
        let payload = makePayload([
            "live_update": true,
            "tag": "flag-tag",
            "title": "Flag Title",
            "message": "World",
        ])
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.startOrUpdateCalls.count, 1)
        XCTAssertEqual(mockRegistry.startOrUpdateCalls[0].tag, "flag-tag")
        XCTAssertEqual(mockRegistry.startOrUpdateCalls[0].title, "Flag Title")
    }

    func testHandle_liveActivityFlagFalse_doesNotRouteToLiveActivity() {
        // live_update: false should fall through to standard command routing
        let payload = makePayload([
            "live_update": false,
            "tag": "no-tag",
            "title": "Should Not Route",
        ])
        // No "command" key → returns notCommand error; registry is never called
        XCTAssertThrowsError(try hang(sut.handle(payload)))
        XCTAssertTrue(mockRegistry.startOrUpdateCalls.isEmpty)
    }

    // MARK: - end_live_activity command

    func testHandle_endLiveActivityCommand_callsRegistryEnd() {
        let payload = makePayload([
            "command": "end_live_activity",
            "tag": "end-me",
        ])
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.endCalls.count, 1)
        XCTAssertEqual(mockRegistry.endCalls[0].tag, "end-me")
        XCTAssertTrue(mockRegistry.endCalls[0].policyIsImmediate)
    }

    func testHandle_endLiveActivityCommand_withDefaultPolicy_callsRegistryEndWithDefaultPolicy() {
        let payload = makePayload([
            "command": "end_live_activity",
            "tag": "end-me",
            "dismissal_policy": "default",
        ])
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertEqual(mockRegistry.endCalls.count, 1)
        XCTAssertTrue(mockRegistry.endCalls[0].policyIsDefault)
    }

    // MARK: - clear_notification also ends live activity

    // NOTE: testHandle_clearNotificationWithTag_callsRegistryEnd is intentionally omitted.
    // HandlerClearNotification calls UNUserNotificationCenter.current().removeDeliveredNotifications
    // synchronously before reaching the live activity dismissal path. That API requires a real
    // app bundle and throws NSInternalInconsistencyException in the XCTest host process.
    // The clear_notification → live activity dismissal path is covered by code review and
    // integration testing instead.

    func testHandle_clearNotificationWithoutTag_doesNotCallRegistryEnd() {
        // No "tag" key → registry.end() must not be called.
        // Intentionally omit "collapseId" too — including any key would trigger
        // UNUserNotificationCenter which requires a real app bundle and crashes in tests.
        let payload = makePayload(["command": "clear_notification"])
        XCTAssertNoThrow(try hang(sut.handle(payload)))
        XCTAssertTrue(mockRegistry.endCalls.isEmpty)
    }

    // MARK: - Missing homeassistant dict

    func testHandle_noHomeAssistantKey_throwsNotCommand() {
        let payload: [AnyHashable: Any] = ["other": "value"]
        XCTAssertThrowsError(try hang(sut.handle(payload))) { error in
            guard case NotificationCommandManager.CommandError.notCommand = error else {
                return XCTFail("Expected .notCommand, got \(error)")
            }
        }
    }

    // MARK: - Unknown command

    func testHandle_unknownCommand_throwsUnknownCommand() {
        let payload = makePayload(["command": "unknown_command_xyz"])
        XCTAssertThrowsError(try hang(sut.handle(payload))) { error in
            guard case NotificationCommandManager.CommandError.unknownCommand = error else {
                return XCTFail("Expected .unknownCommand, got \(error)")
            }
        }
    }
}
#endif
