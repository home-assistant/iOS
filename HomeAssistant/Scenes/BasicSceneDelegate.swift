import Foundation
import UIKit

class BasicSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    struct BasicConfig {
        let title: String
        let rootViewController: UIViewController
    }

    class func basicConfig() -> BasicConfig {
        fatalError("must override")
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene else { return }

        let config = Self.basicConfig()

        scene.title = config.title
        scene.sizeRestrictions?.maximumSize.width = 800.0
        scene.sizeRestrictions?.minimumSize.width = 300.0

        let window = WindowController.window(scene: scene)
        window.rootViewController = config.rootViewController

        // never activate the settings scene for anything incoming
        scene.activationConditions.canActivateForTargetContentIdentifierPredicate = NSPredicate(value: false)

        if #available(macCatalyst 13, *), let titlebar = scene.titlebar {
            titlebar.titleVisibility = .hidden
            titlebar.toolbar = nil
        }

    }
}
