import Foundation
import UIKit

@available(iOS 13, *)
class BasicSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    struct BasicConfig {
        var title: String
        var rootViewController: UIViewController
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

        // never activate these basic scenes scene for anything incoming
        scene.activationConditions.canActivateForTargetContentIdentifierPredicate = NSPredicate(value: false)

        let window = UIWindow(haScene: scene)
        window.rootViewController = config.rootViewController
        self.window = window

        #if targetEnvironment(macCatalyst)
        if let titlebar = scene.titlebar {
            titlebar.titleVisibility = .hidden
            titlebar.toolbar = nil
        }
        #endif

        informManager(from: connectionOptions)
    }
}
