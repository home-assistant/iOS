import Foundation
import HAKit
import HAKit_Mocks
import PromiseKit
@testable import Shared
import UserNotifications
import XCTest

final class HomeAssistantAPIWebhookRequestsTests: XCTestCase {
    private var webhookManager: FakeWebhookManager!
    private var previousWebhookManager: WebhookManager!
    private var previousIsAppExtension: Bool!
    private var server: Server!
    private var api: HomeAssistantAPI!

    override func setUp() {
        super.setUp()
        previousWebhookManager = Current.webhooks
        previousIsAppExtension = Current.isAppExtension
        webhookManager = FakeWebhookManager()
        Current.webhooks = webhookManager
        Current.isAppExtension = false

        server = .fake(update: { info in
            info.setSetting(value: "Test Phone", for: .overrideDeviceName)
        })
        api = HomeAssistantAPI(server: server)
        api.connection = HAMockConnection()
    }

    override func tearDown() {
        Current.webhooks = previousWebhookManager
        Current.isAppExtension = previousIsAppExtension
        api = nil
        server = nil
        super.tearDown()
    }

    private func recordEphemeralRequests(answering response: Any = [String: Any]()) -> () -> [WebhookRequest] {
        var requests = [WebhookRequest]()
        webhookManager.sendEphemeralHandler = { _, request in
            requests.append(request)
            return response
        }
        return { requests }
    }

    private func recordSentRequests() -> () -> [(WebhookResponseIdentifier, WebhookRequest)] {
        var requests = [(WebhookResponseIdentifier, WebhookRequest)]()
        webhookManager.sendRequestHandler = { identifier, _, request, seal in
            requests.append((identifier, request))
            seal.fulfill(())
        }
        return { requests }
    }

    // MARK: - Ephemeral

    func testCreateEventFiresTheEvent() throws {
        let requests = recordEphemeralRequests()

        try hang(api.CreateEvent(eventType: "custom_event", eventData: ["answer": 42]))

        XCTAssertEqual(requests().count, 1)
        let request = try XCTUnwrap(requests().first)
        XCTAssertEqual(request.type, "fire_event")
        let data = try XCTUnwrap(request.data as? [String: Any])
        XCTAssertEqual(data["event_type"] as? String, "custom_event")
        XCTAssertEqual((data["event_data"] as? [String: Any])?["answer"] as? Int, 42)
    }

    func testStreamCameraMapsTheResponse() throws {
        let requests = recordEphemeralRequests(answering: [
            "hls_path": "/api/hls/abc/master_playlist.m3u8",
            "mjpeg_path": "/api/camera_proxy_stream/camera.door",
        ])

        let response = try hang(api.StreamCamera(entityId: "camera.door"))

        XCTAssertEqual(response.hlsPath, "/api/hls/abc/master_playlist.m3u8")
        XCTAssertEqual(response.mjpegPath, "/api/camera_proxy_stream/camera.door")
        let request = try XCTUnwrap(requests().first)
        XCTAssertEqual(request.type, "stream_camera")
        XCTAssertEqual((request.data as? [String: Any])?["camera_entity_id"] as? String, "camera.door")
    }

    func testStreamCameraRejectsAResponseWithoutPaths() {
        _ = recordEphemeralRequests(answering: ["error": "nope"])

        XCTAssertThrowsError(try hang(api.StreamCamera(entityId: "camera.door")))
    }

