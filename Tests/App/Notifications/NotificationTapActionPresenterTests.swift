import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import UIKit
import UserNotifications
import XCTest

/// A notification the user taps instead of pressing and holding: once the setting is on, the actions
/// iOS kept hidden are offered in an alert, unless the payload already asked that tap to do something
/// else.
final class NotificationTapActionPresenterTests: XCTestCase {
    private var sut: NotificationTapActionPresenter!
    private var server: Server!
    private var api: FakeTapActionAPI!
    private var coordinator: MockAppCoordinator!
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousServers: ServerManager!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var previousTapActionsEnabled: Bool!
    private var previousCoordinator: AppCoordinator?

    @MainActor
    override func setUp() async throws {
        database = try DatabaseQueue()
        try NotificationCategoryTable().createIfNeeded(database: database)
        try NotificationSnoozeActionTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { self.database }

        previousServers = Current.servers
        previousCachedApis = Current.cachedApis

        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()

        api = FakeTapActionAPI(server: server)
        Current.setCachedApi(api, for: server.identifier)

        previousCoordinator = await Self.currentAppCoordinator()
        coordinator = MockAppCoordinator()
        Current.sceneManager.registerAppCoordinator(coordinator)

        previousTapActionsEnabled = Current.settingsStore.notificationTapActionsEnabled
        Current.settingsStore.notificationTapActionsEnabled = true

        sut = NotificationTapActionPresenter()
    }

    override func tearDown() {
        Current.database = previousDatabase
        Current.servers = previousServers
        Current.cachedApis = previousCachedApis
        Current.settingsStore.notificationTapActionsEnabled = previousTapActionsEnabled

        if let previousCoordinator {
            Current.sceneManager.registerAppCoordinator(previousCoordinator)
        }

        super.tearDown()
    }

    // MARK: - The setting that turns this on

    /// The whole feature is opt-in: until the switch in Settings › Notifications is on, a tap keeps
    /// doing exactly what it used to.
    @MainActor
    func testOffersNothingUntilTheSettingIsTurnedOn() {
        Current.settingsStore.notificationTapActionsEnabled = false

        let content = content(userInfo: ["actions": [["identifier": "OPEN", "title": "Open the gate"]]])

        XCTAssertFalse(sut.present(for: content, server: server))
        XCTAssertTrue(coordinator.presentedViewControllers.isEmpty)
    }

    // MARK: - Which actions a tap offers

    @MainActor
    func testOffersTheActionsThePayloadCarries() throws {
        let alert = try presentedAlert(for: content(userInfo: [
            "actions": [
                ["identifier": "OPEN", "title": "Open the gate"],
                ["identifier": "IGNORE", "title": "Ignore"],
            ],
        ]))

        XCTAssertEqual(alert.actions.map(\.title), ["Open the gate", "Ignore", L10n.cancelLabel])
        XCTAssertEqual(alert.actions.last?.style, .cancel)
    }

    @MainActor
    func testOffersTheActionsTheNotificationsCategoryWasConfiguredWith() throws {
        save(category: "ALARM", actions: [
            NotificationAction(identifier: "DISARM", title: "Disarm"),
        ])

        // Payloads spell the category however they like; the app stores it uppercased.
        let alert = try presentedAlert(for: content(category: "alarm"))

        XCTAssertEqual(alert.actions.map(\.title), ["Disarm", L10n.cancelLabel])
    }

    @MainActor
    func testPrefersThePayloadsActionsOverTheCategorys() {
        save(category: "ALARM", actions: [NotificationAction(identifier: "DISARM", title: "Disarm")])

        let actions = NotificationTapActionPresenter.actions(
            for: content(
                category: "ALARM",
                userInfo: ["actions": [["identifier": "OPEN", "title": "Open the gate"]]]
            ),
            server: server
        )

        XCTAssertEqual(actions.map(\.identifier), ["OPEN"])
    }

    @MainActor
    func testOffersNothingWhenTheNotificationHasNoActions() {
        XCTAssertFalse(sut.present(for: content(), server: server))
        XCTAssertTrue(coordinator.presentedViewControllers.isEmpty)
    }

    /// Snooze presets are ours, added by the system whenever a notification brings no actions of its
    /// own — a tap should not turn them into the notification's actions.
    @MainActor
    func testDoesNotOfferTheSnoozePresets() {
        let content = content(category: "UNKNOWN")

        XCTAssertFalse(content.userInfoActions.isEmpty, "the system does put snooze presets on this one")
        XCTAssertTrue(NotificationTapActionPresenter.actions(for: content, server: server).isEmpty)
    }

    /// A category is stored under its identifier alone, so the row on file may belong to a different
    /// server — whose actions would be fired against this notification's server.
    @MainActor
    func testIgnoresACategoryThatBelongsToAnotherServer() {
        save(category: "ALARM", serverIdentifier: "another-server", actions: [
            NotificationAction(identifier: "DISARM", title: "Disarm"),
        ])

        let content = content(category: "ALARM")

        XCTAssertTrue(NotificationTapActionPresenter.actions(for: content, server: server).isEmpty)
        XCTAssertFalse(sut.present(for: content, server: server))
    }

