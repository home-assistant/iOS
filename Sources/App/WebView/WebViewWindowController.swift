import Foundation
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

    private var webViewControllerSeal: (WebViewController) -> Void

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
        } else if webViewControllerPromise.isFulfilled {
            // replacing one, so set up a new promise if necessary
            (webViewControllerPromise, webViewControllerSeal) = Guarantee<WebViewController>.pending()
        }
    }

    var requiresOnboarding: Bool {
        return true

        if Current.settingsStore.tokenInfo == nil || Current.settingsStore.connectionInfo == nil {
            Current.Log.info("requiring onboarding due to auth token or connection info")
            return true
        }

        return false
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
        if requiresOnboarding {
            Current.Log.info("showing onboarding")
            updateRootViewController(to: OnboardingNavigationViewController(onboardingStyle: .initial))
        } else {
            if let rootController = window.rootViewController, !rootController.children.isEmpty {
                Current.Log.info("state restoration loaded controller, not creating a new one")
                // not changing anything, but handle the promises
                updateRootViewController(to: rootController)
            } else {
                Current.Log.info("state restoration didn't load anything, constructing controllers manually")
                let webViewController = WebViewController(restorationActivity: restorationActivity)
                let navController = webViewNavigationController(rootViewController: webViewController)
                updateRootViewController(to: navController)

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

    func navigate(to url: URL) {
        webViewControllerPromise.done { webViewController in
            webViewController.open(inline: url)
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

    func open(from: OpenSource, urlString openUrlRaw: String, skipConfirm: Bool = false) {
        let webviewURL = Current.settingsStore.connectionInfo?.webviewURL(from: openUrlRaw)
        let externalURL = URL(string: openUrlRaw)

        guard webviewURL != nil || externalURL != nil else {
            return
        }

        let triggerOpen = { [self] in
            if let webviewURL = webviewURL {
                navigate(to: webviewURL)
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
}

extension WebViewWindowController: OnboardingStateObserver {
    func onboardingStateDidChange(to state: OnboardingState) {
        switch state {
        case let .needed(type):
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
        case .complete:
            updateRootViewController(to: webViewNavigationController(rootViewController: WebViewController(
                restorationActivity: restorationActivity
            )))

            restorationActivity = nil
        }
    }
}
