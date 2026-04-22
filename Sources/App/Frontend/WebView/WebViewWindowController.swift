import Foundation
import MBProgressHUD
import PromiseKit
import Shared
import SwiftUI
import UIKit

/// Navigation controller that forwards status bar and home indicator preferences to its top view controller.
/// This is needed for kiosk mode to properly hide the status bar when WebViewController is embedded.
final class StatusBarForwardingNavigationController: UINavigationController {
    override var childForStatusBarHidden: UIViewController? {
        topViewController
    }

    override var childForStatusBarStyle: UIViewController? {
        topViewController
    }

    override var childForHomeIndicatorAutoHidden: UIViewController? {
        topViewController
    }
}

final class WebViewWindowController {
    enum RecoveryScreenConstants {
        static let minimumVisibleDuration: TimeInterval = 3
    }

    private enum RecoveredServerReauthenticationError: LocalizedError {
        case missingPresenter
        case cancelled

        var errorDescription: String? {
            switch self {
            case .missingPresenter:
                return L10n.Onboarding.ServerImport.Reauthenticate.errorsMissingPresenter
            case .cancelled:
                return L10n.Onboarding.ServerImport.Reauthenticate.errorsCancelled
            }
        }
    }

    enum RootViewControllerType {
        case onboarding
        case webView
    }

    let window: UIWindow
    var restorationActivity: NSUserActivity?

    var webViewControllerPromise: Guarantee<WebViewController>

    private var cachedWebViewControllers = [Identifier<Server>: WebViewController]()
    private var rootViewControllerType: RootViewControllerType?
    private var webViewControllerSeal: (WebViewController) -> Void
    private var onboardingPreloadWebViewController: WebViewController?

    init(window: UIWindow, restorationActivity: NSUserActivity?) {
        self.window = window
        self.restorationActivity = restorationActivity

        (self.webViewControllerPromise, self.webViewControllerSeal) = Guarantee<WebViewController>.pending()

        Current.onboardingObservation.register(observer: self)
    }

    func stateRestorationActivity() -> NSUserActivity? {
        webViewControllerPromise.value?.userActivity
    }

    private func updateRootViewController(to newValue: UIViewController, type: RootViewControllerType) {
        rootViewControllerType = type
        let newWebViewController = newValue.children.compactMap { $0 as? WebViewController }.first

        // must be before the seal fires, or it may request during deinit of an old one
        window.rootViewController = newValue

        if let newWebViewController {
            // any kind of ->webviewcontroller is the same, even if we are for some reason replacing an existing one
            if webViewControllerPromise.isFulfilled {
                webViewControllerPromise = .value(newWebViewController)
            } else {
                webViewControllerSeal(newWebViewController)
            }
        } else if webViewControllerPromise.isFulfilled {
            // replacing one, so set up a new promise if necessary
            (webViewControllerPromise, webViewControllerSeal) = Guarantee<WebViewController>.pending()
        }
    }

    private func webViewNavigationController(rootViewController: UIViewController? = nil) -> UINavigationController {
        let navigationController = StatusBarForwardingNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        if let rootViewController {
            navigationController.viewControllers = [rootViewController]
        }
        return navigationController
    }

    func setup() {
        let restorationType = WebViewRestorationType(restorationActivity)

        if shouldShowRecoveredServersImportScreen() {
            updateRootViewController(
                to: RecoveredServersImportView(onImport: {
                    _ = Current.servers.restoreKeychainFromMirrorIfNeeded()
                }).embeddedInHostingController(),
                type: .onboarding
            )
            DispatchQueue.main
                .asyncAfter(deadline: .now() + RecoveryScreenConstants.minimumVisibleDuration) { [weak self] in
                    self?.setup()
                }
            return
        }

        if let recoveredServer = nextRecoveredServerNeedingReauthentication(restorationType: restorationType) {
            showRecoveredServerReauthentication(for: recoveredServer)
            return
        }

        if let style = OnboardingNavigation.requiredOnboardingStyle {
            Current.Log.info("Showing onboarding \(style)")
            updateRootViewController(
                to: OnboardingNavigationView(onboardingStyle: style).embeddedInHostingController(),
                type: .onboarding
            )
        } else {
            if let webViewController = makeWebViewIfNotInCache(restorationType: restorationType) {
                updateRootViewController(
                    to: webViewNavigationController(rootViewController: webViewController),
                    type: .webView
                )
            } else {
                updateRootViewController(
                    to: OnboardingNavigationView(onboardingStyle: .initial).embeddedInHostingController(),
                    type: .onboarding
                )
            }
            restorationActivity = nil
        }
    }