    /// A category made on the device belongs to every server, so it still has actions to offer.
    @MainActor
    func testOffersACategoryThatBelongsToNoServer() {
        save(category: "ALARM", serverIdentifier: "", actions: [
            NotificationAction(identifier: "DISARM", title: "Disarm"),
        ])

        let actions = NotificationTapActionPresenter.actions(for: content(category: "ALARM"), server: server)

        XCTAssertEqual(actions.map(\.identifier), ["DISARM"])
    }

    /// The app cannot reproduce the unlock gate the system puts on an action that requires
    /// authentication, so such an action stays with the system — see `NotificationActionSplit`.
    @MainActor
    func testLeavesActionsThatRequireAuthenticationToTheSystem() throws {
        let alert = try presentedAlert(for: content(userInfo: [
            "actions": [
                ["identifier": "OPEN", "title": "Open the gate"],
                ["identifier": "UNLOCK", "title": "Unlock", "authenticationRequired": true],
            ],
        ]))

        XCTAssertEqual(alert.actions.map(\.title), ["Open the gate", L10n.cancelLabel])
    }

    @MainActor
    func testOffersNothingWhenEveryActionRequiresAuthentication() {
        save(category: "ALARM", actions: [
            NotificationAction(identifier: "DISARM", title: "Disarm", authenticationRequired: true),
        ])

        XCTAssertFalse(sut.present(for: content(category: "ALARM"), server: server))
        XCTAssertTrue(coordinator.presentedViewControllers.isEmpty)
    }

    // MARK: - Taps that already do something

    @MainActor
    func testLeavesANotificationThatRunsAShortcutAlone() {
        let content = content(userInfo: [
            "shortcut": ["name": "Good Night"],
            "actions": [["identifier": "OPEN", "title": "Open the gate"]],
        ])

        XCTAssertFalse(sut.present(for: content, server: server))
        XCTAssertTrue(coordinator.presentedViewControllers.isEmpty)
    }

    @MainActor
    func testLeavesANotificationThatSendsACommandAlone() {
        let content = content(userInfo: [
            "homeassistant": ["command": "update_complications"],
            "actions": [["identifier": "OPEN", "title": "Open the gate"]],
        ])

        XCTAssertFalse(sut.present(for: content, server: server))
    }

    @MainActor
    func testLeavesALiveActivityNotificationAlone() {
        let content = content(userInfo: [
            "homeassistant": ["live_update": true],
            "actions": [["identifier": "OPEN", "title": "Open the gate"]],
        ])

        XCTAssertFalse(sut.present(for: content, server: server))
    }

    // MARK: - How the alert reads

    @MainActor
    func testHeadsTheAlertWithTheNotificationItself() {
        let alert = sut.makeAlert(
            for: [NotificationAction(identifier: "OPEN", title: "Open the gate")],
            content: content(title: "Front gate", body: "Someone is at the gate"),
            server: server
        )

        XCTAssertEqual(alert.title, "Front gate")
        XCTAssertEqual(alert.message, "Someone is at the gate")
    }

    @MainActor
    func testFallsBackToAGenericTitleForATitlelessNotification() {
        let alert = sut.makeAlert(
            for: [NotificationAction(identifier: "OPEN", title: "Open the gate")],
            content: content(),
            server: server
        )

        XCTAssertEqual(alert.title, L10n.NotificationTapActions.title)
        XCTAssertNil(alert.message)
    }

    @MainActor
    func testMarksDestructiveActionsAsDestructive() {
        let alert = sut.makeAlert(
            for: [
                NotificationAction(identifier: "OPEN", title: "Open the gate"),
                NotificationAction(identifier: "DELETE", title: "Delete", destructive: true),
            ],
            content: content(),
            server: server
        )

        XCTAssertEqual(alert.actions.map(\.style), [.default, .destructive, .cancel])
    }

    // MARK: - Picking an action

    @MainActor
    func testPickingAnActionTellsHomeAssistantWhichOneFired() {
        sut.select(
            NotificationAction(identifier: "OPEN", title: "Open the gate"),
            content: content(category: "GATE"),
            server: server
        )

        XCTAssertEqual(api.receivedInfo?.identifier, "OPEN")
        XCTAssertEqual(api.receivedInfo?.category, "GATE")
        XCTAssertNil(api.receivedInfo?.textInput)
    }

    @MainActor
    func testPickingAnActionOpensTheURLItCarries() {
        let opened = expectation(description: "opened")
        coordinator.onOpenDeeplink = { _ in opened.fulfill() }

        sut.select(
            NotificationAction(identifier: "OPEN", title: "Open the gate"),
            content: content(userInfo: [
                "actions": [["identifier": "OPEN", "title": "Open the gate", "url": "/lovelace/gate"]],
            ]),
            server: server
        )

        wait(for: [opened], timeout: 5)
        XCTAssertEqual(coordinator.openedDeeplinks.map(\.urlString), ["/lovelace/gate"])
        XCTAssertEqual(api.receivedInfo?.identifier, "OPEN")
    }

