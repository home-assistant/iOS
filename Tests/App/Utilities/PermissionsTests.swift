import CoreLocation
import CoreMotion
import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import Testing
import UIKit
import UserNotifications

/// The onboarding permission model: each system authorization status maps onto the generic status,
/// each permission type carries its copy, and requests resolve through the injected Focus status
/// and URL opener rather than real system prompts.
@Suite(.isolatedEnvironment)
struct PermissionsTests {
    private static let allTypes: [PermissionType] = [.location, .motion, .notification, .focus]

    @Test func everyGenericStatusDescribesItself() {
        let descriptions: [PermissionStatus: String] = [
            .notDetermined: "Not determined",
            .restricted: "Restricted",
            .denied: "Denied",
            .authorized: "Authorized",
            .authorizedWhenInUse: "Authorized when in use",
            .unknown: "Unknown",
        ]
        for (status, description) in descriptions {
            #expect(status.description == description)
        }
    }

    @Test func locationStatusesMapToGenericStatuses() {
        #expect(CLAuthorizationStatus.notDetermined.genericStatus == .notDetermined)
        #expect(CLAuthorizationStatus.restricted.genericStatus == .restricted)
        #expect(CLAuthorizationStatus.denied.genericStatus == .denied)
        #expect(CLAuthorizationStatus.authorizedAlways.genericStatus == .authorized)
        #expect(CLAuthorizationStatus.authorizedWhenInUse.genericStatus == .authorizedWhenInUse)
        #expect(CLAuthorizationStatus(rawValue: 99)?.genericStatus == .unknown)
    }

    @Test func motionStatusesMapToGenericStatuses() {
        #expect(CMAuthorizationStatus.notDetermined.genericStatus == .notDetermined)
        #expect(CMAuthorizationStatus.restricted.genericStatus == .restricted)
        #expect(CMAuthorizationStatus.denied.genericStatus == .denied)
        #expect(CMAuthorizationStatus.authorized.genericStatus == .authorized)
        #expect(CMAuthorizationStatus(rawValue: 99)?.genericStatus == .unknown)
    }

    @Test func notificationStatusesMapToGenericStatuses() {
        #expect(UNAuthorizationStatus.notDetermined.genericStatus == .notDetermined)
        #expect(UNAuthorizationStatus.provisional.genericStatus == .restricted)
        #expect(UNAuthorizationStatus.denied.genericStatus == .denied)
        #expect(UNAuthorizationStatus.ephemeral.genericStatus == .authorized)
        #expect(UNAuthorizationStatus.authorized.genericStatus == .authorized)
        #expect(UNAuthorizationStatus(rawValue: 99)?.genericStatus == .unknown)
    }

    @Test func focusStatusesMapToGenericStatuses() {
        #expect(FocusStatusWrapper.AuthorizationStatus.notDetermined.genericStatus == .notDetermined)
        #expect(FocusStatusWrapper.AuthorizationStatus.authorized.genericStatus == .authorized)
        #expect(FocusStatusWrapper.AuthorizationStatus.denied.genericStatus == .denied)
        #expect(FocusStatusWrapper.AuthorizationStatus.restricted.genericStatus == .restricted)
    }

    @Test func everyPermissionTypeHasCopyAndBulletPoints() {
        let bulletCounts: [PermissionType: Int] = [.location: 3, .motion: 3, .notification: 3, .focus: 2]
        for type in Self.allTypes {
            #expect(!type.title.isEmpty)
            #expect(!type.enableDescription.isEmpty)
            _ = type.enableIcon
            let bullets = type.enableBulletPoints
            #expect(bullets.count == bulletCounts[type])
            #expect(bullets.allSatisfy { !$0.text.isEmpty && !$0.id.isEmpty })
        }
        #expect(PermissionType.location.enableIcon == MaterialDesignIcons.mapMarkerOutlineIcon)
        #expect(PermissionType.focus.enableIcon == MaterialDesignIcons.powerSleepIcon)
    }

    @Test func systemPermissionStatusesCanBeRead() {
        // The simulator's answers vary; reading them must not crash. (The notification status is
        // left out: it blocks on a round trip to the notification daemon that a busy CI machine
        // can take seconds to answer.)
        for type in [PermissionType.location, .motion] {
            let status = type.status
            #expect(type.isAuthorized == (status == .authorized || status == .authorizedWhenInUse))
        }
    }

    @Test func focusStatusFollowsTheFocusWrapper() {
        let expectations: [(FocusStatusWrapper.AuthorizationStatus, PermissionStatus, Bool)] = [
            (.notDetermined, .notDetermined, false),
            (.authorized, .authorized, true),
            (.denied, .denied, false),
            (.restricted, .restricted, false),
        ]
        for (focusStatus, status, authorized) in expectations {
            Current.focusStatus.authorizationStatus = { focusStatus }
            #expect(PermissionType.focus.status == status)
            #expect(PermissionType.focus.isAuthorized == authorized)
        }
    }