    private func shouldShowRecoveredServersImportScreen() -> Bool {
        Current.servers.isMirrorRestorePending
    }

    private func nextRecoveredServerNeedingReauthentication(restorationType: WebViewRestorationType?) -> Server? {
        guard let server = preferredStartupServer(restorationType: restorationType),
              server.info.requiresReauthenticationAfterMirrorRestore else {
            return nil
        }

        return server
    }

    private func preferredStartupServer(restorationType: WebViewRestorationType?) -> Server? {
        if let restoredServer = restorationType?.server {
            return restoredServer
        }

        return Current.servers.all.first(where: { !$0.info.requiresReauthenticationAfterMirrorRestore })
            ?? Current.servers.all.first
    }

    private func showRecoveredServerReauthentication(for server: Server) {
        updateRootViewController(
            to: WebViewEmptyStateView(
                style: .recoveredServerNeedingReauthentication,
                server: server,
                availableReauthURLTypes: availableReauthURLTypes(for: server),
                settingsAction: { [weak self] in
                    self?.showSettingsViewController()
                },
                recoveredServerReauthAction: { [weak self] urlType, completion in
                    self?.performRecoveredServerReauthentication(
                        for: server,
                        using: urlType,
                        completion: completion
                    )
                }, serverSelectionAction: { [weak self] selectedServer in
                    self?.handleRecoveredServerSelection(selectedServer)
                }
            ).embeddedInHostingController(),
            type: .onboarding
        )
    }

    private func handleRecoveredServerSelection(_ server: Server) {
        if server.info.requiresReauthenticationAfterMirrorRestore {
            showRecoveredServerReauthentication(for: server)
        } else {
            _ = open(server: server)
        }
    }

    private func performRecoveredServerReauthentication(
        for server: Server,
        using urlType: ConnectionInfo.URLType,
        completion: @escaping (Swift.Result<Void, Error>) -> Void
    ) {
        let connectionInfo = server.info.connection

        guard let baseURL = connectionInfo.address(for: urlType) else {
            completion(.failure(ServerConnectionError.noActiveURL(server.info.name)))
            return
        }

        guard let presenter = window.rootViewController else {
            completion(.failure(RecoveredServerReauthenticationError.missingPresenter))
            return
        }

        do {
            let authDetails = try OnboardingAuthDetails(baseURL: baseURL)
            authDetails.exceptions = connectionInfo.securityExceptions
            authDetails.clientCertificate = connectionInfo.clientCertificate

            let login = OnboardingAuthLoginImpl()

            firstly {
                login.open(authDetails: authDetails, sender: presenter)
            }.then { code -> Promise<TokenInfo> in
                AuthenticationAPI.fetchToken(
                    authorizationCode: code,
                    baseURL: baseURL,
                    exceptions: authDetails.exceptions,
                    clientCertificate: authDetails.clientCertificate
                )
            }.done { [weak self] tokenInfo in
                server.update { serverInfo in
                    serverInfo.token = tokenInfo
                }

                if self?.onboardingPreloadWebViewController?.server.identifier == server.identifier {
                    self?.onboardingPreloadWebViewController = nil
                }
                self?.cachedWebViewControllers[server.identifier] = nil

                completion(.success(()))
                _ = self?.open(server: server)
            }.catch { error in
                if let pmkError = error as? PMKError, pmkError.isCancelled {
                    completion(.failure(RecoveredServerReauthenticationError.cancelled))
                    return
                }

                Current.Log.error("Recovered server re-authentication failed: \(error)")
                completion(.failure(error))
            }
        } catch {
            Current.Log.error("Failed to create auth details for recovered server re-authentication: \(error)")
            completion(.failure(error))
        }
    }

