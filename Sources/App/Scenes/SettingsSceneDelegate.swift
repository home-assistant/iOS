import Foundation
import Shared
import SwiftUI
import UIKit

@objc class SettingsSceneDelegate: BasicSceneDelegate {
    override func basicConfig(in traitCollection: UITraitCollection) -> BasicSceneDelegate.BasicConfig {
        .init(
            title: L10n.Settings.NavigationBar.title,
            rootViewController: // Use SwiftUI SettingsView for all platforms
            // macOS will show split view, iOS will show list view
            SettingsView().embeddedInHostingController()
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
            // SwiftUI view handles its own navigation
            titlebar.titleVisibility = scene.traitCollection.userInterfaceIdiom == .mac ? .visible : .hidden
        }
        #endif
    }
}