    @Test(arguments: [FocusStatusWrapper.AuthorizationStatus.authorized, .denied])
    func requestingFocusAsksTheWrapper(_ answer: FocusStatusWrapper.AuthorizationStatus) async {
        Current.focusStatus.authorizationStatus = { .notDetermined }
        Current.focusStatus.requestAuthorization = { .value(answer) }

        let result = await requestResult(.focus)

        #expect(result?.granted == (answer == .authorized))
        #expect(result?.status == answer.genericStatus)
    }

    /// A denied permission sends the user to Settings instead of asking again.
    @Test(.sharedState) func requestingADeniedPermissionOpensSettings() async {
        Current.focusStatus.authorizationStatus = { .denied }
        let previousOpener = URLOpener.shared
        let opener = MockURLOpener()
        URLOpener.shared = opener
        defer { URLOpener.shared = previousOpener }

        let result = await requestResult(.focus)

        #expect(result?.granted == false)
        #expect(result?.status == .denied)
        #expect(opener.openSettingsDestination == .focus)
    }

    @Test(.isolatedEnvironment { $0.isCatalyst = false })
    func defaultNotificationOptionsIncludeCriticalAlertsOnIOS() {
        let options = UNAuthorizationOptions.defaultOptions
        #expect(options.contains(.criticalAlert))
        #expect(options.contains([.alert, .badge, .sound, .providesAppNotificationSettings]))
    }

    @Test(.isolatedEnvironment { $0.isCatalyst = true })
    func defaultNotificationOptionsSkipCriticalAlertsOnCatalyst() {
        #expect(!UNAuthorizationOptions.defaultOptions.contains(.criticalAlert))
    }

    @Test(.isolatedEnvironment { $0.isCatalyst = true })
    func catalystSettingsDestinationsPointAtSystemPreferences() {
        #expect(OpenSettingsDestination.location.url?.absoluteString.contains("Privacy_LocationServices") == true)
        #expect(OpenSettingsDestination.notification.url?.absoluteString.contains("notifications") == true)
        #expect(OpenSettingsDestination.focus.url?.absoluteString.contains("notifications") == true)
        let withoutPane: [OpenSettingsDestination] = [
            .motion, .backgroundRefresh, .health, .camera, .microphone, .speech, .bluetooth, .localNetwork,
        ]
        for destination in withoutPane {
            #expect(destination.url == nil)
        }
    }

    @Test(.isolatedEnvironment { $0.isCatalyst = false })
    func iOSSettingsDestinationsOpenTheAppSettings() {
        #expect(OpenSettingsDestination.camera.url?.absoluteString == UIApplication.openSettingsURLString)
        #expect(OpenSettingsDestination.location.url?.absoluteString == UIApplication.openSettingsURLString)
    }

    /// The real opener reports a destination without a URL as a failure instead of opening anything.
    /// `.sharedState`: other suites swap `URLOpener.shared` for a mock while holding the lock.
    @Test(.sharedState, .isolatedEnvironment { $0.isCatalyst = true })
    @MainActor func theRealOpenerFailsForADestinationWithoutAURL() {
        var opened: Bool?
        URLOpener.shared.openSettings(destination: .motion) { opened = $0 }
        #expect(opened == false)
    }

    @Test func theMockOpenerRecordsWhatItOpens() throws {
        let opener = MockURLOpener()
        let url = try #require(URL(string: "https://example.com"))
        var openedURL: URL?
        opener.onOpen = { openedURL = $0 }
        var completed: Bool?
        opener.open(url, options: [:]) { completed = $0 }
        #expect(opener.openedURLs.map(\.url) == [url])
        #expect(openedURL == url)
        #expect(completed == true)
        #expect(opener.canOpenURL(url))
    }

    // MARK: - Helpers

    private final class ResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value: (granted: Bool, status: PermissionStatus)?
        var result: (granted: Bool, status: PermissionStatus)? { lock.withLock { value } }
        func set(_ granted: Bool, _ status: PermissionStatus) {
            lock.withLock { if value == nil { value = (granted, status) } }
        }
    }

    /// Requests the permission and polls (at most ten seconds) for the completion handler.
    private func requestResult(_ type: PermissionType) async -> (granted: Bool, status: PermissionStatus)? {
        let box = ResultBox()
        type.request { box.set($0, $1) }
        // The answer comes back through PromiseKit on the main queue, which other suites keep busy
        // under load, so the deadline counts main-queue turns as well as time.
        _ = await LoadTolerantDeadline.waitUntil { box.result != nil }
        return box.result
    }
}
