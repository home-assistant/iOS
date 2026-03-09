import Foundation
import Shared
import SwiftUI
import UIKit

extension UIWindow {
    convenience init(haScene scene: UIWindowScene) {
        self.init(windowScene: scene)
        self.tintColor = UIColor(Color.haPrimary)
        makeKeyAndVisible()
    }
}
