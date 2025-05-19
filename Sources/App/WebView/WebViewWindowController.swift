import Foundation
import MBProgressHUD
import PromiseKit
import Shared
import SwiftUI
import UIKit

final class WebViewWindowController {
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
        let navigationController = UINavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        if let rootViewController {
            navigationController.viewControllers = [rootViewController]
        }
        return navigationController
    }

    func setup() {
        if let style = OnboardingNavigation.requiredOnboardingStyle {
            Current.Log.info("Showing onboarding \(style)")
            updateRootViewController(
                to: OnboardingNavigationView(onboardingStyle: style).embeddedInHostingController(),
                type: .onboarding
            )
        } else {
            if let webViewController = makeWebViewIfNotInCache(restorationType: .init(restorationActivity)) {
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

    func presentInvitation(url inviteURL: URL?) {
        guard let inviteURL else { return }

        switch rootViewControllerType {
        case .onboarding:
            Current.appSessionValues.inviteURL = inviteURL
        case .webView:
            webViewControllerPromise.done { controller in
                let navigationView = NavigationView {
                    OnboardingServersListView(prefillURL: inviteURL, shouldDismissOnSuccess: true)
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
        if let server = restorationType?.server ?? Current.servers.all.first {
            if let cachedController = cachedWebViewControllers[server.identifier] {
                return cachedController
            } else {
                let newController = WebViewController(
                    restoring: restorationType,
                    shouldLoadImmediately: shouldLoadImmediately
                )
                cachedWebViewControllers[server.identifier] = newController
                return newController
            }
        } else {
            return nil
        }
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

    func navigate(to url: URL, on server: Server, avoidUnecessaryReload: Bool = false, isOpenPageIntent: Bool) {
        open(server: server).done { webViewController in
            // Dismiss any overlayed controllers
            webViewController.dismissOverlayController(animated: true, completion: nil)
            if isOpenPageIntent {
                webViewController.openPanel(url)
            } else {
                webViewController.open(inline: url, avoidUnecessaryReload: avoidUnecessaryReload)
            }
        }
    }

    @discardableResult
    func open(server: Server) -> Guarantee<WebViewController> {
        webViewControllerPromise.then { [self] controller -> Guarantee<WebViewController> in
            guard controller.server != server else {
                return .value(controller)
            }

            let (promise, resolver) = Guarantee<WebViewController>.pending()

            let perform = { [self] in
                let newController: WebViewController = {
                    if let cachedController = cachedWebViewControllers[server.identifier] {
                        return cachedController
                    } else {
                        let newController = WebViewController(server: server)
                        cachedWebViewControllers[server.identifier] = newController
                        return newController
                    }
                }()

                updateRootViewController(
                    to: webViewNavigationController(rootViewController: newController),
                    type: .webView
                )
                resolver(newController)
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
        isOpenPageIntent: Bool
    ) {
        let serverNameOrId = queryParameters?.first(where: { $0.name == "server" })?.value
        let avoidUnecessaryReload = {
            if let avoidUnecessaryReloadString =
                queryParameters?.first(where: { $0.name == "avoidUnecessaryReload" })?.value {
                return Bool(avoidUnecessaryReloadString) ?? false
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
                    isOpenPageIntent: isOpenPageIntent
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
                        avoidUnecessaryReload: avoidUnecessaryReload,
                        isOpenPageIntent: isOpenPageIntent
                    )
                } else {
                    open(
                        from: from,
                        server: first,
                        urlString: openUrlRaw,
                        skipConfirm: skipConfirm,
                        avoidUnecessaryReload: avoidUnecessaryReload,
                        isOpenPageIntent: isOpenPageIntent
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
                    isOpenPageIntent: isOpenPageIntent
                )
            }
        }
    }

    func open(
        from: OpenSource,
        server: Server,
        urlString openUrlRaw: String,
        skipConfirm: Bool = false,
        avoidUnecessaryReload: Bool = false,
        isOpenPageIntent: Bool
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
            avoidUnecessaryReload: avoidUnecessaryReload,
            isOpenPageIntent: isOpenPageIntent
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
        avoidUnecessaryReload: Bool = false,
        isOpenPageIntent: Bool
    ) {
        guard webviewURL != nil || externalURL != nil else {
            return
        }

        let triggerOpen = { [self] in
            if let webviewURL {
                navigate(
                    to: webviewURL,
                    on: server,
                    avoidUnecessaryReload: avoidUnecessaryReload,
                    isOpenPageIntent: isOpenPageIntent
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
