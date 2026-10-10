import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing
import UIKit

/// Routing of `homeassistant://` deep links. The `camera` link used to open the native camera player;
/// it now lands on the entity's more-info dialog, so links created before the change keep working.
struct IncomingURLHandlerTests {
    private func withFakeServer(_ body: (Server, MockAppCoordinator, IncomingURLHandler) throws -> Void) throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        Current.servers = manager

        let coordinator = MockAppCoordinator()
        let handler = IncomingURLHandler(coordinator: coordinator)
        try body(server, coordinator, handler)
    }

    private func withAppIconShortcutConfig(item: MagicItem, _ body: () throws -> Void) throws {
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        try database.write { db in
            try AppIconShortcutConfig(items: [item]).save(db)
        }

        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }

        try body()
    }

    @Test func cameraDeeplinkOpensTheMoreInfoDialog() throws {
        try withFakeServer { server, coordinator, handler in
            let url = try #require(URL(
                string: "\(AppConstants.deeplinkURL.absoluteString)camera/?entityId=camera.porch&serverId=\(server.identifier.rawValue)"
            ))

            #expect(handler.handle(url: url))

            let opened = try #require(coordinator.openedDeeplinks.first)
            #expect(opened.server.identifier == server.identifier)
            #expect(opened.urlString.contains("\(AppConstants.QueryItems.openMoreInfoDialog.rawValue)=camera.porch"))
            #expect(coordinator.openedDeeplinksSelectingServer.isEmpty)
        }
    }

    @Test func cameraDeeplinkWithoutEntityIsRejected() throws {
        try withFakeServer { server, coordinator, handler in
            let url = try #require(URL(
                string: "\(AppConstants.deeplinkURL.absoluteString)camera/?serverId=\(server.identifier.rawValue)"
            ))

            #expect(!handler.handle(url: url))
            #expect(coordinator.openedDeeplinks.isEmpty)
            #expect(coordinator.openedDeeplinksSelectingServer.isEmpty)
        }
    }

    @Test func settingsDeeplinkShowsAppSettings() throws {
        try withFakeServer { _, coordinator, handler in
            let url = try #require(URL(string: "\(AppConstants.deeplinkURL.absoluteString)settings"))

            #expect(handler.handle(url: url))

            #expect(coordinator.showSettingsCalled)
            #expect(!coordinator.showSettingsPushedOntoNavigationStack)
            #expect(coordinator.openedDeeplinks.isEmpty)
            #expect(coordinator.openedDeeplinksSelectingServer.isEmpty)
        }
    }

    @Test func appIconShortcutNavigateStripsLeadingSlash() throws {
        try withFakeServer { server, coordinator, handler in
            let item = MagicItem(
                id: "light.input_test",
                serverId: server.identifier.rawValue,
                type: .entity,
                action: .navigate("/ios-input-test/0")
            )

            try withAppIconShortcutConfig(item: item) {
                let shortcutItem = UIApplicationShortcutItem(
                    type: "appIconShortcut.\(item.serverId)|\(item.type.rawValue)|\(item.id)",
                    localizedTitle: "Input test"
                )

                try handler.handle(shortcutItem: shortcutItem).wait()

                let routedURLString = try #require(coordinator.openedDeeplinksSelectingServer.first)
                let components = try #require(URLComponents(string: routedURLString))
                #expect(components.path == "/ios-input-test/0")
                #expect(coordinator.openedDeeplinks.isEmpty)
            }
        }
    }

    /// The prompts wait for a frontend to exist; `webView` is created in `viewDidLoad`, so it is loaded first.
    /// The scene manager is process-wide, so whichever frontend it knew before is put back afterwards.
    @MainActor
    private func withFakeServerAndFrontend(
        _ body: (Server, MockAppCoordinator, IncomingURLHandler) async throws -> Void
    ) async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        Current.servers = manager

        let previousWebViewController = Current.sceneManager.webViewControllerPromise.value
        defer {
            if let previousWebViewController {
                Current.sceneManager.setWebViewController(previousWebViewController)
            }
        }
        let webViewController = WebViewController(server: server)
        webViewController.loadViewIfNeeded()
        Current.sceneManager.setWebViewController(webViewController)

        let coordinator = MockAppCoordinator()
        let handler = IncomingURLHandler(coordinator: coordinator)
        try await body(server, coordinator, handler)
    }

    /// The alert arrives through a promise that resolves on the main queue, which a test isolated to the
    /// main actor only lets run while it is suspended.
    @MainActor
    private func waitForPresentation(on coordinator: MockAppCoordinator) async {
        let deadline = Date().addingTimeInterval(5)
        while coordinator.presentedViewControllers.isEmpty, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// A link to a route the app does not have is still "handled" — with an error on top of whatever is on
    /// screen, rather than silently.
    @MainActor @Test func unknownRouteShowsAnError() async throws {
        try await withFakeServerAndFrontend { _, coordinator, handler in
            let url = try #require(URL(string: "\(AppConstants.deeplinkURL.absoluteString)no-such-route"))

            #expect(handler.handle(url: url))

            await waitForPresentation(on: coordinator)
            let alert = try #require(coordinator.presentedViewControllers.last as? UIAlertController)
            #expect(alert.title == L10n.errorLabel)
            #expect(alert.message == L10n.UrlHandler.NoService.message("no-such-route"))
            #expect(alert.actions.map(\.title) == [L10n.okLabel])
        }
    }

    /// Firing an event from a link is confirmed first, and cancelling leaves the server alone.
    @MainActor @Test func fireEventLinkAsksBeforeFiring() async throws {
        try await withFakeServerAndFrontend { _, coordinator, handler in
            let url = try #require(URL(string: "\(AppConstants.deeplinkURL.absoluteString)fire_event/custom_event"))

            #expect(handler.handle(url: url))

            await waitForPresentation(on: coordinator)
            let alert = try #require(coordinator.presentedViewControllers.last as? UIAlertController)
            #expect(alert.title == L10n.UrlHandler.FireEvent.Confirm.title)
            #expect(alert.message == L10n.UrlHandler.FireEvent.Confirm.message("custom_event"))
            #expect(alert.actions.map(\.title) == [L10n.cancelLabel, L10n.yesLabel])
            #expect(alert.actions.map(\.style) == [.cancel, .default])
        }
    }
}
