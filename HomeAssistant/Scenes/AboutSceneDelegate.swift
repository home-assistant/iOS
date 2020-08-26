import Foundation
import UIKit

@objc class AboutSceneDelegate: BasicSceneDelegate {
    override class func basicConfig() -> BasicSceneDelegate.BasicConfig {
        .init(
            title: L10n.About.title,
            rootViewController: UINavigationController(rootViewController: AboutViewController())
        )
    }
}
