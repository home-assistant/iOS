import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

/// Answers the update check with whatever the test decided, without going near GitHub.
private final class FakeUpdater: Updater {
    var result: Swift.Result<AvailableUpdate, Error> = .failure(Updater.UpdateError.onLatestVersion)
    private(set) var checks: [Bool] = []

    override var isSupported: Bool { true }

    override func check(dueToUserInteraction: Bool) -> Promise<AvailableUpdate> {
        checks.append(dueToUserInteraction)
        switch result {
        case let .success(update): return .value(update)
        case let .failure(error): return Promise(error: error)
        }
    }
}

@MainActor
final class AppDelegateUpdateAlertTests: XCTestCase {
    private var updater: FakeUpdater!
    private var coordinator: MockAppCoordinator!
    private var previousUpdater: Updater!
    private var previousOpener: URLOpening!
    private var opener: MockURLOpener!

    override func setUp() {
        super.setUp()
        updater = FakeUpdater()
        coordinator = MockAppCoordinator()
        opener = MockURLOpener()
        previousUpdater = Current.updater
        previousOpener = URLOpener.shared
        Current.updater = updater
        URLOpener.shared = opener
        Current.sceneManager.registerAppCoordinator(coordinator)
    }

    override func tearDown() {
        Current.updater = previousUpdater
        URLOpener.shared = previousOpener
        super.tearDown()
    }

    private func waitForAlert() {
        let deadline = Date().addingTimeInterval(5)
        while coordinator.presentedAlerts.isEmpty, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    func testAnAvailableUpdateIsOfferedAndItsPageOpensFromTheAlert() throws {
        let update = AvailableUpdate(
            id: 1,
            htmlUrl: URL(string: "https://github.com/home-assistant/iOS/releases/tag/release-2026.11.0")!,
            tagName: "release-2026.11.0",
            name: "2026.11.0",
            prerelease: false,
            assets: []
        )
        updater.result = .success(update)

        try XCTUnwrap(AppDelegate.shared).checkForUpdate(self)

        waitForAlert()
        let alert = try XCTUnwrap(coordinator.presentedAlerts.first)
        XCTAssertEqual(updater.checks, [true])
        XCTAssertEqual(alert.title, L10n.Updater.UpdateAvailable.title)
        XCTAssertEqual(alert.actions.map(\.title), [L10n.Updater.UpdateAvailable.open("2026.11.0"), L10n.okLabel])

        alert.actions[0].handler?()
        XCTAssertEqual(opener.openedURLs.map(\.url), [update.htmlUrl])
    }

    /// A check the user asked for says so when there is nothing new; one the app runs by itself stays quiet.
    func testNoUpdateIsReportedOnlyWhenTheUserAsked() throws {
        updater.result = .failure(Updater.UpdateError.onLatestVersion)

        try XCTUnwrap(AppDelegate.shared).checkForUpdate(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertTrue(coordinator.presentedAlerts.isEmpty)

        try XCTUnwrap(AppDelegate.shared).checkForUpdate(self)
        waitForAlert()
        let alert = try XCTUnwrap(coordinator.presentedAlerts.first)
        XCTAssertEqual(updater.checks, [false, true])
        XCTAssertEqual(alert.title, L10n.Updater.NoUpdatesAvailable.title)
        XCTAssertEqual(alert.message, L10n.Updater.NoUpdatesAvailable.onLatestVersion)
        XCTAssertEqual(alert.actions.map(\.title), [L10n.okLabel])
    }

    func testTheNotificationCategoryDeprecationAlertIsRememberedOnceAnswered() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AppDelegateUpdateAlertTests"))
        defer { defaults.removePersistentDomain(forName: "AppDelegateUpdateAlertTests") }
        let seenKey = "category-deprecation-test"

        let alert = AppDelegate.notificationCategoryDeprecationAlert(userDefaults: defaults, seenKey: seenKey)

        XCTAssertEqual(alert.title, L10n.Alerts.Deprecations.NotificationCategory.title)
        XCTAssertEqual(alert.actions.map(\.title), [L10n.Nfc.List.learnMore, L10n.okLabel])
        XCTAssertFalse(defaults.bool(forKey: seenKey))

        alert.actions[1].handler?()
        XCTAssertTrue(defaults.bool(forKey: seenKey))

        defaults.set(false, forKey: seenKey)
        alert.actions[0].handler?()
        XCTAssertTrue(defaults.bool(forKey: seenKey))
        XCTAssertEqual(
            opener.openedURLs.last?.url.absoluteString,
            "https://companion.home-assistant.io/app/ios/actionable-notifications"
        )
    }
}
