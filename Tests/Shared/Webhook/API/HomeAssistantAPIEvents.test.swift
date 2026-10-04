import CoreLocation
import Foundation
import HAKit
@testable import Shared
import XCTest

final class HomeAssistantAPIEventsTests: XCTestCase {
    private var api: HomeAssistantAPI!

    override func setUp() {
        super.setUp()
        api = HomeAssistantAPI(server: .fake(update: { info in
            info.setSetting(value: "Test Phone", for: .overrideDeviceName)
        }))
    }

    override func tearDown() {
        api = nil
        super.tearDown()
    }

    // MARK: - User agent

    func testUserAgentDescribesTheApp() {
        let userAgent = HomeAssistantAPI.userAgent

        XCTAssertTrue(userAgent.hasPrefix("Home Assistant/\(AppConstants.version) ("))
        XCTAssertTrue(userAgent.contains("build:\(AppConstants.build)"))
        XCTAssertTrue(userAgent.contains(AppConstants.BundleID))
    }

    func testApplicationNameForUserAgentLooksLikeMobileSafari() {
        XCTAssertEqual(
            HomeAssistantAPI.applicationNameForUserAgent,
            HomeAssistantAPI.userAgent + " Mobile/HomeAssistant, like Safari"
        )
    }

    func testClientVersionDescription() {
        XCTAssertEqual(
            HomeAssistantAPI.clientVersionDescription,
            "\(AppConstants.version) (\(AppConstants.build))"
        )
    }

    // MARK: - Connect reasons and websocket state

    func testConnectReasonSensorTriggers() {
        XCTAssertEqual(HomeAssistantAPI.ConnectReason.cold.updateSensorTrigger, .Launch)
        XCTAssertEqual(HomeAssistantAPI.ConnectReason.warm.updateSensorTrigger, .Launch)
        XCTAssertEqual(HomeAssistantAPI.ConnectReason.background.updateSensorTrigger, .Launch)
        XCTAssertEqual(HomeAssistantAPI.ConnectReason.periodic.updateSensorTrigger, .Periodic)
    }

    func testAutomaticWebSocketConnectOnlyFromIdleDisconnect() {
        XCTAssertTrue(HomeAssistantAPI.shouldAttemptAutomaticWebSocketConnect(
            for: .disconnected(reason: .disconnected)
        ))
        XCTAssertFalse(HomeAssistantAPI.shouldAttemptAutomaticWebSocketConnect(
            for: .disconnected(reason: .rejected)
        ))
        XCTAssertFalse(HomeAssistantAPI.shouldAttemptAutomaticWebSocketConnect(for: .connecting))
        XCTAssertFalse(HomeAssistantAPI.shouldAttemptAutomaticWebSocketConnect(for: .authenticating))
        XCTAssertFalse(HomeAssistantAPI.shouldAttemptAutomaticWebSocketConnect(for: .ready(version: "2026.1.0")))
    }

    func testManualUpdateTypes() {
        XCTAssertTrue(HomeAssistantAPI.ManualUpdateType.userRequested.allowsTemporaryAccess)
        XCTAssertFalse(HomeAssistantAPI.ManualUpdateType.appOpened.allowsTemporaryAccess)
        XCTAssertFalse(HomeAssistantAPI.ManualUpdateType.programmatic.allowsTemporaryAccess)

        XCTAssertEqual(HomeAssistantAPI.ManualUpdateType.appOpened.locationUpdateTrigger, .Launch)
        XCTAssertEqual(HomeAssistantAPI.ManualUpdateType.userRequested.locationUpdateTrigger, .Manual)
        XCTAssertEqual(HomeAssistantAPI.ManualUpdateType.programmatic.locationUpdateTrigger, .Manual)
    }

    // MARK: - Download paths

