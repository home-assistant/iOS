import Foundation
import PromiseKit
import Shared
import SwiftUI
import UIKit

/// App coordinator for the primary web view, owned by `ContainerView` — the SwiftUI replacement for
/// `WebViewWindowController`'s presentation duties. It drives the active `WebFrontend` (published by the
/// `WebFrontendView`) and routes server/onboarding changes through `OnboardingStateObservable` via hooks.
final class AppContainerCoordinator: AppCoordinator {
    weak var frontend: (any WebFrontend)?

    /// Set by `ContainerView` to drive `OnboardingStateObservable` (the screen/server source of truth).
    var onOpenServer: ((Server) -> Void)?
    var onSetup: (() -> Void)?
    /// Set by `ContainerView` to present Settings as a sheet over the web view (non-Catalyst).
    var onShowSettings: (() -> Void)?
    /// Set by `ContainerView` to present Assist settings as a sheet over the web view.
    var onShowAssistSettings: (() -> Void)?
    /// Set by `ContainerView` to present the download manager (iOS 17+) as a sheet over the web view.
    var onShowDownloadManager: ((DownloadManagerViewModel) -> Void)?
    /// Set by `ContainerView` to present the forced onboarding-permissions decision as a full-screen cover.
    var onShowOnboardingPermissions: ((Server, [OnboardingPermissionsNavigationViewModel.StepID]) -> Void)?
    /// Set by `ContainerView` to present the server picker as a sheet. The picked server is delivered back
    /// via `completeServerSelection(_:)` (the completion can't be forwarded through this non-escaping hook).
    var onSelectServer: ((String?, Bool) -> Void)?
    private var pendingServerSelection: ((Server) -> Void)?

    /// Seals for in-flight `open(server:)` requests, keyed by server. Keyed + arrayed so concurrent opens
    /// (same or different servers) don't overwrite each other and leave callers hanging.
    private var pendingOpens: [Identifier<Server>: [(any WebFrontend) -> Void]] = [:]

    /// Called by `ContainerView` whenever the active `WebFrontendView` (re)creates its frontend.
    /// Resolves every pending `open(server:)` for the server whose frontend just appeared.
    func setFrontend(_ frontend: any WebFrontend) {
        self.frontend = frontend
        let seals = pendingOpens.removeValue(forKey: frontend.server.identifier) ?? []
        seals.forEach { $0(frontend) }
    }

    var window: UIWindow? { frontend?.presentationWindow }

    var presentedViewController: UIViewController? {
        var current = frontend?.presentationWindow?.rootViewController
        while let next = current?.presentedViewController {
            current = next
        }
        return current
    }

