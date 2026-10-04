import Foundation
import PromiseKit
@testable import Shared
import XCTest

final class NotificationCommandManagerRoutingTests: XCTestCase {
    private final class RecordingHandler: NotificationCommandHandler {
        var payloads: [[String: Any]] = []
        var result: Promise<Void> = .value(())

        func handle(_ payload: [String: Any]) -> Promise<Void> {
            payloads.append(payload)
            return result
        }
    }

    private enum TestError: Error {
        case expected
    }

    private static let pushLocationKey = "locationUpdateOnNotification"

    private var sut: NotificationCommandManager!
    private var previousClientEventStore: ClientEventStoreProtocol!
    private var previousPushLocationSetting: Any?

    override func setUp() {
        super.setUp()
        sut = NotificationCommandManager()
        previousClientEventStore = Current.clientEventStore
        previousPushLocationSetting = Current.settingsStore.prefs.object(forKey: Self.pushLocationKey)
    }

    override func tearDown() {
        Current.clientEventStore = previousClientEventStore
        if let previousPushLocationSetting {
            Current.settingsStore.prefs.set(previousPushLocationSetting, forKey: Self.pushLocationKey)
        } else {
            Current.settingsStore.prefs.removeObject(forKey: Self.pushLocationKey)
        }
        sut = nil
        super.tearDown()
    }

    func testDidUpdateComplicationsNotificationName() {
        XCTAssertEqual(
            NotificationCommandManager.didUpdateComplicationsNotification.rawValue,
            "didUpdateComplicationsNotification"
        )
    }

    func testRegisteredHandlerReceivesHomeAssistantPayload() throws {
        let handler = RecordingHandler()
        sut.register(command: "custom_command", handler: handler)

        try hang(sut.handle(["homeassistant": ["command": "custom_command", "extra": 1] as [String: Any]]))

        XCTAssertEqual(handler.payloads.count, 1)
        XCTAssertEqual(handler.payloads.first?["command"] as? String, "custom_command")
        XCTAssertEqual(handler.payloads.first?["extra"] as? Int, 1)
        XCTAssertNil(handler.payloads.first?["webhook_id"])
        XCTAssertNil(handler.payloads.first?[LocalPushManager.confirmIDUserInfoKey])
    }

    func testWebhookIDAndConfirmIDAreForwardedToHandler() throws {
        let handler = RecordingHandler()
        sut.register(command: "custom_command", handler: handler)

        try hang(sut.handle([
            "homeassistant": ["command": "custom_command"],
            "webhook_id": "webhook-123",
            LocalPushManager.confirmIDUserInfoKey: "confirm-456",
        ]))

        XCTAssertEqual(handler.payloads.first?["webhook_id"] as? String, "webhook-123")
        XCTAssertEqual(handler.payloads.first?[LocalPushManager.confirmIDUserInfoKey] as? String, "confirm-456")
    }

    func testHandlerFailureIsPropagated() {
        let handler = RecordingHandler()
        handler.result = .init(error: TestError.expected)
        sut.register(command: "failing", handler: handler)

        XCTAssertThrowsError(try hang(sut.handle(["homeassistant": ["command": "failing"]]))) { error in
            XCTAssertTrue(error is TestError)
        }
    }

    func testRegisteringSameCommandReplacesHandler() throws {
        let first = RecordingHandler()
        let second = RecordingHandler()
        sut.register(command: "custom_command", handler: first)
        sut.register(command: "custom_command", handler: second)

        try hang(sut.handle(["homeassistant": ["command": "custom_command"]]))

        XCTAssertTrue(first.payloads.isEmpty)
        XCTAssertEqual(second.payloads.count, 1)
    }

    func testMissingCommandIsNotACommand() {
        XCTAssertThrowsError(try hang(sut.handle(["homeassistant": ["other": "value"]]))) { error in
            guard case NotificationCommandManager.CommandError.notCommand = error else {
                return XCTFail("Expected .notCommand, got \(error)")
            }
        }
    }

    func testNonDictionaryHomeAssistantValueIsNotACommand() {
        XCTAssertThrowsError(try hang(sut.handle(["homeassistant": "update_widgets"]))) { error in
            guard case NotificationCommandManager.CommandError.notCommand = error else {
                return XCTFail("Expected .notCommand, got \(error)")
            }
        }
    }

    func testLocationUpdateIsRejectedWhenPushLocationSourceIsDisabled() {
        Current.settingsStore.prefs.set(false, forKey: Self.pushLocationKey)
        XCTAssertFalse(Current.settingsStore.locationSources.pushNotifications)

        XCTAssertThrowsError(try hang(sut.handle(["homeassistant": ["command": "request_location_update"]])))
    }

    #if os(iOS)
    func testUpdateWidgetsRecordsClientEvent() throws {
        var events: [ClientEvent] = []
        Current.clientEventStore = MockClientEventStore { events.append($0) }

        try hang(sut.handle(["homeassistant": ["command": "update_widgets"]]))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.type, .notification)
        XCTAssertEqual(events.first?.text, "Notification command triggered widget update")
    }
    #endif
}
