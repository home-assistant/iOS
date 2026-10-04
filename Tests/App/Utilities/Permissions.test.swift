import CoreLocation
import CoreMotion
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import UserNotifications
import XCTest

final class PermissionsTests: XCTestCase {
    private var previousFocusStatus: FocusStatusWrapper!
    private var previousURLOpener: URLOpening!
    private var previousIsCatalyst: Bool!

    override func setUp() {
        super.setUp()
        previousFocusStatus = Current.focusStatus
        previousURLOpener = URLOpener.shared
        previousIsCatalyst = Current.isCatalyst
        Current.focusStatus = FocusStatusWrapper()
    }

    override func tearDown() {
        Current.focusStatus = previousFocusStatus
        URLOpener.shared = previousURLOpener
        Current.isCatalyst = previousIsCatalyst
        super.tearDown()
    }

    func testPermissionStatusDescriptions() {
        XCTAssertEqual(PermissionStatus.notDetermined.description, "Not determined")
        XCTAssertEqual(PermissionStatus.restricted.description, "Restricted")
        XCTAssertEqual(PermissionStatus.denied.description, "Denied")
        XCTAssertEqual(PermissionStatus.authorized.description, "Authorized")
        XCTAssertEqual(PermissionStatus.authorizedWhenInUse.description, "Authorized when in use")
        XCTAssertEqual(PermissionStatus.unknown.description, "Unknown")
    }

    func testLocationStatusMapping() {
        XCTAssertEqual(CLAuthorizationStatus.notDetermined.genericStatus, .notDetermined)
        XCTAssertEqual(CLAuthorizationStatus.restricted.genericStatus, .restricted)
        XCTAssertEqual(CLAuthorizationStatus.denied.genericStatus, .denied)
        XCTAssertEqual(CLAuthorizationStatus.authorizedAlways.genericStatus, .authorized)
        XCTAssertEqual(CLAuthorizationStatus.authorizedWhenInUse.genericStatus, .authorizedWhenInUse)
    }

    func testMotionStatusMapping() {
        XCTAssertEqual(CMAuthorizationStatus.notDetermined.genericStatus, .notDetermined)
        XCTAssertEqual(CMAuthorizationStatus.restricted.genericStatus, .restricted)
        XCTAssertEqual(CMAuthorizationStatus.denied.genericStatus, .denied)
        XCTAssertEqual(CMAuthorizationStatus.authorized.genericStatus, .authorized)
    }

    func testNotificationStatusMapping() {
        XCTAssertEqual(UNAuthorizationStatus.notDetermined.genericStatus, .notDetermined)
        XCTAssertEqual(UNAuthorizationStatus.provisional.genericStatus, .restricted)
        XCTAssertEqual(UNAuthorizationStatus.denied.genericStatus, .denied)
        XCTAssertEqual(UNAuthorizationStatus.ephemeral.genericStatus, .authorized)
        XCTAssertEqual(UNAuthorizationStatus.authorized.genericStatus, .authorized)
    }

    func testFocusStatusMapping() {
        XCTAssertEqual(FocusStatusWrapper.AuthorizationStatus.notDetermined.genericStatus, .notDetermined)
        XCTAssertEqual(FocusStatusWrapper.AuthorizationStatus.authorized.genericStatus, .authorized)
        XCTAssertEqual(FocusStatusWrapper.AuthorizationStatus.denied.genericStatus, .denied)
        XCTAssertEqual(FocusStatusWrapper.AuthorizationStatus.restricted.genericStatus, .restricted)
    }

    func testTitles() {
        XCTAssertEqual(PermissionType.location.title, L10n.Onboarding.Permissions.Location.title)
        XCTAssertEqual(PermissionType.motion.title, L10n.Onboarding.Permissions.Motion.title)
        XCTAssertEqual(PermissionType.notification.title, L10n.Onboarding.Permissions.Notification.title)
        XCTAssertEqual(PermissionType.focus.title, L10n.Onboarding.Permissions.Focus.title)
    }

    func testEnableIcons() {
        XCTAssertEqual(PermissionType.location.enableIcon, .mapMarkerOutlineIcon)
        XCTAssertEqual(PermissionType.motion.enableIcon, .runIcon)
        XCTAssertEqual(PermissionType.notification.enableIcon, .bellOutlineIcon)
        XCTAssertEqual(PermissionType.focus.enableIcon, .powerSleepIcon)
    }

