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
    var webViewControllerPromise: Guarantee<WebViewController>

    private var webViewControllerSeal: (WebViewController) -> Void

    init(window: UIWindow) {
        self.window = window
        (self.webViewControllerPromise, self.webViewControllerSeal) = Guarantee<WebViewController>.pending()

        Current.authenticationControllerPresenter = { [weak self] controller in
            self?.present(controller)
        }

        Current.signInRequiredCallback = { [weak self] type in
            guard let self = self else { return }
            let controller = self.onboardingNavigationController()
            self.updateRootViewController(to: controller)

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
        }

        Current.onboardingComplete = { [weak self] in
            guard let self = self else { return }
            self.updateRootViewController(to: self.webViewNavigationController(rootViewController: WebViewController()))
        }
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
        if HomeAssistantAPI.authenticatedAPI() == nil {
            Current.Log.info("requiring onboarding due to no auth token")
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
                let webViewController = WebViewController()
                let navController = webViewNavigationController(rootViewController: webViewController)
                updateRootViewController(to: navController)
            }
        }
    }

    func present(_ viewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        window.rootViewController?.present(viewController, animated: animated, completion: completion)
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
