import Foundation
import Shared
import UIKit

enum WebViewAccessoryViews {
    static let settingsButton: UIButton = {
        let button = UIButton()
        button.setImage(
            MaterialDesignIcons.cogIcon.image(ofSize: CGSize(width: 36, height: 36), color: .white),
            for: .normal
        )
        button.accessibilityLabel = L10n.Settings.NavigationBar.title
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        button.setBackgroundImage(
            UIImage(size: CGSize(width: 1, height: 1), color: UIColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1.0)),
            for: .normal
        )

        // size isn't affected by any trait changes, so we can grab the height once and not worry about it changing
        let desiredSize = button.systemLayoutSizeFitting(.zero)
        button.layer.cornerRadius = ceil(desiredSize.height / 2.0)
        button.layer.masksToBounds = true

        button.translatesAutoresizingMaskIntoConstraints = false
        if Current.appConfiguration == .fastlaneSnapshot {
            button.alpha = 0
        }
        return button
    }()
}
