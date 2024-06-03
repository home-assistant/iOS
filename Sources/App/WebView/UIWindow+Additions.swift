import Foundation
import Shared
import UIKit

extension UIWindow {
    convenience init(haScene scene: UIWindowScene) {
        self.init(windowScene: scene)
        self.tintColor = Constants.tintColor
        makeKeyAndVisible()
    }
}