    func testTemporaryDownloadFileURLWithoutSourceHasNoExtension() throws {
        let url = try XCTUnwrap(api.temporaryDownloadFileURL())

        XCTAssertTrue(url.isFileURL)
        XCTAssertEqual(url.pathExtension, "")
        XCTAssertTrue(url.path.hasPrefix(URL(fileURLWithPath: NSTemporaryDirectory()).path))
    }

    func testTemporaryDownloadFileURLKeepsTheSourceExtension() throws {
        let source = try XCTUnwrap(URL(string: "https://example.com/image.jpeg"))

        let first = try XCTUnwrap(api.temporaryDownloadFileURL(appropriateFor: source))
        let second = try XCTUnwrap(api.temporaryDownloadFileURL(appropriateFor: source))

        XCTAssertEqual(first.pathExtension, "jpeg")
        XCTAssertNotEqual(first, second)
    }

    // MARK: - Events

    func testSharedEventDeviceInfo() {
        let info = api.sharedEventDeviceInfo

        XCTAssertEqual(info["sourceDevicePermanentID"], AppConstants.PermanentID)
        XCTAssertEqual(info["sourceDeviceName"], "Test Phone")
        XCTAssertNotNil(info["sourceDeviceID"])
    }

    func testLegacyNotificationActionEventWithEverything() {
        let event = api.legacyNotificationActionEvent(
            identifier: "OPEN",
            category: "ALARM",
            actionData: ["key": "value"],
            textInput: "hello"
        )

        XCTAssertEqual(event.eventType, "ios.notification_action_fired")
        XCTAssertEqual(event.eventData["actionName"] as? String, "OPEN")
        XCTAssertEqual(event.eventData["categoryName"] as? String, "ALARM")
        XCTAssertEqual(event.eventData["action_data"] as? [String: String], ["key": "value"])
        XCTAssertEqual(event.eventData["response_info"] as? String, "hello")
        XCTAssertEqual(event.eventData["textInput"] as? String, "hello")
        XCTAssertEqual(event.eventData["sourceDeviceName"] as? String, "Test Phone")
    }

    func testLegacyNotificationActionEventWithOnlyIdentifier() {
        let event = api.legacyNotificationActionEvent(
            identifier: "OPEN",
            category: nil,
            actionData: nil,
            textInput: nil
        )

        XCTAssertEqual(event.eventData["actionName"] as? String, "OPEN")
        XCTAssertNil(event.eventData["categoryName"])
        XCTAssertNil(event.eventData["action_data"])
        XCTAssertNil(event.eventData["response_info"])
        XCTAssertNil(event.eventData["textInput"])
    }

    func testMobileAppNotificationActionEvent() {
        let full = api.mobileAppNotificationActionEvent(
            identifier: "REPLY",
            category: "CHAT",
            actionData: 42,
            textInput: "ok"
        )
        let bare = api.mobileAppNotificationActionEvent(
            identifier: "REPLY",
            category: nil,
            actionData: nil,
            textInput: nil
        )

        XCTAssertEqual(full.eventType, "mobile_app_notification_action")
        XCTAssertEqual(full.eventData["action"] as? String, "REPLY")
        XCTAssertEqual(full.eventData["action_data"] as? Int, 42)
        XCTAssertEqual(full.eventData["reply_text"] as? String, "ok")
        XCTAssertNil(full.eventData["categoryName"])

        XCTAssertEqual(bare.eventData.count, 1)
        XCTAssertEqual(bare.eventData["action"] as? String, "REPLY")
    }

    func testTagEventOnCurrentServerOmitsDeviceID() {
        let event = api.tagEvent(tagPath: "tag-1")

        XCTAssertEqual(event.eventType, "tag_scanned")
        XCTAssertEqual(event.eventData["tag_id"], "tag-1")
        XCTAssertNil(event.eventData["device_id"])
        XCTAssertEqual(event.eventData["sourceDeviceName"], "Test Phone")
    }

