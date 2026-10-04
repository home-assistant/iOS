import CoreSpotlight
import GRDB
@testable import HomeAssistant
import PromiseKit
import SafariServices
@testable import Shared
import SwiftUI
import UIKit
import XCTest

/// Routing of incoming URLs, user activities and app icon shortcuts by `IncomingURLHandler`: which
/// coordinator call each one ends in, and which prompt it shows before acting.
@MainActor
final class IncomingURLHandlerRoutingTests: XCTestCase {
    /// Answers `handle(userActivity:)` with a fixed result, the way a scanned tag would.
    private final class StubTagManager: TagManager {
        var result: TagManagerHandleResult = .unhandled
        private(set) var firedTags: [String] = []

        var isNFCAvailable: Bool { false }

        func readNFC() -> Promise<String> {
            .value("tag")
        }

        func writeNFC(value: String) -> Promise<String> {
            .value(value)
        }

        func writeNFC(deeplink: URL, alertMessage: String) -> Promise<Void> {
            .value(())
        }

        func handle(userActivity: NSUserActivity) -> TagManagerHandleResult {
            result
        }

        func fireEvent(tag: String) -> Promise<Void> {
            firedTags.append(tag)
            return .value(())
        }
    }

    private var previousServers: ServerManager!
    private var previousTags: TagManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var servers: FakeServerManager!
    private var server: Server!
    private var database: DatabaseQueue!
    private var tags: StubTagManager!
    private var coordinator: MockAppCoordinator!
    private var handler: IncomingURLHandler!

    override func setUp() async throws {
        previousServers = Current.servers
        previousTags = Current.tags
        previousDatabase = Current.database

        servers = FakeServerManager(initial: 0)
        server = servers.addFake()
        Current.servers = servers

        tags = StubTagManager()
        Current.tags = tags

        database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let database = database!
        Current.database = { database }

        // Prompts are presented once a frontend exists; an unloaded controller trips over `webView`.
        let webViewController = WebViewController(server: server)
        webViewController.loadViewIfNeeded()
        Current.sceneManager.setWebViewController(webViewController)

        coordinator = MockAppCoordinator()
        handler = IncomingURLHandler(coordinator: coordinator)
    }

    override func tearDown() async throws {
        Current.servers = previousServers
        Current.tags = previousTags
        Current.database = previousDatabase
        handler = nil
        coordinator = nil
        tags = nil
        database = nil
        server = nil
        servers = nil
    }

    // MARK: - Helpers

    private func deeplink(_ suffix: String) throws -> URL {
        try XCTUnwrap(URL(string: "\(AppConstants.deeplinkURL.absoluteString)\(suffix)"))
    }

    /// Runs `action` and returns the controller it presents through the coordinator.
    private func presentedController(
        file: StaticString = #filePath,
        line: UInt = #line,
        by action: () -> Void
    ) -> UIViewController? {
        let presented = expectation(description: "controller presented")
        presented.assertForOverFulfill = false
        coordinator.onPresent = { _ in presented.fulfill() }
        action()
        wait(for: [presented], timeout: 5)
        coordinator.onPresent = nil
        return coordinator.presentedViewControllers.last
    }

    private func assertNothingPresented(by action: () -> Void) {
        let presented = expectation(description: "nothing presented")
        presented.isInverted = true
        coordinator.onPresent = { _ in presented.fulfill() }
        action()
        wait(for: [presented], timeout: 0.5)
        coordinator.onPresent = nil
    }

    private func result(of promise: Promise<Void>) -> Result<Void, Error> {
        let finished = expectation(description: "promise resolved")
        var outcome: Result<Void, Error>?
        promise.pipe { result in
            switch result {
            case .fulfilled:
                outcome = .success(())
            case let .rejected(error):
                outcome = .failure(error)
            }
            finished.fulfill()
        }
        wait(for: [finished], timeout: 10)
        return outcome ?? .failure(HomeAssistantAPI.APIError.notConfigured)
    }

    private func saveShortcutConfig(_ items: [MagicItem]) throws {
        try database.write { db in
            try AppIconShortcutConfig(items: items).save(db)
        }
    }