    private func showSettingsViewController() {
        if Current.sceneManager.supportsMultipleScenes, Current.isCatalyst {
            Current.sceneManager.activateAnyScene(for: .settings)
        } else {
            let settingsView = SettingsView().embeddedInHostingController()
            window.rootViewController?.present(settingsView, animated: true)
        }
    }

    func presentInvitation(url inviteURL: URL?) {
        guard let inviteURL else { return }

        switch rootViewControllerType {
        case .onboarding:
            Current.appSessionValues.inviteURL = inviteURL
        case .webView:
            webViewControllerPromise.done { controller in
                let navigationView = NavigationView {
                    OnboardingServersListView(
                        prefillURL: inviteURL,
                        shouldDismissOnSuccess: true,
                        onboardingStyle: .secondary
                    )
                }.navigationViewStyle(.stack)
                controller.presentOverlayController(
                    controller: navigationView.embeddedInHostingController(),
                    animated: true
                )
            }
        case nil:
            Current.Log.error("No root view controller type set, presentInvitation failed")
            return
        }
    }

    private func makeWebViewIfNotInCache(
        restorationType: WebViewRestorationType?,
        shouldLoadImmediately: Bool = false
    ) -> WebViewController? {
        if let server = preferredStartupServer(restorationType: restorationType) {
            let effectiveRestorationType: WebViewRestorationType? = if restorationType?.server?.identifier == server
                .identifier {
                restorationType
            } else {
                .server(server)
            }

            if let cachedController = cachedWebViewControllers[server.identifier] {
                return cachedController
            } else {
                let newController = WebViewController(
                    restoring: effectiveRestorationType,
                    shouldLoadImmediately: shouldLoadImmediately
                )
                cachedWebViewControllers[server.identifier] = newController
                return newController
            }
        } else {
            return nil
        }
    }

    private func availableReauthURLTypes(for server: Server) -> [ConnectionInfo.URLType] {
        let preferenceOrder: [ConnectionInfo.URLType] = [.remoteUI, .external, .internal]
        return preferenceOrder.filter { server.info.connection.address(for: $0) != nil }
    }

    func present(_ viewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        presentedViewController?.present(viewController, animated: animated, completion: completion)
    }

    func show(alert: ServerAlert) {
        webViewControllerPromise.done { webViewController in
            webViewController.show(alert: alert)
        }
    }

    var presentedViewController: UIViewController? {
        var currentController = window.rootViewController
        while let controller = currentController?.presentedViewController {
            currentController = controller
        }
        return currentController
    }

    func navigate(to url: URL, on server: Server, avoidUnnecessaryReload: Bool = false, isComingFromAppIntent: Bool) {
        open(server: server).pipe { result in
            switch result {
            case let .fulfilled(webViewController):
                webViewController.dismissOverlayController(animated: true, completion: nil)
                if isComingFromAppIntent {
                    webViewController.openPanel(url)
                } else {
                    webViewController.open(inline: url, avoidUnnecessaryReload: avoidUnnecessaryReload)
                }
            case .rejected:
                Current.Log.error("Failed to open WebViewController for server \(server.identifier)")
            }
        }
    }

    @discardableResult
    func open(server: Server) -> Guarantee<WebViewController> {
        let makeController = { [self] in
            if let cachedController = cachedWebViewControllers[server.identifier] {
                return cachedController
            } else {
                let newController = WebViewController(server: server)
                cachedWebViewControllers[server.identifier] = newController
                return newController
            }
        }

        let openController = { [self] (controller: WebViewController) -> Guarantee<WebViewController> in
            let (promise, resolver) = Guarantee<WebViewController>.pending()

            let perform = { [self] in
                updateRootViewController(
                    to: webViewNavigationController(rootViewController: controller),
                    type: .webView
                )
                resolver(controller)
            }

            if let rootViewController = window.rootViewController, rootViewController.presentedViewController != nil {
                rootViewController.dismiss(animated: true, completion: {
                    perform()
                })
            } else {
                perform()
            }

            return promise
        }

        guard rootViewControllerType == .webView, webViewControllerPromise.isFulfilled else {
            return openController(makeController())
        }

        return webViewControllerPromise.then { controller -> Guarantee<WebViewController> in
            guard controller.server != server else {
                return .value(controller)
            }

            return openController(makeController())
        }
    }