    func testEnableDescriptions() {
        XCTAssertEqual(
            PermissionType.location.enableDescription,
            L10n.Onboarding.Permissions.Location.grantDescription
        )
        XCTAssertEqual(PermissionType.motion.enableDescription, L10n.Onboarding.Permissions.Motion.grantDescription)
        XCTAssertEqual(
            PermissionType.notification.enableDescription,
            L10n.Onboarding.Permissions.Notification.grantDescription
        )
        XCTAssertEqual(PermissionType.focus.enableDescription, L10n.Onboarding.Permissions.Focus.grantDescription)
    }

    func testEnableBulletPoints() {
        XCTAssertEqual(PermissionType.location.enableBulletPoints.map(\.text), [
            L10n.Onboarding.Permissions.Location.Bullet.automations,
            L10n.Onboarding.Permissions.Location.Bullet.history,
            L10n.Onboarding.Permissions.Location.Bullet.wifi,
        ])
        XCTAssertEqual(PermissionType.motion.enableBulletPoints.map(\.icon), [.walkIcon, .mapMarkerDistanceIcon, .bikeIcon])
        XCTAssertEqual(PermissionType.notification.enableBulletPoints.map(\.text), [
            L10n.Onboarding.Permissions.Notification.Bullet.alert,
            L10n.Onboarding.Permissions.Notification.Bullet.commands,
            L10n.Onboarding.Permissions.Notification.Bullet.badge,
        ])
        XCTAssertEqual(PermissionType.focus.enableBulletPoints.map(\.icon), [.homeAutomationIcon, .cancelIcon])

        let ids = PermissionType.location.enableBulletPoints.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testFocusStatusComesFromTheFocusWrapper() {
        Current.focusStatus.authorizationStatus = { .authorized }
        XCTAssertEqual(PermissionType.focus.status, .authorized)
        XCTAssertTrue(PermissionType.focus.isAuthorized)

        Current.focusStatus.authorizationStatus = { .restricted }
        XCTAssertEqual(PermissionType.focus.status, .restricted)
        XCTAssertFalse(PermissionType.focus.isAuthorized)

        Current.focusStatus.authorizationStatus = { .notDetermined }
        XCTAssertFalse(PermissionType.focus.isAuthorized)
    }

    func testLocationAndMotionAuthorizationMatchTheirStatus() {
        for type in [PermissionType.location, .motion] {
            let status = type.status
            XCTAssertEqual(type.isAuthorized, status == .authorized || status == .authorizedWhenInUse)
        }
    }

    func testDeniedFocusOpensSettingsInsteadOfPrompting() {
        let opener = MockURLOpener()
        URLOpener.shared = opener
        Current.focusStatus.authorizationStatus = { .denied }
        Current.focusStatus.requestAuthorization = {
            XCTFail("a denied permission must not prompt again")
            return .value(.denied)
        }

        var result: (Bool, PermissionStatus)?
        PermissionType.focus.request { granted, status in
            result = (granted, status)
        }

        XCTAssertEqual(result?.0, false)
        XCTAssertEqual(result?.1, .denied)
        XCTAssertEqual(opener.openSettingsDestination, .focus)
    }

    func testFocusRequestReportsTheGrantedStatus() {
        Current.focusStatus.authorizationStatus = { .notDetermined }
        Current.focusStatus.requestAuthorization = { .value(.authorized) }

        let completed = expectation(description: "completed")
        var result: (Bool, PermissionStatus)?
        PermissionType.focus.request { granted, status in
            result = (granted, status)
            completed.fulfill()
        }

        wait(for: [completed], timeout: 5)
        XCTAssertEqual(result?.0, true)
        XCTAssertEqual(result?.1, .authorized)
    }

    func testFocusRequestReportsARefusal() {
        Current.focusStatus.authorizationStatus = { .notDetermined }
        Current.focusStatus.requestAuthorization = { .value(.restricted) }

        let completed = expectation(description: "completed")
        var result: (Bool, PermissionStatus)?
        PermissionType.focus.request { granted, status in
            result = (granted, status)
            completed.fulfill()
        }

        wait(for: [completed], timeout: 5)
        XCTAssertEqual(result?.0, false)
        XCTAssertEqual(result?.1, .restricted)
    }

    func testDefaultNotificationOptionsIncludeCriticalAlertsOutsideCatalyst() {
        Current.isCatalyst = false
        let options = UNAuthorizationOptions.defaultOptions
        XCTAssertTrue(options.contains(.alert))
        XCTAssertTrue(options.contains(.badge))
        XCTAssertTrue(options.contains(.sound))
        XCTAssertTrue(options.contains(.providesAppNotificationSettings))
        XCTAssertTrue(options.contains(.criticalAlert))
    }

    func testDefaultNotificationOptionsSkipCriticalAlertsOnCatalyst() {
        Current.isCatalyst = true
        XCTAssertFalse(UNAuthorizationOptions.defaultOptions.contains(.criticalAlert))
    }
}
