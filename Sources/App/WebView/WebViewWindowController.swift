import Foundation
import MBProgressHUD
import PromiseKit
import Shared
import UIKit

@available(iOS, deprecated: 13.0)
enum StateRestorationKey: String {
    case mainWindow
    case webViewNavigationController
}

class WebViewWindowController {
    let window: UIWindow
    var restorationActivity: NSUserActivity?

    var webViewControllerPromise: Guarantee<WebViewController>

    private var cachedWebViewControllers = [Identifier<Server>: WebViewController]()

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

    private func updateRootViewController(to newValue: UIViewController) {
        let newWebViewController = newValue.children.compactMap { $0 as? WebViewController }.first

        // must be before the seal fires, or it may request during deinit of an old one
        window.rootViewController = newValue

        if let newWebViewController = newWebViewController {
            // any kind of ->webviewcontroller is the same, even if we are for some reason replacing an existing one
            if webViewControllerPromise.isFulfilled {
                webViewControllerPromise = .value(newWebViewController)
            } else {
                webViewControllerSeal(newWebViewController)
            }

            update(webViewController: newWebViewController)
        } else if webViewControllerPromise.isFulfilled {
            // replacing one, so set up a new promise if necessary
            (webViewControllerPromise, webViewControllerSeal) = Guarantee<WebViewController>.pending()
        }
    }

    private func webViewNavigationController(rootViewController: UIViewController? = nil) -> UINavigationController {
        let navigationController = UINavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        if #available(iOS 13, *) {
        } else {
            navigationController.restorationIdentifier = StateRestorationKey.webViewNavigationController.rawValue
        }