    func testTagEventOnOldServerIncludesDeviceID() {
        let oldAPI = HomeAssistantAPI(server: .fake(update: { info in
            info.version = "0.110.0"
        }))

        let event = oldAPI.tagEvent(tagPath: "tag-1")

        XCTAssertEqual(event.eventData["tag_id"], "tag-1")
        XCTAssertNotNil(event.eventData["device_id"])
    }

    func testZoneStateEventEntered() {
        let zone = AppZone(entityId: "zone.home", serverIdentifier: "server")
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: 1, longitude: 2),
            radius: 100,
            identifier: "zone.home"
        )

        let event = api.zoneStateEvent(region: region, state: .inside, zone: zone)

        XCTAssertEqual(event.eventType, "ios.zone_entered")
        XCTAssertEqual(event.eventData["zone"] as? String, "zone.home")
        XCTAssertNil(event.eventData["multi_region_zone_id"])
    }

    func testZoneStateEventExitedFromSubRegion() {
        let zone = AppZone(entityId: "zone.work", serverIdentifier: "server")
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: 1, longitude: 2),
            radius: 100,
            identifier: "server/zone.work@090"
        )

        let event = api.zoneStateEvent(region: region, state: .outside, zone: zone)

        XCTAssertEqual(event.eventType, "ios.zone_exited")
        XCTAssertEqual(event.eventData["zone"] as? String, "zone.work")
        XCTAssertEqual(event.eventData["multi_region_zone_id"] as? String, "090")
    }

    func testShareEvent() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/page"))

        let event = api.shareEvent(entered: "share-sheet", url: url, text: "look")

        XCTAssertEqual(event.eventType, "mobile_app.share")
        XCTAssertEqual(event.eventData["entered"], "share-sheet")
        XCTAssertEqual(event.eventData["url"], "https://example.com/page")
        XCTAssertEqual(event.eventData["text"], "look")
    }

    func testShareEventWithoutURLOrText() {
        let event = api.shareEvent(entered: "share-sheet", url: nil, text: nil)

        XCTAssertEqual(event.eventData["entered"], "share-sheet")
        XCTAssertNil(event.eventData["url"])
        XCTAssertNil(event.eventData["text"])
    }

    func testProfilePictureCacheKeyIsPerServer() {
        XCTAssertEqual(api.profilePictureCacheKey, "profile-picture-\(api.server.identifier.rawValue)")
    }

    // MARK: - Errors

    func testAPIErrorDescriptions() {
        typealias APIError = HomeAssistantAPI.APIError

        XCTAssertEqual(APIError.managerNotAvailable.errorDescription, L10n.HaApi.ApiError.managerNotAvailable)
        XCTAssertEqual(APIError.invalidResponse.errorDescription, L10n.HaApi.ApiError.invalidResponse)
        XCTAssertEqual(APIError.cantBuildURL.errorDescription, L10n.HaApi.ApiError.cantBuildUrl)
        XCTAssertEqual(APIError.notConfigured.errorDescription, L10n.HaApi.ApiError.notConfigured)
        XCTAssertEqual(APIError.updateNotPossible.errorDescription, L10n.HaApi.ApiError.updateNotPossible)
        XCTAssertEqual(
            APIError.mobileAppComponentNotLoaded.errorDescription,
            L10n.HaApi.ApiError.mobileAppComponentNotLoaded
        )
        let current: Version = "0.100.0"
        let minimum: Version = "2021.1.0"
        XCTAssertEqual(
            APIError.mustUpgradeHomeAssistant(current: current, minimum: minimum).errorDescription,
            L10n.HaApi.ApiError.mustUpgradeHomeAssistant(current.description, minimum.description)
        )
        XCTAssertEqual(APIError.noAPIAvailable.errorDescription, L10n.HaApi.ApiError.noAvailableApi)
        XCTAssertEqual(APIError.unknown.errorDescription, L10n.HaApi.ApiError.unknown)
    }
}
