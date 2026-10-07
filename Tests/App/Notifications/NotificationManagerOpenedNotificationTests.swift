import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import UIKit
import UserNotifications
import XCTest

/// Where opening a notification takes the user, which is the one decision a tap on a notification
/// makes: a URL, the entity it is about, or the actions it carries.
final class NotificationManagerOpenedNotificationTests: XCTestCase {
    private var sut: NotificationManager!
    private var server: Server!
    private var coordinator: MockAppCoordinator!
    private var urlOpener: MockURLOpener!
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousServers: ServerManager!
    private var previousURLOpener: URLOpening!
    private var previousTapActionsEnabled: Bool!
    private var previousCoordinator: AppCoordinator?

    @MainActor
    override func setUp() async throws {
        database = try DatabaseQueue()
        try NotificationCategoryTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { self.database }

        previousServers = Current.servers
        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()

        previousCoordinator = await Self.currentAppCoordinator()
        coordinator = MockAppCoordinator()
        Current.sceneManager.registerAppCoordinator(coordinator)

        urlOpener = MockURLOpener()
        previousURLOpener = URLOpener.shared
        URLOpener.shared = urlOpener

        previousTapActionsEnabled = Current.settingsStore.notificationTapActionsEnabled
        Current.settingsStore.notificationTapActionsEnabled = true

        sut = NotificationManager()
    }

    override func tearDown() {
        Current.database = previousDatabase
        Current.servers = previousServers
        Current.settingsStore.notificationTapActionsEnabled = previousTapActionsEnabled
        URLOpener.shared = previousURLOpener

        if let previousCoordinator {
            Current.sceneManager.registerAppCoordinator(previousCoordinator)
        }

        super.tearDown()
    }

    @MainActor
    func testOpensTheURLTheNotificationAsksFor() {
        let opened = expectation(description: "opened")
        coordinator.onOpenDeeplink = { _ in opened.fulfill() }

        sut.handleOpenedNotification(
            content: content(userInfo: ["url": "/lovelace/gate", "entity_id": "lock.front_door"]),
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            server: server
        )

        wait(for: [opened], timeout: 5)
        XCTAssertEqual(coordinator.openedDeeplinks.map(\.urlString), ["/lovelace/gate"])
        XCTAssertTrue(urlOpener.openedURLs.isEmpty, "the URL wins over the entity it also names")
    }

    /// An action picked from the notification opens the URL that action carries, and stops there: the
    /// entity fallback and the actions alert both belong to a plain tap.
    @MainActor
    func testOpensTheURLOfThePickedAction() {
        let opened = expectation(description: "opened")
        coordinator.onOpenDeeplink = { _ in opened.fulfill() }

        sut.handleOpenedNotification(
            content: content(userInfo: [
                "actions": [["identifier": "OPEN", "title": "Open the gate", "url": "/lovelace/gate"]],
            ]),
            actionIdentifier: "OPEN",
            server: server
        )

        wait(for: [opened], timeout: 5)
        XCTAssertEqual(coordinator.openedDeeplinks.map(\.urlString), ["/lovelace/gate"])
    }

    @MainActor
    func testOpensTheEntityWhenTheTapHasNoURL() {
        let opened = expectation(description: "opened")
        urlOpener.onOpen = { _ in opened.fulfill() }

        sut.handleOpenedNotification(
            content: content(userInfo: ["entity_id": "lock.front_door"]),
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            server: server
        )

        wait(for: [opened], timeout: 5)
        let openedURL = urlOpener.openedURLs.map(\.url.absoluteString).first
        XCTAssertEqual(openedURL?.contains("lock.front_door"), true)
        XCTAssertTrue(coordinator.presentedViewControllers.isEmpty)
    }

    @MainActor
    func testOffersTheActionsWhenTheTapHasNothingElseToDo() throws {
        let presented = expectation(description: "presented")
        coordinator.onPresent = { _ in presented.fulfill() }

        sut.handleOpenedNotification(
            content: content(userInfo: ["actions": [["identifier": "OPEN", "title": "Open the gate"]]]),
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            server: server
        )

        wait(for: [presented], timeout: 5)
        let alert = try XCTUnwrap(coordinator.presentedViewControllers.last as? UIAlertController)
        XCTAssertEqual(alert.actions.map(\.title), ["Open the gate", L10n.cancelLabel])
    }

    /// Picking an action that carries no URL leaves the routing with nothing to do: the event it fires
    /// is the whole of it.
    @MainActor
    func testDoesNothingForAnActionThatCarriesNoURL() {
        sut.handleOpenedNotification(
            content: content(userInfo: [
                "entity_id": "lock.front_door",
                "actions": [["identifier": "OPEN", "title": "Open the gate"]],
            ]),
            actionIdentifier: "OPEN",
            server: server
        )

        XCTAssertTrue(coordinator.openedDeeplinks.isEmpty)
        XCTAssertTrue(urlOpener.openedURLs.isEmpty)
        XCTAssertTrue(coordinator.presentedViewControllers.isEmpty)
    }

    /// The scene manager is process-wide, so a mock registered here would outlive the test and answer
    /// for every later one. Put back whatever was registered before, when there was one.
    @MainActor
    private static func currentAppCoordinator() async -> AppCoordinator? {
        guard Current.sceneManager.appCoordinator.isFulfilled else { return nil }
        return await withCheckedContinuation { continuation in
            Current.sceneManager.appCoordinator.done { continuation.resume(returning: $0) }
        }
    }

    private func content(userInfo: [String: Any]) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        return content
    }
}
