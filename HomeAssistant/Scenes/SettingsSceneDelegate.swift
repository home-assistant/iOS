import Foundation
import UIKit

@objc class SettingsSceneDelegate: BasicSceneDelegate {
    override class func basicConfig() -> BasicSceneDelegate.BasicConfig {
        .init(
            title: L10n.Settings.NavigationBar.title,
            rootViewController: UINavigationController(rootViewController: SettingsViewController())
        )
    }
}
