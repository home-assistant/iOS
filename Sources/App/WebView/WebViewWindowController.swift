import Foundation
import UIKit
import Shared
import PromiseKit

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
            (self.webViewControllerPromise, self.webViewControllerSeal) = Guarantee<WebViewController>.pending()
        }
    }

    var requiresOnboarding: Bool {
        if Current.settingsStore.tokenInfo == nil || Current.settingsStore.connectionInfo == nil {
            Current.Log.info("requiring onboarding due to auth token or connection info")
            return true
        }

        return false
    }

    private func onboardingNavigationController() -> UINavigationController {
        return StoryboardScene.Onboarding.navController.instantiate()
    }

    private func webViewNavigationController(rootViewController: UIViewController? = nil) -> UINavigationController {
        let navigationController = UINavigationController()

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
            updateRootViewController(to: onboardingNavigationController())
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
        window.rootViewController?.present(viewController, animated: animated, completion: completion)
    }

    func show(alert: ServerAlert) {
        webViewControllerPromise.done { webViewController in
            webViewController.show(alert: alert)
        }
    }

    var presentingViewController: UIViewController? {
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

    func open(urlString openUrlRaw: String) {
        if let webviewURL = Current.settingsStore.connectionInfo?.webviewURL(from: openUrlRaw) {
            navigate(to: webviewURL)
            return
        }

        guard let url = URL(string: openUrlRaw) else {
            return
        }

        let triggerOpen = {
            openURLInBrowser(url, self.presentingViewController)
        }

        if prefs.bool(forKey: "confirmBeforeOpeningUrl") {
            let alert = UIAlertController(
                title: L10n.Alerts.OpenUrlFromNotification.title,
                message: L10n.Alerts.OpenUrlFromNotification.message(openUrlRaw),
                preferredStyle: UIAlertController.Style.alert
            )

            alert.addAction(UIAlertAction(
                title: L10n.cancelLabel,
                style: .cancel,
                handler: nil
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
        case .needed(let type):
            let controller = onboardingNavigationController()
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
