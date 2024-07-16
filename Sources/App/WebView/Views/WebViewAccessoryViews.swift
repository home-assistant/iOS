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

    static let improEntryFlowView: UIView = {
        let view = UIView()
        view.alpha = 0
        view.backgroundColor = .secondarySystemBackground

        let improvIcon = UIImageView(image: Asset.SharedAssets.improvLogo.image)
        improvIcon.contentMode = .scaleAspectFit
        let title = UILabel()
        title.text = "There are Improv-BLE devices available to setup."
        title.numberOfLines = 0

        let chevron = UIImage(systemName: "chevron.right")?.withTintColor(.tertiaryLabel)
        let chevronImageView = UIImageView(image: chevron)
        chevronImageView.contentMode = .scaleAspectFit

        let stackView = UIStackView(arrangedSubviews: [
            improvIcon,
            title,
            chevronImageView,
        ])
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        stackView.spacing = Spaces.two

        view.addSubview(stackView)

        view.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: Spaces.half),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Spaces.half),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Spaces.two),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Spaces.two),
            stackView.heightAnchor.constraint(equalToConstant: 100),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
        ])
        view.layer.cornerRadius = 25
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowRadius = 10
        view.layer.shadowOffset = .init(width: 0, height: 0)
        view.layer.shadowOpacity = 0.2
        view.layoutIfNeeded()
        return view
    }()
}