    @MainActor
    func testPickingATextInputActionAsksWhatToSendFirst() throws {
        let presented = expectation(description: "presented")
        coordinator.onPresent = { _ in presented.fulfill() }

        sut.select(
            NotificationAction(
                identifier: "REPLY",
                title: "Reply",
                textInput: true,
                textInputButtonTitle: "Send",
                textInputPlaceholder: "Your reply"
            ),
            content: content(),
            server: server
        )

        wait(for: [presented], timeout: 5)
        let alert = try XCTUnwrap(coordinator.presentedViewControllers.last as? UIAlertController)
        XCTAssertEqual(alert.title, "Reply")
        XCTAssertEqual(alert.textFields?.count, 1)
        XCTAssertEqual(alert.textFields?.first?.placeholder, "Your reply")
        XCTAssertEqual(alert.actions.map(\.title), [L10n.cancelLabel, "Send"])
        XCTAssertNil(api.receivedInfo, "nothing is sent until there is something to send")
    }

    /// The reply alert is where the text comes from, so sending reads it back out of that alert.
    @MainActor
    func testSendsWhatWasTypedIntoTheReplyAlert() {
        let action = NotificationAction(identifier: "REPLY", title: "Reply", textInput: true)
        let alert = sut.makeTextInputAlert(for: action, content: content(), server: server)
        alert.textFields?.first?.text = "on my way"

        sut.send(action, content: content(), server: server, from: alert)

        XCTAssertEqual(api.receivedInfo?.identifier, "REPLY")
        XCTAssertEqual(api.receivedInfo?.textInput, "on my way")
    }

    /// An empty reply is still a reply: the system's own response path forwards it, so dropping it
    /// here would lose an event the user asked to send.
    @MainActor
    func testSendsAnEmptyReplyWhenNothingWasTyped() {
        sut.send(
            NotificationAction(identifier: "REPLY", title: "Reply", textInput: true),
            content: content(),
            server: server,
            from: nil
        )

        XCTAssertEqual(api.receivedInfo?.textInput, "")
    }

    /// Home Assistant rejecting the action is handled rather than left as an unhandled rejection.
    @MainActor
    func testHandlesHomeAssistantRejectingTheAction() {
        api.failure = FakeTapActionAPI.TestError.any

        sut.perform(
            NotificationAction(identifier: "OPEN", title: "Open the gate"),
            content: content(),
            server: server,
            textInput: nil
        )

        // Nothing observable comes back from a rejected action, so this just lets the promise settle.
        let settled = expectation(description: "settled")
        settled.isInverted = true
        wait(for: [settled], timeout: 0.5)

        XCTAssertEqual(api.receivedInfo?.identifier, "OPEN")
    }

    @MainActor
    func testSendingAReplyForwardsWhatWasTyped() {
        sut.perform(
            NotificationAction(identifier: "REPLY", title: "Reply", textInput: true),
            content: content(),
            server: server,
            textInput: "on my way"
        )

        XCTAssertEqual(api.receivedInfo?.identifier, "REPLY")
        XCTAssertEqual(api.receivedInfo?.textInput, "on my way")
    }

    // MARK: - Helpers

    /// The scene manager is process-wide, so a mock registered here would outlive the test and answer
    /// for every later one. Put back whatever was registered before, when there was one.
    @MainActor
    private static func currentAppCoordinator() async -> AppCoordinator? {
        guard Current.sceneManager.appCoordinator.isFulfilled else { return nil }
        return await withCheckedContinuation { continuation in
            Current.sceneManager.appCoordinator.done { continuation.resume(returning: $0) }
        }
    }

    private func content(
        title: String = "",
        body: String = "",
        category: String = "",
        userInfo: [String: Any] = [:]
    ) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        content.userInfo = userInfo
        return content
    }

    private func save(
        category identifier: String,
        serverIdentifier: String? = nil,
        actions: [NotificationAction]
    ) {
        NotificationCategory(
            identifier: identifier,
            serverIdentifier: serverIdentifier ?? server.identifier.rawValue,
            name: identifier,
            actions: actions
        ).save()
    }

    /// Offers `content`'s actions and returns the alert that reached the screen. Presentation goes
    /// through the scene manager's coordinator promise, so it lands a run loop later.
    @MainActor
    private func presentedAlert(for content: UNNotificationContent) throws -> UIAlertController {
        let presented = expectation(description: "presented")
        coordinator.onPresent = { _ in presented.fulfill() }

        XCTAssertTrue(sut.present(for: content, server: server))

        wait(for: [presented], timeout: 5)
        return try XCTUnwrap(coordinator.presentedViewControllers.last as? UIAlertController)
    }
}

private final class FakeTapActionAPI: HomeAssistantAPI {
    enum TestError: Error {
        case any
    }

    /// Set before the call to make Home Assistant reject the action.
    var failure: Error?
    private(set) var receivedInfo: PushActionInfo?

    override func handlePushAction(for info: PushActionInfo) -> Promise<Void> {
        receivedInfo = info

        if let failure {
            return Promise(error: failure)
        }
        return .value(())
    }
}