    enum OpenSource {
        case notification
        case deeplink

        func message(with urlString: String) -> String {
            switch self {
            case .notification: return L10n.Alerts.OpenUrlFromNotification.message(urlString)
            case .deeplink: return L10n.Alerts.OpenUrlFromDeepLink.message(urlString)
            }
        }
    }

    func selectServer(prompt: String? = nil, includeSettings: Bool = false, completion: @escaping (Server) -> Void) {
        let serverSelectView = UIHostingController(rootView: ServerSelectView(
            prompt: prompt,
            includeSettings: includeSettings,
            selectAction: completion
        ))
        serverSelectView.view.backgroundColor = .clear
        serverSelectView.modalPresentationStyle = .overFullScreen
        serverSelectView.modalTransitionStyle = .crossDissolve
        present(serverSelectView, animated: false, completion: nil)
    }

    func openSelectingServer(
        from: OpenSource,
        urlString openUrlRaw: String,
        skipConfirm: Bool = false,
        queryParameters: [URLQueryItem]? = nil,
        isComingFromAppIntent: Bool
    ) {
        let serverNameOrId = queryParameters?.first(where: { $0.name == "server" })?.value
        let avoidUnnecessaryReload = {
            if let avoidUnnecessaryReloadString =
                queryParameters?.first(where: { $0.name == "avoidUnnecessaryReload" })?.value {
                return Bool(avoidUnnecessaryReloadString) ?? false
            } else {
                return false
            }
        }()
        let servers = Current.servers.all

        if let first = servers.first, Current.servers.all.count == 1 || serverNameOrId != nil {
            if serverNameOrId == "default" || serverNameOrId == nil {
                open(
                    from: from,
                    server: first,
                    urlString: openUrlRaw,
                    skipConfirm: skipConfirm,
                    isComingFromAppIntent: isComingFromAppIntent
                )
            } else {
                if let selectedServer = servers.first(where: { server in
                    server.info.name.lowercased() == serverNameOrId?.lowercased() ||
                        server.identifier.rawValue == serverNameOrId
                }) {
                    open(
                        from: from,
                        server: selectedServer,
                        urlString: openUrlRaw,
                        skipConfirm: skipConfirm,
                        avoidUnnecessaryReload: avoidUnnecessaryReload,
                        isComingFromAppIntent: isComingFromAppIntent
                    )
                } else {
                    open(
                        from: from,
                        server: first,
                        urlString: openUrlRaw,
                        skipConfirm: skipConfirm,
                        avoidUnnecessaryReload: avoidUnnecessaryReload,
                        isComingFromAppIntent: isComingFromAppIntent
                    )
                }
            }
        } else if Current.servers.all.count > 1 {
            let prompt: String?

            if skipConfirm {
                prompt = nil
            } else {
                prompt = from.message(with: openUrlRaw)
            }

            selectServer(prompt: prompt) { [self] server in
                open(
                    from: from,
                    server: server,
                    urlString: openUrlRaw,
                    skipConfirm: true,
                    isComingFromAppIntent: isComingFromAppIntent
                )
            }
        }
    }

    func open(
        from: OpenSource,
        server: Server,
        urlString openUrlRaw: String,
        skipConfirm: Bool = false,
        avoidUnnecessaryReload: Bool = false,
        isComingFromAppIntent: Bool
    ) {
        let webviewURL = server.info.connection.webviewURL(from: openUrlRaw)
        let externalURL = URL(string: openUrlRaw)

        open(
            from: from,
            server: server,
            urlString: openUrlRaw,
            webviewURL: webviewURL,
            externalURL: externalURL,
            skipConfirm: skipConfirm,
            avoidUnnecessaryReload: avoidUnnecessaryReload,
            isComingFromAppIntent: isComingFromAppIntent
        )
    }

