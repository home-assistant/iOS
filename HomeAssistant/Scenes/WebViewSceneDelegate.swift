import Foundation
import UIKit
import PromiseKit

@available(iOS 13, *)
final class WebViewSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?
    var windowController: WebViewWindowController?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene else { return }

        let window = WebViewWindowController.window(scene: scene)
        let windowController = WebViewWindowController(window: window)
        self.window = window
        self.windowController = windowController

        windowController.setup()

        #if targetEnvironment(macCatalyst)
        if let titlebar = scene.titlebar {
            // disabling this also disables the "show tab bar" window tab bar (aka not uitabbar)
            titlebar.titleVisibility = .hidden
            titlebar.toolbar = nil
        }
        #endif

        informManager(from: connectionOptions)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        windowController = nil
        window = nil
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {

    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        nil
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        print("continue user activity \(userActivity)")
    }
}
