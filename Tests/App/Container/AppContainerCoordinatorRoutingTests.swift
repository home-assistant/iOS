import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// How the container coordinator routes requests that carry no window of their own: the hooks
/// `ContainerView` installs, links resolved against one or several servers, invite links before and
/// after a frontend exists, and the Settings presenter's picker state.
///
/// `.sharedState`: the tests swap `Current.servers` and `URLOpener.shared`, and write the invite URL
/// and link-confirmation preference.
@Suite(.sharedState)
@MainActor
struct AppContainerCoordinatorRoutingTests {
    private struct World {
        let coordinator: AppContainerCoordinator
        let frontend: MockWebFrontend
        let presenter: AppSettingsPresenter
        let window: UIWindow
        let servers: FakeServerManager
    }

    private func withWorld(serverCount: Int = 1, _ body: (World) async throws -> Void) async rethrows {
        let previousServers = Current.servers
        let previousOpener = URLOpener.shared
        let previousConfirm = prefs.object(forKey: "confirmBeforeOpeningUrl")
        let previousBrowser = prefs.object(forKey: "openInBrowser")
        defer {
            Current.servers = previousServers
            URLOpener.shared = previousOpener
            prefs.set(previousConfirm, forKey: "confirmBeforeOpeningUrl")
            prefs.set(previousBrowser, forKey: "openInBrowser")
        }
        let servers = FakeServerManager(initial: serverCount)
        Current.servers = servers
        URLOpener.shared = MockURLOpener()
        prefs.set(false, forKey: "confirmBeforeOpeningUrl")
        prefs.set(OpenInBrowser.Safari.rawValue, forKey: "openInBrowser")

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        let frontend = MockWebFrontend(server: servers.all[0], presentationWindow: window)
        let presenter = AppSettingsPresenter()
        let coordinator = AppContainerCoordinator(themeModeApplier: FrontendThemeModeApplier(windowScenes: { [] }))
        coordinator.settingsPresenter = presenter
        presenter.appCoordinator = coordinator
        coordinator.setFrontend(frontend)
        try await body(World(
            coordinator: coordinator,
            frontend: frontend,
            presenter: presenter,
            window: window,
            servers: servers
        ))
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    @Test func hooksReachWhatContainerViewInstalled() async {
        await withWorld { world in
            var calls: [String] = []
            world.coordinator.onShowSettings = { calls.append("settings") }
            world.coordinator.onShowAssistSettings = { calls.append("assist") }
            world.coordinator.onShowDownloadManager = { _ in calls.append("download") }
            world.coordinator.onShowOnboardingPermissions = { _, steps in calls.append("permissions \(steps.count)") }
            world.coordinator.onSetup = { calls.append("setup") }

            world.coordinator.showSettings()
            world.coordinator.showAssistSettings()
            world.coordinator.showDownloadManager(DownloadManagerViewModel())
            world.coordinator.showOnboardingPermissions(server: world.servers.all[0], steps: [])
            world.coordinator.setup()

            #expect(calls == ["settings", "assist", "download", "permissions 0", "setup"])
            #expect(world.coordinator.window === world.window)
            #expect(world.coordinator.presentedViewController === world.window.rootViewController)
        }
    }

    @Test func aCoordinatorWithoutAFrontendFallsBackToTheActiveScene() {
        let coordinator = AppContainerCoordinator(themeModeApplier: FrontendThemeModeApplier(windowScenes: { [] }))
        #expect(coordinator.window == nil)
        // Whatever the host app shows; reading it must not crash.
        _ = coordinator.presentedViewController
    }

    @Test func inviteLinksWaitForAFrontend() async {
        let previousInvite = Current.appSessionValues.inviteURL
        defer { Current.appSessionValues.inviteURL = previousInvite }
        let invite = URL(string: "https://my.home-assistant.io/invite#url=http://ha.local:8123")!

        let coordinator = AppContainerCoordinator(themeModeApplier: FrontendThemeModeApplier(windowScenes: { [] }))
        coordinator.presentInvitation(url: nil)
        coordinator.presentInvitation(url: invite)
        #expect(Current.appSessionValues.inviteURL == invite)

        await withWorld { world in
            world.coordinator.presentInvitation(url: invite)
            await #expect(waitUntil { world.frontend.presentedOverlayControllers.count == 1 })
        }
    }

    @Test func aLinkWithOneServerOpensOnIt() async {
        await withWorld { world in
            world.coordinator.openSelectingServer(
                from: .deeplink,
                urlString: "/lovelace/0",
                skipConfirm: true,
                isComingFromAppIntent: false
            )
            await #expect(waitUntil { !world.frontend.openedInlineURLs.isEmpty })
        }
    }

    @Test func aLinkNamingAServerOpensOnThatServer() async {
        await withWorld(serverCount: 2) { world in
            let target = world.servers.all[1]
            var opened: [Server] = []
            world.coordinator.onOpenServer = { opened.append($0) }
            world.coordinator.openSelectingServer(
                from: .notification,
                urlString: "/config",
                skipConfirm: true,
                queryParameters: [
                    .init(name: "server", value: target.identifier.rawValue),
                    .init(name: "avoidUnnecessaryReload", value: "true"),
                ],
                isComingFromAppIntent: true
            )
            // Another server has to be opened first; the container then hands its frontend over.
            await #expect(waitUntil { opened.map(\.identifier) == [target.identifier] })
            let frontend = MockWebFrontend(server: target, presentationWindow: world.window)
            world.coordinator.setFrontend(frontend)
            await #expect(waitUntil { !frontend.openedPanelURLs.isEmpty })
        }
    }

    @Test func aLinkWithSeveralServersAsksWhichOne() async {
        await withWorld(serverCount: 2) { world in
            world.coordinator.openSelectingServer(
                from: .deeplink,
                urlString: "/lovelace/0",
                skipConfirm: false,
                isComingFromAppIntent: false
            )
            await #expect(waitUntil { world.presenter.isSheetPresented })
            #expect(world.presenter.mode == .serverSelection)
            #expect(world.presenter.selectionRequest?.prompt?.link == "/lovelace/0")

            // Picking the frontend's own server opens the link right away.
            world.presenter.completeServerSelection(world.servers.all[0])
            #expect(!world.presenter.isSheetPresented)
            await #expect(waitUntil { !world.frontend.openedInlineURLs.isEmpty })
        }
    }

    @Test func anExternalLinkOpensInTheBrowser() async throws {
        try await withWorld { world in
            let opener = try #require(URLOpener.shared as? MockURLOpener)
            world.coordinator.open(
                from: .deeplink,
                server: world.servers.all[0],
                urlString: "https://www.home-assistant.io",
                skipConfirm: true,
                isComingFromAppIntent: false
            )
            await #expect(waitUntil { !opener.openedURLs.isEmpty })
        }
    }

    @Test func thePresenterMovesBetweenPickerAndSettings() async {
        await withWorld { world in
            let presenter = world.presenter
            presenter.presentServerSelection(.init(prompt: nil, zoomsFromStandBy: false, onSelect: { _ in }))
            presenter.showFullSettings()
            #expect(presenter.mode == .full)
            #expect(presenter.detent == .large)
            presenter.showServerSelection()
            #expect(presenter.mode == .serverSelection)
            #expect(presenter.detent == .medium)

            // Without a request the picked server is activated through the coordinator.
            presenter.sheetDismissed()
            presenter.isSheetPresented = false
            presenter.sheetDismissed()
            var opened: [Server] = []
            world.coordinator.onOpenServer = { opened.append($0) }
            presenter.completeServerSelection(world.servers.all[0])
            // The frontend already shows that server, so it goes back to its root instead.
            #expect(world.frontend.navigateToRootCallCount == 1)
            #expect(opened.isEmpty)
        }
    }
}