    private func shortcutItem(for item: MagicItem) -> UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: "appIconShortcut.\(item.serverId)|\(item.type.rawValue)|\(item.id)",
            localizedTitle: item.id
        )
    }

    private func runShortcut(_ item: MagicItem) throws -> Result<Void, Error> {
        try saveShortcutConfig([item])
        return result(of: handler.handle(shortcutItem: shortcutItem(for: item)))
    }

    // MARK: - URLs without a route

    func testURLWithoutHostIsAcceptedAndDoesNothing() throws {
        let scheme = try XCTUnwrap(AppConstants.deeplinkURL.scheme)
        let url = try XCTUnwrap(URL(string: "\(scheme):nohost"))

        assertNothingPresented {
            XCTAssertTrue(handler.handle(url: url))
        }
        XCTAssertTrue(coordinator.openedDeeplinks.isEmpty)
        XCTAssertTrue(coordinator.openedDeeplinksSelectingServer.isEmpty)
    }

    func testUnknownHostShowsAnErrorAlert() throws {
        let url = try deeplink("notaroute/somewhere")

        let presented = presentedController {
            XCTAssertTrue(handler.handle(url: url))
        }

        let alert = try XCTUnwrap(presented as? UIAlertController)
        XCTAssertEqual(alert.title, L10n.errorLabel)
        XCTAssertEqual(alert.message, L10n.UrlHandler.NoService.message("notaroute"))
        XCTAssertEqual(alert.actions.map(\.title), [L10n.okLabel])
    }

    // MARK: - Confirmed actions

    func testCallServiceAsksForConfirmation() throws {
        let url = try deeplink("call_service/light.turn_on?entity_id=light.kitchen")

        let presented = presentedController {
            XCTAssertTrue(handler.handle(url: url))
        }

        let alert = try XCTUnwrap(presented as? UIAlertController)
        XCTAssertEqual(alert.title, L10n.UrlHandler.CallService.Confirm.title)
        XCTAssertEqual(alert.message, L10n.UrlHandler.CallService.Confirm.message("light.turn_on"))
        XCTAssertEqual(alert.actions.map(\.title), [L10n.cancelLabel, L10n.yesLabel])
        XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default])
    }

    func testCallServiceWithoutADomainAndServiceIsIgnored() throws {
        let missingService = try deeplink("call_service/light")
        let missingPath = try deeplink("call_service")
        let emptyDomain = try deeplink("call_service/.turn_on")

        assertNothingPresented {
            XCTAssertTrue(handler.handle(url: missingService))
            XCTAssertTrue(handler.handle(url: missingPath))
            XCTAssertTrue(handler.handle(url: emptyDomain))
        }
    }

    func testFireEventAsksForConfirmation() throws {
        let url = try deeplink("fire_event/custom_event?entity_id=device_tracker.phone")

        let presented = presentedController {
            XCTAssertTrue(handler.handle(url: url))
        }

        let alert = try XCTUnwrap(presented as? UIAlertController)
        XCTAssertEqual(alert.title, L10n.UrlHandler.FireEvent.Confirm.title)
        XCTAssertEqual(alert.message, L10n.UrlHandler.FireEvent.Confirm.message("custom_event"))
        XCTAssertEqual(alert.actions.count, 2)
    }

    func testSendLocationAsksForConfirmation() throws {
        let url = try deeplink("send_location/")

        let presented = presentedController {
            XCTAssertTrue(handler.handle(url: url))
        }

        let alert = try XCTUnwrap(presented as? UIAlertController)
        XCTAssertEqual(alert.title, L10n.UrlHandler.SendLocation.Confirm.title)
        XCTAssertEqual(alert.message, L10n.UrlHandler.SendLocation.Confirm.message)
    }

    func testRouteMatchingIsCaseInsensitive() throws {
        let url = try deeplink("SEND_LOCATION/")

        let presented = presentedController {
            XCTAssertTrue(handler.handle(url: url))
        }

        XCTAssertEqual((presented as? UIAlertController)?.title, L10n.UrlHandler.SendLocation.Confirm.title)
    }

    // MARK: - My links

    func testMyLinkOpensInSafari() throws {
        let url = try XCTUnwrap(URL(string: "https://my.home-assistant.io/redirect/config/"))

        XCTAssertTrue(handler.handle(url: url))

        XCTAssertTrue(coordinator.presentedViewControllers.last is SFSafariViewController)
        XCTAssertTrue(coordinator.openedDeeplinks.isEmpty)
    }

    func testMyLinkHostOnTheAppSchemeIsNotOpenedInSafari() throws {
        let url = try deeplink("my.home-assistant.io/redirect/config/")

        let presented = presentedController {
            XCTAssertTrue(handler.handle(url: url))
        }

        XCTAssertTrue(presented is UIAlertController)
        XCTAssertFalse(coordinator.presentedViewControllers.contains { $0 is SFSafariViewController })
    }

    // MARK: - Navigate

    func testNavigateWithAKnownServerIdOpensThatServer() throws {
        let url = try deeplink("navigate/lovelace/dashboard?serverId=\(server.identifier.rawValue)")

        XCTAssertTrue(handler.handle(url: url))

        let opened = try XCTUnwrap(coordinator.openedDeeplinks.first)
        XCTAssertEqual(opened.server.identifier, server.identifier)
        XCTAssertTrue(opened.urlString.hasPrefix("/lovelace/dashboard"))
        XCTAssertFalse(opened.urlString.contains("homeassistant"))
        XCTAssertTrue(coordinator.openedDeeplinksSelectingServer.isEmpty)
    }

    func testNavigateWithoutAServerAsksWhichServerToOpen() throws {
        let url = try deeplink("navigate/lovelace/dashboard")

        XCTAssertTrue(handler.handle(url: url))

        XCTAssertEqual(coordinator.openedDeeplinksSelectingServer, ["/lovelace/dashboard"])
        XCTAssertTrue(coordinator.openedDeeplinks.isEmpty)
    }

    func testNavigateWithAnUnknownServerIdAsksWhichServerToOpen() throws {
        let url = try deeplink("navigate/energy?serverId=unknown-server")

        XCTAssertTrue(handler.handle(url: url))

        let urlString = try XCTUnwrap(coordinator.openedDeeplinksSelectingServer.first)
        XCTAssertTrue(urlString.hasPrefix("/energy"))
        XCTAssertTrue(coordinator.openedDeeplinks.isEmpty)
    }

    func testNavigateResolvesTheServerFromItsWebhookIdAndStripsIt() throws {
        let webhookID = server.info.connection.webhookID
        let url = try deeplink("navigate/lovelace/0?webhook_id=\(webhookID)")

        XCTAssertTrue(handler.handle(url: url))

        let opened = try XCTUnwrap(coordinator.openedDeeplinks.first)
        XCTAssertEqual(opened.server.identifier, server.identifier)
        XCTAssertEqual(opened.urlString, "/lovelace/0")
        XCTAssertFalse(opened.urlString.contains("webhook_id"))
    }

    func testNavigateWithAnExplicitURLOpensThatURL() throws {
        let url = try deeplink("navigate/?url=https%3A%2F%2Fexample.com%2Fpage")

        XCTAssertTrue(handler.handle(url: url))

        XCTAssertEqual(coordinator.openedDeeplinksSelectingServer, ["https://example.com/page"])
    }

    func testNavigateFromAWidgetOpensTheServerItNames() throws {
        let url = try XCTUnwrap(AppConstants.openPageDeeplinkURL(
            path: "map",
            serverId: server.identifier.rawValue
        ))

        XCTAssertTrue(handler.handle(url: url))

        let opened = try XCTUnwrap(coordinator.openedDeeplinks.first)
        XCTAssertEqual(opened.server.identifier, server.identifier)
        XCTAssertTrue(opened.urlString.hasPrefix("/map"))
        XCTAssertFalse(opened.urlString.contains("widgetAuthenticity"))
    }

    // MARK: - Assist & invite

    func testAssistWithoutQueryParametersIsRejected() throws {
        XCTAssertFalse(try handler.handle(url: deeplink("assist")))
    }

    func testAssistWithoutAnyServerIsRejected() throws {
        servers.removeAll()

        XCTAssertFalse(try handler.handle(url: deeplink("assist?serverId=missing&pipelineId=1")))
    }

    func testInviteWithoutAFragmentIsRejected() throws {
        XCTAssertFalse(try handler.handle(url: deeplink("invite")))
    }

    // MARK: - User activities

    func testSpotlightActivityForAnUnknownEntityIsNotHandled() {
        let activity = NSUserActivity(activityType: CSSearchableItemActionType)
        activity.userInfo = [CSSearchableItemActivityIdentifier: "unknown-entity"]

        XCTAssertFalse(handler.handle(userActivity: activity))
        XCTAssertTrue(coordinator.openedDeeplinks.isEmpty)
    }

    func testSpotlightActivityOpensTheEntityMoreInfoDialog() throws {
        let entityId = "light.kitchen"
        let uniqueId = ServerEntity.uniqueId(serverId: server.identifier.rawValue, entityId: entityId)
        try database.write { db in
            try HAAppEntity(
                id: uniqueId,
                entityId: entityId,
                serverId: server.identifier.rawValue,
                domain: "light",
                name: "Kitchen",
                icon: nil,
                rawDeviceClass: nil
            ).insert(db)
        }
        let activity = NSUserActivity(activityType: CSSearchableItemActionType)
        activity.userInfo = [CSSearchableItemActivityIdentifier: uniqueId]

        XCTAssertTrue(handler.handle(userActivity: activity))

        let opened = try XCTUnwrap(coordinator.openedDeeplinks.first)
        XCTAssertEqual(opened.server.identifier, server.identifier)
        XCTAssertTrue(opened.urlString.contains("\(AppConstants.QueryItems.openMoreInfoDialog.rawValue)=\(entityId)"))
    }

    func testWebActivityForAMyLinkOpensInSafari() throws {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = try XCTUnwrap(URL(string: "https://my.home-assistant.io/redirect/info/"))

        XCTAssertTrue(handler.handle(userActivity: activity))

        XCTAssertTrue(coordinator.presentedViewControllers.last is SFSafariViewController)
    }

    func testWebActivityForAnotherSiteIsNotHandled() throws {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = try XCTUnwrap(URL(string: "https://www.home-assistant.io/"))

        XCTAssertFalse(handler.handle(userActivity: activity))
        XCTAssertTrue(coordinator.presentedViewControllers.isEmpty)
    }

    func testTagThatOpensAURLRoutesThatURL() throws {
        tags.result = try .open(deeplink("navigate/lovelace/tags"))

        XCTAssertTrue(handler.handle(userActivity: NSUserActivity(activityType: "tag")))

        XCTAssertEqual(coordinator.openedDeeplinksSelectingServer, ["/lovelace/tags"])
    }

    func testHandledTagIsReportedAsHandled() {
        tags.result = .handled(.nfc)
        XCTAssertTrue(handler.handle(userActivity: NSUserActivity(activityType: "tag")))

        tags.result = .handled(.generic)
        XCTAssertTrue(handler.handle(userActivity: NSUserActivity(activityType: "tag")))
    }

    func testTagRequiringApprovalPresentsTheApprovalSheet() throws {
        tags.result = .requiresApproval(tag: "tag-id", type: .nfc)

        let presented = presentedController {
            XCTAssertTrue(handler.handle(userActivity: NSUserActivity(activityType: "tag")))
        }

        let controller = try XCTUnwrap(presented as? UIHostingController<AnyView>)
        XCTAssertEqual(controller.modalPresentationStyle, .overFullScreen)
        XCTAssertEqual(controller.view.backgroundColor, .clear)

        // Lays the sheet out so its body is built.
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()
        XCTAssertTrue(tags.firedTags.isEmpty)
    }

    // MARK: - Shortcut items

    func testUnknownShortcutItemFails() {
        let item = UIApplicationShortcutItem(type: "not-a-shortcut", localizedTitle: "Unknown")

        guard case .failure = result(of: handler.handle(shortcutItem: item)) else {
            return XCTFail("expected an unknown shortcut to fail")
        }
    }

    func testAppIconShortcutMissingFromTheConfigFails() throws {
        try saveShortcutConfig([])
        let item = MagicItem(id: "light.kitchen", serverId: server.identifier.rawValue, type: .entity)

        guard case .failure = result(of: handler.handle(shortcutItem: shortcutItem(for: item))) else {
            return XCTFail("expected a shortcut without a configured item to fail")
        }
        XCTAssertTrue(coordinator.openedDeeplinks.isEmpty)
    }

    func testAppIconShortcutWithNoActionDoesNothing() throws {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: server.identifier.rawValue,
            type: .entity,
            action: .nothing
        )

        guard case .success = try runShortcut(item) else {
            return XCTFail("expected a no-op shortcut to succeed")
        }
        XCTAssertTrue(coordinator.openedDeeplinks.isEmpty)
        XCTAssertTrue(coordinator.openedDeeplinksSelectingServer.isEmpty)
    }

    func testAppIconShortcutMoreInfoActionOpensTheEntity() throws {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: server.identifier.rawValue,
            type: .entity,
            action: .moreInfoDialog
        )

        guard case .success = try runShortcut(item) else {
            return XCTFail("expected the more-info shortcut to succeed")
        }
        let opened = try XCTUnwrap(coordinator.openedDeeplinks.first)
        XCTAssertEqual(opened.server.identifier, server.identifier)
        XCTAssertTrue(opened.urlString.contains("\(AppConstants.QueryItems.openMoreInfoDialog.rawValue)=light.kitchen"))
    }

    func testAppIconShortcutURLActionHandlesTheAppsOwnDeeplinkInPlace() throws {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: server.identifier.rawValue,
            type: .entity,
            action: .url("\(AppConstants.deeplinkURL.absoluteString)navigate/energy")
        )

        guard case .success = try runShortcut(item) else {
            return XCTFail("expected the url shortcut to succeed")
        }
        XCTAssertEqual(coordinator.openedDeeplinksSelectingServer, ["/energy"])
    }

    func testAppIconShortcutURLActionWithoutAURLFails() throws {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: server.identifier.rawValue,
            type: .entity,
            action: .url("   ")
        )

        guard case .failure = try runShortcut(item) else {
            return XCTFail("expected an empty url shortcut to fail")
        }
    }

    func testAppIconShortcutNavigateActionStripsLeadingSlashesAndWhitespace() throws {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: server.identifier.rawValue,
            type: .entity,
            action: .navigate("  ///history  ")
        )

        guard case .success = try runShortcut(item) else {
            return XCTFail("expected the navigate shortcut to succeed")
        }
        let routed = try XCTUnwrap(coordinator.openedDeeplinksSelectingServer.first)
        XCTAssertEqual(URLComponents(string: routed)?.path, "/history")
    }

    func testAppIconShortcutPerformActionForAnUnknownServerFails() throws {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: server.identifier.rawValue,
            type: .entity,
            action: .performAction("unknown-server", "light.turn_on", "{}")
        )

        guard case .failure = try runShortcut(item) else {
            return XCTFail("expected an action on an unknown server to fail")
        }
    }

    func testAppIconShortcutPerformActionThatIsNotDomainDotServiceFails() throws {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: server.identifier.rawValue,
            type: .entity,
            action: .performAction(server.identifier.rawValue, "not_an_action", "{}")
        )

        guard case .failure = try runShortcut(item) else {
            return XCTFail("expected a malformed action id to fail")
        }
    }

    func testAppIconShortcutRunScriptForAnUnknownServerFails() throws {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: server.identifier.rawValue,
            type: .entity,
            action: .runScript("unknown-server", "script.goodnight")
        )

        guard case .failure = try runShortcut(item) else {
            return XCTFail("expected a script on an unknown server to fail")
        }
    }

    // MARK: - X-Callback-URL errors

    func testXCallbackErrorCodesAndMessages() {
        XCTAssertEqual(IncomingURLHandler.XCallbackError.generalError.code, 0)
        XCTAssertEqual(IncomingURLHandler.XCallbackError.eventNameMissing.code, 1)
        XCTAssertEqual(IncomingURLHandler.XCallbackError.serviceMissing.code, 2)
        XCTAssertEqual(IncomingURLHandler.XCallbackError.templateMissing.code, 2)

        XCTAssertEqual(
            IncomingURLHandler.XCallbackError.generalError.message,
            L10n.UrlHandler.XCallbackUrl.Error.general
        )
        XCTAssertEqual(
            IncomingURLHandler.XCallbackError.eventNameMissing.message,
            L10n.UrlHandler.XCallbackUrl.Error.eventNameMissing
        )
        XCTAssertEqual(
            IncomingURLHandler.XCallbackError.serviceMissing.message,
            L10n.UrlHandler.XCallbackUrl.Error.serviceMissing
        )
        XCTAssertEqual(
            IncomingURLHandler.XCallbackError.templateMissing.message,
            L10n.UrlHandler.XCallbackUrl.Error.templateMissing
        )
    }
}
