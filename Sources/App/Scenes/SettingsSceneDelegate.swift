import Eureka
import Foundation
import Shared
import SwiftUI
import UIKit

@objc class SettingsSceneDelegate: BasicSceneDelegate {
    private var navigationController: UINavigationController? {
        didSet {
            if let navigationController {
                navigationController.delegate = self
                update(navigationController: navigationController)
            }
        }
    }

    override func basicConfig(in traitCollection: UITraitCollection) -> BasicSceneDelegate.BasicConfig {
        .init(
            title: L10n.Settings.NavigationBar.title,
            rootViewController: {
                if traitCollection.userInterfaceIdiom == .mac {
                    #if targetEnvironment(macCatalyst)
                    // On macOS, use SwiftUI with split view
                    return SettingsView().embeddedInHostingController()
                    #else
                    return UINavigationController(rootViewController: SettingsViewController())
                    #endif
                } else {
                    return UINavigationController(rootViewController: SettingsViewController())
                }
            }()
        )
    }

    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)

        guard let scene = scene as? UIWindowScene else { return }

        #if targetEnvironment(macCatalyst)
        if let titlebar = scene.titlebar {
            if scene.traitCollection.userInterfaceIdiom == .mac {
                // SwiftUI view handles its own navigation, no toolbar needed
                titlebar.titleVisibility = .visible
            } else {
                // iOS on Catalyst
                if let navigationController = window?.rootViewController as? UINavigationController {
                    self.navigationController = navigationController
                }
                titlebar.titleVisibility = .hidden
            }
        }
        #else
        if let navigationController = window?.rootViewController as? UINavigationController {
            self.navigationController = navigationController
        }
        #endif
    }

    func pushActions(animated: Bool) {
        #if targetEnvironment(macCatalyst)
        if window?.traitCollection.userInterfaceIdiom == .mac {
            // macOS uses SwiftUI, navigation is handled within the SwiftUI view
            // No action needed here
            return
        }
        #endif
        
        navigationController?.pushViewController(
            with(SettingsDetailViewController()) {
                $0.detailGroup = .actions
            },
            animated: animated
        )
    }
}

extension SettingsSceneDelegate: UINavigationControllerDelegate {
    private func update(navigationController: UINavigationController) {
        if navigationController.traitCollection.userInterfaceIdiom == .mac {
            let shouldBeHidden = navigationController.viewControllers.count <= 1

            if #available(iOS 16, *) {
                navigationController.navigationBar.preferredBehavioralStyle = .pad
            }

            if navigationController.isNavigationBarHidden != shouldBeHidden {
                navigationController.setNavigationBarHidden(shouldBeHidden, animated: true)
            }
        }
    }

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        update(navigationController: navigationController)
        navigationController.transitionCoordinator?.animate(
            alongsideTransition: nil,
            completion: { [weak self] context in
                if context.isCancelled {
                    self?.update(navigationController: navigationController)
                }
            }
        )
    }
}

// NSToolbar delegate methods removed - macOS now uses SwiftUI NavigationSplitView
