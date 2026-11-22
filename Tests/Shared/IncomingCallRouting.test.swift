@testable import Shared
import XCTest

final class IncomingCallRoutingTests: XCTestCase {
    private var defaults: UserDefaults!
    private var callGuard: IncomingCallGuard!
    private let server = Server.fake()

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "IncomingCallRoutingTests")
        defaults.removePersistentDomain(forName: "IncomingCallRoutingTests")
        callGuard = IncomingCallGuard(defaults: defaults, now: Date.init)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "IncomingCallRoutingTests")
        super.tearDown()
    }

    private func userInfo(_ fields: [String: Any] = [:]) -> [AnyHashable: Any] {
        [
            "webhook_id": "FakeWebhookID",
            "homeassistant": ["command": "incoming_call", "tag": "visio"].merging(fields, uniquingKeysWith: { $1 }),
        ]
    }

    private func route(
        _ userInfo: [AnyHashable: Any],
        server: Server? = nil,
        isEnabled: Bool = true
    ) -> IncomingCallRouting.Route {
        IncomingCallRouting.route(
            userInfo: userInfo,
            server: server ?? self.server,
            isEnabled: isEnabled,
            callGuard: callGuard
        )
    }

    func testRingsWhenEnabled() throws {
        guard case let .callKit(request) = route(userInfo(["caller": "Papa"])) else {
            return XCTFail("expected CallKit")
        }
        XCTAssertEqual(request.tag, "visio")
        XCTAssertEqual(request.caller, "Papa")
        XCTAssertEqual(request.webhookID, "FakeWebhookID")
    }

    func testNotificationWhenDisabled() {
        XCTAssertEqual(route(userInfo(), isEnabled: false), .notification)
        // And the call was not recorded, so switching the feature on lets it ring.
        XCTAssertNotEqual(route(userInfo()), .notification)
    }

    func testNotificationWithoutServer() {
        XCTAssertEqual(
            IncomingCallRouting.route(userInfo: userInfo(), server: nil, isEnabled: true, callGuard: callGuard),
            .notification
        )
    }

    func testNotificationWhenInvalid() {
        XCTAssertEqual(route(userInfo(["tag": "bad tag"])), .notification)
    }

    func testNotificationForOtherNotifications() {
        XCTAssertEqual(route(["homeassistant": ["command": "clear_notification"]]), .notification)
        XCTAssertEqual(route([:]), .notification)
    }

    func testDuplicateRingsOnce() {
        XCTAssertNotEqual(route(userInfo()), .notification)
        XCTAssertEqual(route(userInfo()), .notification)
    }

    func testURLIsCheckedAgainstTheServer() {
        guard case let .callKit(request) = route(userInfo(["url": "https://evil.example/"])) else {
            return XCTFail("expected CallKit")
        }
        XCTAssertNil(request.url)
    }

    func testNotificationOnlyStripsTheCommand() {
        let stripped = IncomingCallRouting.notificationOnly(userInfo(["caller": "Papa"]))
        let hadict = stripped["homeassistant"] as? [String: Any]
        XCTAssertNil(hadict?["command"])
        XCTAssertEqual(hadict?["tag"] as? String, "visio")
        XCTAssertEqual(hadict?["caller"] as? String, "Papa")
        XCTAssertFalse(IncomingCallRequest.isIncomingCall(userInfo: stripped))

        let other: [AnyHashable: Any] = ["homeassistant": ["command": "clear_notification"]]
        XCTAssertEqual(
            (IncomingCallRouting.notificationOnly(other)["homeassistant"] as? [String: Any])?["command"] as? String,
            "clear_notification"
        )
    }

    func testServerURLs() {
        XCTAssertEqual(
            IncomingCallRouting.serverURLs(for: server),
            [URL(string: "http://homeassistant.local:8123")!]
        )
    }

    func testFeatureIsOffUntilSwitchedOnAndOnlyOnTestFlight() {
        let previousTestFlight = Current.isTestFlight
        let previousEnabled = Current.settingsStore.incomingCallsEnabled
        defer {
            Current.isTestFlight = previousTestFlight
            Current.settingsStore.incomingCallsEnabled = previousEnabled
        }

        Current.isTestFlight = true
        Current.settingsStore.incomingCallsEnabled = false
        XCTAssertFalse(IncomingCallFeature.isEnabled)

        Current.settingsStore.incomingCallsEnabled = true
        XCTAssertEqual(IncomingCallFeature.isEnabled, IncomingCallFeature.isSupportedOnThisDevice)

        Current.isTestFlight = false
        XCTAssertFalse(IncomingCallFeature.isOffered)
        XCTAssertFalse(IncomingCallFeature.isEnabled)
    }

    func testExtensionTrustsTheStoredSwitch() {
        let previousTestFlight = Current.isTestFlight
        let previousEnabled = Current.settingsStore.incomingCallsEnabled
        defer {
            Current.isTestFlight = previousTestFlight
            Current.isAppExtension = false
            Current.settingsStore.incomingCallsEnabled = previousEnabled
        }
        // An extension has no receipt of its own, so `isTestFlight` is false there even on TestFlight builds.
        Current.isTestFlight = false
        Current.isAppExtension = true
        Current.settingsStore.incomingCallsEnabled = true
        XCTAssertEqual(IncomingCallFeature.isEnabled, IncomingCallFeature.isSupportedOnThisDevice)
    }

    func testAppTurnsTheSwitchOffWhereItIsNotOffered() {
        let previousTestFlight = Current.isTestFlight
        let previousEnabled = Current.settingsStore.incomingCallsEnabled
        defer {
            Current.isTestFlight = previousTestFlight
            Current.settingsStore.incomingCallsEnabled = previousEnabled
        }
        Current.isAppExtension = false
        Current.settingsStore.incomingCallsEnabled = true

        Current.isTestFlight = true
        IncomingCallFeature.enforceAvailability()
        XCTAssertEqual(Current.settingsStore.incomingCallsEnabled, IncomingCallFeature.isSupportedOnThisDevice)

        Current.settingsStore.incomingCallsEnabled = true
        Current.isTestFlight = false
        IncomingCallFeature.enforceAvailability()
        XCTAssertFalse(Current.settingsStore.incomingCallsEnabled)
    }

    func testUnsupportedRegion() {
        XCTAssertTrue(IncomingCallFeature.isInUnsupportedRegion(Locale(identifier: "zh_CN")))
        XCTAssertFalse(IncomingCallFeature.isInUnsupportedRegion(Locale(identifier: "zh_TW")))
        XCTAssertFalse(IncomingCallFeature.isInUnsupportedRegion(Locale(identifier: "fr_FR")))
    }
}