        if let rootViewController = rootViewController {
            navigationController.viewControllers = [rootViewController]
        }
        return navigationController
    }

    func setup() {
        if let style = OnboardingNavigationViewController.requiredOnboardingStyle {
            Current.Log.info("showing onboarding \(style)")
            updateRootViewController(to: OnboardingNavigationViewController(onboardingStyle: style))
        } else {
            if let rootController = window.rootViewController, !rootController.children.isEmpty {
                Current.Log.info("[iOS 12] state restoration loaded controller, not creating a new one")
                // not changing anything, but handle the promises
                updateRootViewController(to: rootController)
            } else {
                if let webViewController = WebViewController(restoring: .init(restorationActivity)) {
                    updateRootViewController(to: webViewNavigationController(rootViewController: webViewController))
                } else {
                    updateRootViewController(to: OnboardingNavigationViewController(onboardingStyle: .initial))
                }
                restorationActivity = nil
            }
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

    @available(iOS, deprecated: 13.0)
    func viewController(
        withRestorationIdentifierPath identifierComponents: [String]
    ) -> UIViewController? {
        // iOS 12 and below state restoration code path only
        if identifierComponents == [StateRestorationKey.webViewNavigationController.rawValue] {
            let navigationController = webViewNavigationController()
            window.rootViewController = navigationController
            return navigationController
        } else {
            return nil
        }
    }

    func navigate(to url: URL, on server: Server) {
        open(server: server).done { webViewController in
            webViewController.open(inline: url)
        }
    }

    @discardableResult
    func open(server: Server) -> Guarantee<WebViewController> {
        webViewControllerPromise.then { [self] controller -> Guarantee<WebViewController> in
            guard controller.server != server else {
                return .value(controller)
            }

            cachedWebViewControllers[controller.server.identifier] = controller

            let (promise, resolver) = Guarantee<WebViewController>.pending()

            let perform = { [self] in
                let newController = cachedWebViewControllers[server.identifier] ?? WebViewController(server: server)
                updateRootViewController(to: webViewNavigationController(rootViewController: newController))
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

    private func selectServer(prompt: String? = nil, includeSettings: Bool = false) -> Promise<Server?> {
        let select = ServerSelectViewController()
        if let prompt = prompt {
            select.prompt = prompt
        }
        if includeSettings {
            select.navigationItem.rightBarButtonItems = [
                with(UIBarButtonItem(icon: .cogIcon, target: self, action: #selector(openSettings(_:)))) {
                    $0.accessibilityLabel = L10n.Settings.NavigationBar.title
                },
            ]
        }
        let promise = select.result.ensureThen { [weak select] in
            Guarantee { seal in
                if let select = select, select.presentingViewController != nil {
                    select.dismiss(animated: true, completion: {
                        seal(())
                    })
                } else {
                    seal(())
                }
            }
        }
        present(UINavigationController(rootViewController: select))
        return promise.map {
            if case let .server(server) = $0 {
                return server
            } else {
                return nil
            }
        }
    }

    func openSelectingServer(
        from: OpenSource,
        urlString openUrlRaw: String,
        skipConfirm: Bool = false,
        queryParameters: [URLQueryItem]? = nil
    ) {
        let serverName = queryParameters?.first(where: { $0.name == "server" })?.value
        let servers = Current.servers.all

        if let first = servers.first, Current.servers.all.count == 1 || serverName != nil {
            if serverName == "default" || serverName == nil {
                open(from: from, server: first, urlString: openUrlRaw, skipConfirm: skipConfirm)
            } else {
                if let selectedServer = servers.first(where: { server in
                    server.info.name.lowercased() == serverName?.lowercased()
                }) {
                    open(from: from, server: selectedServer, urlString: openUrlRaw, skipConfirm: skipConfirm)
                } else {
                    open(from: from, server: first, urlString: openUrlRaw, skipConfirm: skipConfirm)
                }
            }
        } else if Current.servers.all.count > 1 {
            let prompt: String?

            if skipConfirm {
                prompt = nil
            } else {
                prompt = from.message(with: openUrlRaw)
            }

            selectServer(prompt: prompt).done { [self] server in
                if let server = server {
                    open(from: from, server: server, urlString: openUrlRaw, skipConfirm: true)
                }
            }.catch { error in
                Current.Log.error("failed to select server: \(error)")
            }
        }
    }

    func open(from: OpenSource, server: Server, urlString openUrlRaw: String, skipConfirm: Bool = false) {
        let webviewURL = server.info.connection.webviewURL(from: openUrlRaw)
        let externalURL = URL(string: openUrlRaw)

        open(
            from: from,
            server: server,
            urlString: openUrlRaw,
            webviewURL: webviewURL,
            externalURL: externalURL,
            skipConfirm: skipConfirm
        )
    }

    private func open(
        from: OpenSource,
        server: Server,
        urlString openUrlRaw: String,
        webviewURL: URL?,
        externalURL: URL?,
        skipConfirm: Bool
    ) {
        guard webviewURL != nil || externalURL != nil else {
            return
        }

        let triggerOpen = { [self] in
            if let webviewURL = webviewURL {
                navigate(to: webviewURL, on: server)
            } else if let externalURL = externalURL {
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

    private lazy var serverChangeGestures: [UIGestureRecognizer] = {
        class InlineDelegate: NSObject, UIGestureRecognizerDelegate {
            func gestureRecognizer(
                _ gestureRecognizer: UIGestureRecognizer,
                shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
            ) -> Bool {
                if let gestureRecognizer = gestureRecognizer as? UISwipeGestureRecognizer {
                    return gestureRecognizer.direction == .up
                } else {
                    return false
                }
            }
        }

        var delegate = InlineDelegate()

        return [.left, .right, .up].map { (direction: UISwipeGestureRecognizer.Direction) in
            with(UISwipeGestureRecognizer()) {
                $0.numberOfTouchesRequired = 3
                $0.direction = direction
                $0.addTarget(self, action: #selector(serverChangeGestureDidChange(_:)))
                $0.delegate = delegate

                after(life: $0).done {
                    withExtendedLifetime(delegate) {
                        //
                    }
                }
            }
        }
    }()

    private func update(webViewController: WebViewController) {
        for gesture in serverChangeGestures {
            webViewController.view.addGestureRecognizer(gesture)
        }
    }

    @objc private func openSettings(_ sender: UIBarButtonItem) {
        presentedViewController?.dismiss(animated: true, completion: { [self] in
            webViewControllerPromise.done { controller in
                controller.showSettingsViewController()
            }
        })
    }

    @objc private func serverChangeGestureDidChange(_ gesture: UISwipeGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }

        if gesture.direction == .up {
            with(webViewControllerPromise.value?.webView.scrollView.panGestureRecognizer) {
                $0?.isEnabled = false
                $0?.isEnabled = true
            }

            selectServer(includeSettings: true).done { [self] server in
                if let server = server {
                    open(server: server)
                }
            }.catch { error in
                Current.Log.error("failed to select server: \(error)")
            }
            return
        }

        let servers = Current.servers.all

        guard servers.count > 1,
              let current = webViewControllerPromise.value?.server,
              let startIndex = servers.firstIndex(of: current) else {
            return
        }

        // swiping "right" visually goes left, which is down in index
        let nextIndex = gesture.direction == .right ? startIndex - 1 : startIndex + 1

        let server: Server

        if nextIndex < servers.startIndex {
            server = servers[servers.endIndex - 1]
        } else if nextIndex >= servers.endIndex {
            server = servers[servers.startIndex]
        } else {
            server = servers[nextIndex]
        }

        open(server: server).done { controller in
            let hud = MBProgressHUD.showAdded(to: controller.view, animated: true)
            hud.isUserInteractionEnabled = false
            hud.mode = .text
            hud.label.text = server.info.name
            hud.hide(animated: true, afterDelay: 1.0)
        }
    }
}

extension WebViewWindowController: OnboardingStateObserver {
    func onboardingStateDidChange(to state: OnboardingState) {
        switch state {
        case let .needed(type):
            guard !(window.rootViewController is OnboardingNavigationViewController) else {
                return
            }

            cachedWebViewControllers.removeAll()

            if Current.servers.all.isEmpty {
                let controller = OnboardingNavigationViewController(onboardingStyle: .initial)
                updateRootViewController(to: controller)

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
        case .didConnect:
            onboardingPreloadWebViewController = WebViewController(
                restoring: .init(restorationActivity),
                shouldLoadImmediately: true
            )
        case .complete:
            if window.rootViewController is OnboardingNavigationViewController {
                let controller: WebViewController?

                if let preload = onboardingPreloadWebViewController {
                    controller = preload
                } else {
                    controller = WebViewController(
                        restoring: .init(restorationActivity),
                        shouldLoadImmediately: true
                    )
                    restorationActivity = nil
                }

                if let controller = controller {
                    updateRootViewController(to: webViewNavigationController(rootViewController: controller))
                }
            }
        }
    }
}
