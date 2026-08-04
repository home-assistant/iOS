import CoreLocation
@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

final class ForceQuitNotifierTests: XCTestCase {
    private var dispatcher: MockLocalNotificationDispatcher!
    private var previousDispatcher: LocalNotificationDispatcherProtocol!
    private var previousServers: ServerManager!
    private var previousNotifyOnForceQuit: Bool!
    private var previousLocationSources: SettingsStore.LocationSource!

    override func setUp() {
        super.setUp()

        previousDispatcher = Current.notificationDispatcher
        previousServers = Current.servers
        previousNotifyOnForceQuit = Current.settingsStore.notifyOnForceQuit
        previousLocationSources = Current.settingsStore.locationSources

        dispatcher = MockLocalNotificationDispatcher()
        Current.notificationDispatcher = dispatcher
        Current.servers = FakeServerManager(initial: 1)
        Current.settingsStore.notifyOnForceQuit = true
        Current.settingsStore.locationSources = .init(
            zone: true,
            backgroundFetch: true,
            significantLocationChange: true,
            pushNotifications: true
        )
    }

    override func tearDown() {
        Current.notificationDispatcher = previousDispatcher
        Current.servers = previousServers
        Current.settingsStore.notifyOnForceQuit = previousNotifyOnForceQuit
        Current.settingsStore.locationSources = previousLocationSources

        super.tearDown()
    }

    func testNotifiesWhenBackgroundLocationIsInUse() {
        makeNotifier().notifyIfNeeded()

        XCTAssertEqual(dispatcher.sentNotifications.map(\.id), [.forceQuit])
    }

    func testDoesNotNotifyWhenSettingIsDisabled() {
        Current.settingsStore.notifyOnForceQuit = false

        makeNotifier().notifyIfNeeded()

        XCTAssertTrue(dispatcher.sentNotifications.isEmpty)
    }

    func testDoesNotNotifyWhenNoServerIsConfigured() {
        Current.servers = FakeServerManager(initial: 0)

        makeNotifier().notifyIfNeeded()

        XCTAssertTrue(dispatcher.sentNotifications.isEmpty)
    }

    func testDoesNotNotifyWithoutAlwaysLocationPermission() {
        makeNotifier(locationPermissionStatus: .authorizedWhenInUse).notifyIfNeeded()

        XCTAssertTrue(dispatcher.sentNotifications.isEmpty)
    }

    func testDoesNotNotifyWhenEveryLocationSourceIsDisabled() {
        Current.settingsStore.locationSources = .init(
            zone: false,
            backgroundFetch: false,
            significantLocationChange: false,
            pushNotifications: false
        )

        makeNotifier().notifyIfNeeded()

        XCTAssertTrue(dispatcher.sentNotifications.isEmpty)
    }

    func testNotifiesWhenTheApplicationWillTerminate() {
        let notificationCenter = NotificationCenter()
        let notifier = makeNotifier(notificationCenter: notificationCenter)

        // The notification center holds its observer unretained, so the notifier has to stay alive
        // for the whole post-and-assert.
        withExtendedLifetime(notifier) {
            notificationCenter.post(name: UIApplication.willTerminateNotification, object: nil)

            XCTAssertEqual(dispatcher.sentNotifications.map(\.id), [.forceQuit])
        }
    }

    private func makeNotifier(
        notificationCenter: NotificationCenter = NotificationCenter(),
        locationPermissionStatus: CLAuthorizationStatus = .authorizedAlways
    ) -> ForceQuitNotifier {
        ForceQuitNotifier(
            notificationCenter: notificationCenter,
            locationPermissionStatus: { locationPermissionStatus }
        )
    }
}
