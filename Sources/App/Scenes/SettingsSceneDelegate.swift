import Foundation
import Shared
import UIKit

@available(iOS 13, *)
@objc class SettingsSceneDelegate: BasicSceneDelegate {
    override func basicConfig(in traitCollection: UITraitCollection) -> BasicSceneDelegate.BasicConfig {
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
