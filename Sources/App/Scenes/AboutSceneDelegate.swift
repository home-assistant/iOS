import Foundation
import Shared
import UIKit

@objc class AboutSceneDelegate: BasicSceneDelegate {
    override func basicConfig(in traitCollection: UITraitCollection) -> BasicSceneDelegate.BasicConfig {
        .init(
            title: L10n.About.title,
            rootViewController: UINavigationController(rootViewController: AboutViewController())
        )
    }
}