    func testUpdateRegistrationSendsDeviceDetailsAndRemembersTheName() throws {
        let requests = recordEphemeralRequests(answering: [
            "webhook_id": "new-webhook",
            "secret": "new-secret",
        ])
        XCTAssertNil(server.info.setting(for: .registeredDeviceName))

        let response = try hang(api.updateRegistration())

        XCTAssertEqual(response.WebhookID, "new-webhook")
        XCTAssertEqual(response.WebhookSecret, "new-secret")
        XCTAssertEqual(server.info.setting(for: .registeredDeviceName), "Test Phone")

        let request = try XCTUnwrap(requests().first)
        XCTAssertEqual(request.type, "update_registration")
        let data = try XCTUnwrap(request.data as? [String: Any])
        XCTAssertEqual(data["device_name"] as? String, "Test Phone")
        XCTAssertEqual(data["manufacturer"] as? String, "Apple")
        XCTAssertEqual(data["app_version"] as? String, HomeAssistantAPI.clientVersionDescription)
        XCTAssertNotNil(data["model"])
        XCTAssertNotNil(data["os_version"])
        // Only the initial registration carries these.
        XCTAssertNil(data["app_id"])
        XCTAssertNil(data["supports_encryption"])
    }

    func testUpdateRegistrationFailsForAnUnmappableResponse() {
        _ = recordEphemeralRequests(answering: "not a registration")

        XCTAssertThrowsError(try hang(api.updateRegistration())) { error in
            XCTAssertEqual(error as? WebhookError, .unmappableValue)
        }
        XCTAssertNil(server.info.setting(for: .registeredDeviceName))
    }

    func testHandlePushActionFiresLegacyAndMobileAppEvents() throws {
        let requests = recordEphemeralRequests()
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "ALARM"
        content.userInfo = ["homeassistant": ["id": "1"]]
        let info = HomeAssistantAPI.PushActionInfo(
            content: content,
            actionIdentifier: "SNOOZE",
            textInput: "later"
        )

        try hang(api.handlePushAction(for: info))

        let events = requests().compactMap { $0.data as? [String: Any] }
        XCTAssertEqual(
            Set(events.compactMap { $0["event_type"] as? String }),
            ["ios.notification_action_fired", "mobile_app_notification_action"]
        )
        let mobileApp = try XCTUnwrap(events.first { $0["event_type"] as? String == "mobile_app_notification_action" })
        let mobileAppData = try XCTUnwrap(mobileApp["event_data"] as? [String: Any])
        XCTAssertEqual(mobileAppData["action"] as? String, "SNOOZE")
        XCTAssertEqual(mobileAppData["reply_text"] as? String, "later")
    }

    // MARK: - Regular webhooks

    func testCallServiceSendsAServiceCall() throws {
        let requests = recordSentRequests()

        try hang(api.CallService(
            domain: "light",
            service: "turn_on",
            serviceData: ["entity_id": "light.kitchen"],
            triggerSource: .AppShortcut
        ))

        let (identifier, request) = try XCTUnwrap(requests().first)
        XCTAssertEqual(identifier, .serviceCall)
        XCTAssertEqual(request.type, "call_service")
        let data = try XCTUnwrap(request.data as? [String: Any])
        XCTAssertEqual(data["domain"] as? String, "light")
        XCTAssertEqual(data["service"] as? String, "turn_on")
        XCTAssertEqual((data["service_data"] as? [String: Any])?["entity_id"] as? String, "light.kitchen")
    }

    func testTurnOnScriptCallsScriptTurnOn() throws {
        let requests = recordSentRequests()

        try hang(api.turnOnScript(scriptEntityId: "script.morning", triggerSource: .AppShortcut))

        let (_, request) = try XCTUnwrap(requests().first)
        let data = try XCTUnwrap(request.data as? [String: Any])
        XCTAssertEqual(data["domain"] as? String, "script")
        XCTAssertEqual(data["service"] as? String, "turn_on")
        XCTAssertEqual((data["service_data"] as? [String: Any])?["entity_id"] as? String, "script.morning")
    }

    // MARK: - Connect

    func testConnectStopsWhenRegistrationUpdateFailsForAnotherReason() {
        // No ephemeral handler: the update fails with an error that isn't a `WebhookError`, which
        // must not trigger a re-registration.
        XCTAssertThrowsError(try hang(api.Connect(reason: .warm))) { error in
            XCTAssertEqual(error as? FakeWebhookManagerError, .noEphemeralHandler)
        }
    }
}
