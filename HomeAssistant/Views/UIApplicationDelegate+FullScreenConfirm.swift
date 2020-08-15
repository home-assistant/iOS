import Foundation
import Shared
import UIKit
import MBProgressHUD

extension UIApplicationDelegate {
    func showFullScreenConfirm(
        icon: MaterialDesignIcons,
        text: String
    ) {
        guard case .some(.some(let window)) = window else {
            Current.Log.error("not showing confirm before window created")
            return
        }

        let hud = MBProgressHUD.showAdded(to: window, animated: true)
        hud.mode = .customView
        hud.backgroundView.style = .blur
        hud.customView = with(IconImageView(frame: .init(x: 0, y: 0, width: 64, height: 64))) {
            $0.iconDrawable = icon
        }
        hud.label.text = text
        hud.hide(animated: true, afterDelay: 3)
    }
}
