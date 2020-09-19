import Foundation
import UIKit
import Shared

@available(iOS 13, *)
@objc class SettingsSceneDelegate: BasicSceneDelegate {
    override class func basicConfig() -> BasicSceneDelegate.BasicConfig {
        .init(
            title: L10n.Settings.NavigationBar.title,
            rootViewController: UINavigationController(rootViewController: SettingsViewController())
        )
    }

    func pushDetail(group: String, animated: Bool) {
        guard let navigationController = window?.rootViewController as? UINavigationController else {
            return
        }

        navigationController.pushViewController(
            with(SettingsDetailViewController()) {
                $0.detailGroup = group
            },
            animated: animated
        )
    }
}
