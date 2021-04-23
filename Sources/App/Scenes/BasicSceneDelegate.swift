import Foundation
import Shared
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

        with(scene.sizeRestrictions) {
            if #available(iOS 14, *), scene.traitCollection.userInterfaceIdiom == .mac {
                $0?.maximumSize = CGSize(width: 600.0, height: 600.0)
                $0?.minimumSize = CGSize(width: 200.0, height: 200.0)
            } else {
                $0?.maximumSize.width = 800.0
                $0?.minimumSize.width = 300.0
            }
        }

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
