import Foundation
import SFSafeSymbols
import Shared
import UIKit

enum WebViewControllerButtons {
    static var openInSafariButton: UIButton {
        let openInSafariButton = UIButton(type: .custom)
        let image = UIImage(resource: .compass).scaledToSize(.init(width: 7, height: 7))
            .withTintColor(.haPrimary)
        openInSafariButton.setImage(image, for: .normal)
        openInSafariButton.backgroundColor = .white
        openInSafariButton.tintColor = .white
        openInSafariButton.layer.cornerRadius = 6
        openInSafariButton.layer.shadowColor = UIColor.black.cgColor
        openInSafariButton.layer.shadowRadius = 0.5
        openInSafariButton.layer.shadowOpacity = 0.7
        openInSafariButton.layer.shadowOffset = .init(width: 0, height: 0)
        openInSafariButton.layer.masksToBounds = false
        return openInSafariButton
    }

    private static func navigationButton(symbol: SFSymbol, accessibilityLabel: String) -> UIButton {
        let button = UIButton(type: .system)
        let image = UIImage(systemSymbol: symbol).withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.tintColor = .label
        button.accessibilityLabel = accessibilityLabel
        // Add white shadow to improve visibility on dark backgrounds
        button.layer.shadowColor = UIColor.gray.cgColor
        button.layer.shadowRadius = 1.5
        button.layer.shadowOpacity = 0.8
        button.layer.shadowOffset = CGSize(width: 0, height: 0)
        button.layer.masksToBounds = false
        return button
    }

    static var backButton: UIButton {
        navigationButton(symbol: .chevronLeft, accessibilityLabel: L10n.Mac.Navigation.GoBack.accessibilityLabel)
    }

    static var forwardButton: UIButton {
        navigationButton(symbol: .chevronRight, accessibilityLabel: L10n.Mac.Navigation.GoForward.accessibilityLabel)
    }
}