    func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
        presentedViewController?.present(viewController, animated: animated, completion: completion)
    }

    func show(alert: ServerAlert) {
        frontend?.show(alert: alert)
    }

    func showSettings() {
        // On Catalyst with multiple scenes, Settings is its own window; otherwise present it as a sheet
        // over the web view via `ContainerView`.
        if Current.sceneManager.supportsMultipleScenes, Current.isCatalyst {
            Current.sceneManager.activateAnyScene(for: .settings)
        } else {
            onShowSettings?()
        }
    }

    func showAssistSettings() {
        onShowAssistSettings?()
    }

    func showDownloadManager(_ viewModel: DownloadManagerViewModel) {
        onShowDownloadManager?(viewModel)
    }

    func showOnboardingPermissions(server: Server, steps: [OnboardingPermissionsNavigationViewModel.StepID]) {
        onShowOnboardingPermissions?(server, steps)
    }

    @discardableResult
    func open(server: Server) -> Guarantee<any WebFrontend> {
        if let current = frontend, current.server.identifier == server.identifier {
            return .value(current)
        }
        let (promise, seal) = Guarantee<any WebFrontend>.pending()
        pendingOpens[server.identifier, default: []].append(seal)
        onOpenServer?(server)
        return promise
    }

    func selectServer(prompt: String?, includeSettings: Bool, completion: @escaping (Server) -> Void) {
        pendingServerSelection = completion
        onSelectServer?(prompt, includeSettings)
    }

    /// Called by `ContainerView`'s server-picker sheet when the user picks a server.
    func completeServerSelection(_ server: Server) {
        let completion = pendingServerSelection
        pendingServerSelection = nil
        completion?(server)
    }

    func presentInvitation(url inviteURL: URL?) {
        guard let inviteURL else { return }
        guard let frontend else {
            Current.appSessionValues.inviteURL = inviteURL
            return
        }
        let navigationView = NavigationView {
            OnboardingServersListView(
                prefillURL: inviteURL,
                shouldDismissOnSuccess: true,
                onboardingStyle: .secondary
            )
        }.navigationViewStyle(.stack)
        frontend.presentOverlayController(
            controller: navigationView.embeddedInHostingController(),
            animated: true
        )
    }

    func setup() {
        onSetup?()
    }

    func open(
        from: OpenSource,
        server: Server,
        urlString openUrlRaw: String,
        skipConfirm: Bool,
        avoidUnnecessaryReload: Bool,
        isComingFromAppIntent: Bool
    ) {
        // Accept the same destination forms anywhere a url is opened (notifications, deep links,
        // Live Activities, …): slash-less HA paths and the app's own navigate deep link resolve to
        // an internal path; external URLs pass through untouched.
        let openUrl = AppConstants.normalizedNavigationDestination(openUrlRaw)
        Task { @MainActor [weak self] in
            guard let self else { return }
            await open(
                from: from,
                server: server,
                urlString: openUrl,
                webviewURL: server.webviewURL(from: openUrl),
                externalURL: URL(string: openUrl),
                skipConfirm: skipConfirm,
                avoidUnnecessaryReload: avoidUnnecessaryReload,
                isComingFromAppIntent: isComingFromAppIntent
            )
        }
    }

    func openSelectingServer(
        from: OpenSource,
        urlString openUrlRaw: String,
        skipConfirm: Bool,
        queryParameters: [URLQueryItem]?,
        isComingFromAppIntent: Bool
    ) {
        let serverNameOrId = queryParameters?.first { $0.name == "server" }?.value
        let avoidUnnecessaryReload = queryParameters?
            .first { $0.name == "avoidUnnecessaryReload" }?.value
            .flatMap(Bool.init) ?? false
        let servers = Current.servers.all

        if let first = servers.first, servers.count == 1 || serverNameOrId != nil {
            let matched = servers.first {
                $0.info.name.lowercased() == serverNameOrId?.lowercased()
                    || $0.identifier.rawValue == serverNameOrId
            }
            let target = (serverNameOrId == nil || serverNameOrId == "default") ? first : (matched ?? first)
            open(
                from: from,
                server: target,
                urlString: openUrlRaw,
                skipConfirm: skipConfirm,
                avoidUnnecessaryReload: avoidUnnecessaryReload,
                isComingFromAppIntent: isComingFromAppIntent
            )
        } else if servers.count > 1 {
            selectServer(prompt: skipConfirm ? nil : from.message(with: openUrlRaw), includeSettings: false) {
                [weak self] server in
                self?.open(
                    from: from,
                    server: server,
                    urlString: openUrlRaw,
                    skipConfirm: true,
                    avoidUnnecessaryReload: avoidUnnecessaryReload,
                    isComingFromAppIntent: isComingFromAppIntent
                )
            }
        }
    }

    private func navigate(to url: URL, on server: Server, avoidUnnecessaryReload: Bool, isComingFromAppIntent: Bool) {
        open(server: server).done { frontend in
            frontend.dismissOverlayController(animated: true, completion: nil)
            if isComingFromAppIntent {
                frontend.openPanel(url)
            } else {
                frontend.open(inline: url, avoidUnnecessaryReload: avoidUnnecessaryReload)
            }
        }
    }

    private func open(
        from: OpenSource,
        server: Server,
        urlString openUrlRaw: String,
        webviewURL: URL?,
        externalURL: URL?,
        skipConfirm: Bool,
        avoidUnnecessaryReload: Bool,
        isComingFromAppIntent: Bool
    ) {
        guard webviewURL != nil || externalURL != nil else { return }

        let triggerOpen = { [weak self] in
            guard let self else { return }
            if let webviewURL {
                navigate(
                    to: webviewURL,
                    on: server,
                    avoidUnnecessaryReload: avoidUnnecessaryReload,
                    isComingFromAppIntent: isComingFromAppIntent
                )
            } else if let externalURL {
                openURLInBrowser(externalURL, presentedViewController)
            }
        }

        guard prefs.bool(forKey: "confirmBeforeOpeningUrl"), !skipConfirm else {
            triggerOpen()
            return
        }

        let alert = UIAlertController(
            title: L10n.Alerts.OpenUrlFromNotification.title,
            message: from.message(with: openUrlRaw),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: L10n.alwaysOpenLabel, style: .default) { _ in
            prefs.set(false, forKey: "confirmBeforeOpeningUrl")
            triggerOpen()
        })
        alert.addAction(UIAlertAction(title: L10n.openLabel, style: .default) { _ in triggerOpen() })
        present(alert)
    }
}