    func clearCachedControllers() {
        cachedWebViewControllers = [:]
    }

    private func open(
        from: OpenSource,
        server: Server,
        urlString openUrlRaw: String,
        webviewURL: URL?,
        externalURL: URL?,
        skipConfirm: Bool,
        avoidUnnecessaryReload: Bool = false,
        isComingFromAppIntent: Bool
    ) {
        guard webviewURL != nil || externalURL != nil else {
            return
        }

        let triggerOpen = { [self] in
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

        if prefs.bool(forKey: "confirmBeforeOpeningUrl"), !skipConfirm {
            let alert = UIAlertController(
                title: L10n.Alerts.OpenUrlFromNotification.title,
                message: from.message(with: openUrlRaw),
                preferredStyle: UIAlertController.Style.alert
            )

            alert.addAction(UIAlertAction(
                title: L10n.cancelLabel,
                style: .cancel,
                handler: nil
            ))

            alert.addAction(UIAlertAction(
                title: L10n.alwaysOpenLabel,
                style: .default,
                handler: { _ in
                    prefs.set(false, forKey: "confirmBeforeOpeningUrl")
                    triggerOpen()
                }
            ))

            alert.addAction(UIAlertAction(
                title: L10n.openLabel,
                style: .default
            ) { _ in
                triggerOpen()
            })

            present(alert)
        } else {
            triggerOpen()
        }
    }
}

extension WebViewWindowController: OnboardingStateObserver {
    func onboardingStateDidChange(to state: OnboardingState) {
        switch state {
        case let .needed(type):
            if window.rootViewController as? UIHostingController<OnboardingNavigationView> != nil {
                return
            }

            onboardingPreloadWebViewController = nil
            // Remove cached webview for servers that don't exist anymore
            cachedWebViewControllers = cachedWebViewControllers.filter({ serverIdentifier, _ in
                Current.servers.all.contains(where: { $0.identifier == serverIdentifier })
            })

            switch type {
            case .error, .logout:
                if Current.servers.all.isEmpty {
                    let controller = OnboardingNavigationView(onboardingStyle: .initial).embeddedInHostingController()
                    updateRootViewController(to: controller, type: .onboarding)

                    if type.shouldShowError {
                        let alert = UIAlertController(
                            title: L10n.Alerts.AuthRequired.title,
                            message: L10n.Alerts.AuthRequired.message,
                            preferredStyle: .alert
                        )

                        alert.addAction(UIAlertAction(
                            title: L10n.okLabel,
                            style: .default,
                            handler: nil
                        ))

                        controller.present(alert, animated: true, completion: nil)
                    }
                } else if let existingServer = webViewControllerPromise.value?.server,
                          !Current.servers.all.contains(existingServer),
                          let newServer = Current.servers.all.first {
                    open(server: newServer)
                }
            case let .unauthenticated(serverId, code):
                Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                    .done { controller in
                        controller.showReAuthPopup(serverId: serverId, code: code)
                    }
            }
        case .didConnect:
            onboardingPreloadWebViewController = makeWebViewIfNotInCache(
                restorationType: .init(restorationActivity),
                shouldLoadImmediately: true
            )
        case .complete:
            if window.rootViewController as? UIHostingController<OnboardingNavigationView> != nil {
                let controller: WebViewController?

                if let preload = onboardingPreloadWebViewController {
                    controller = preload
                } else {
                    controller = makeWebViewIfNotInCache(
                        restorationType: .init(restorationActivity),
                        shouldLoadImmediately: true
                    )
                    restorationActivity = nil
                }

                if let controller {
                    updateRootViewController(
                        to: webViewNavigationController(rootViewController: controller),
                        type: .webView
                    )
                }
            }
        }
    }
}
