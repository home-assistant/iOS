import Foundation
import UIKit

@available(iOS 13, *)
class WebViewSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?
    var windowController: WindowController?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene else { return }

        let window = WindowController.window(scene: scene)
        let windowController = WindowController(window: window)
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
    }
}
