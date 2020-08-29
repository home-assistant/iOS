import Foundation
import UIKit

@available(iOS 13, *)
@objc class SettingsSceneDelegate: BasicSceneDelegate {
    override class func basicConfig() -> BasicSceneDelegate.BasicConfig {
        .init(
            title: L10n.Settings.NavigationBar.title,
            rootViewController: UINavigationController(rootViewController: SettingsViewController())
        )
    }
}
