import Foundation
import UIKit
import Shared
import PromiseKit

enum StateRestorationKey: String {
    case mainWindow
    case webViewNavigationController
}

class WindowController {
    let window: UIWindow
    var webViewControllerPromise: Guarantee<WebViewController>

    private var webViewControllerSeal: (WebViewController) -> Void

    @available(iOS 13, *)
    static func window(scene: UIWindowScene) -> UIWindow {
        return with(UIWindow(windowScene: scene)) {
            $0.tintColor = Constants.tintColor
            $0.makeKeyAndVisible()
        }
    }

    static func window(preiOS12: ()) -> UIWindow {
        return with(UIWindow(frame: UIScreen.main.bounds)) {
            $0.tintColor = Constants.tintColor
            $0.restorationIdentifier = StateRestorationKey.mainWindow.rawValue
            $0.makeKeyAndVisible()
        }
    }

    init(window: UIWindow) {
        self.window = window
        (self.webViewControllerPromise, self.webViewControllerSeal) = Guarantee<WebViewController>.pending()

        Current.authenticationControllerPresenter = { [window] controller in
            var presenter: UIViewController? = window.rootViewController

            while let next = presenter?.presentedViewController {
                presenter = next
            }

            presenter?.present(controller, animated: true, completion: nil)
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
        navigationController.restorationIdentifier = StateRestorationKey.webViewNavigationController.rawValue
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

    func viewController(
        withRestorationIdentifierPath identifierComponents: [String]
    ) -> UIViewController? {
        if identifierComponents == [StateRestorationKey.webViewNavigationController.rawValue] {
            let navigationController = webViewNavigationController()
            window.rootViewController = navigationController
            return navigationController
        } else {
            return nil
        }
    }
}
