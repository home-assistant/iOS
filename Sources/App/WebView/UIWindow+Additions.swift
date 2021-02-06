import Foundation
import Shared
import UIKit

extension UIWindow {
    @available(iOS 13, *)
    convenience init(haScene scene: UIWindowScene) {
        self.init(windowScene: scene)
        self.tintColor = Constants.tintColor
        makeKeyAndVisible()
    }

    @available(iOS, deprecated: 13.0)
    convenience init(haForiOS12: ()) {
        self.init(frame: UIScreen.main.bounds)
        self.tintColor = Constants.tintColor
        self.restorationIdentifier = StateRestorationKey.mainWindow.rawValue
        makeKeyAndVisible()
    }
}
