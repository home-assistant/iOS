import ObjectiveC.runtime
import UIKit

public struct Style {
    #if os(iOS)
    public var onboardingBackground: UIColor = Constants.darkerTintColor
    public var onboardingTintColor: UIColor = .white
    public var onboardingLabel: UIColor = .white
    public var onboardingLabelSecondary: UIColor = .white.withAlphaComponent(0.85)
    public var onboardingTitle: (_ label: UILabel) -> Void = { label in
        label.font = .preferredFont(forTextStyle: .title1)
        label.textColor = Current.style.onboardingLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityTraits.insert(.header)
    }

    private class WiderButton: UIButton {
        override func didMoveToSuperview() {
            super.didMoveToSuperview()

            if let superview = superview {
                switch traitCollection.userInterfaceIdiom {
                case .pad, .mac:
                    widthAnchor.constraint(equalTo: superview.readableContentGuide.widthAnchor)
                        .isActive = true
                default:
                    widthAnchor.constraint(equalTo: superview.layoutMarginsGuide.widthAnchor)
                        .isActive = true
                }
            }
        }
    }

    private static func onboardingButton(_ button: UIButton) {
        button.layer.cornerRadius = 6.0
        button.layer.masksToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        button.titleLabel?.font = UIFont.systemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize,
            weight: .bold
        )

        if type(of: button) == UIButton.self {
            object_setClass(button, WiderButton.self)
        }
    }

    public var onboardingButtonPrimary: (_ button: UIButton) -> Void = { button in
        Self.onboardingButton(button)

        button.setTitleColor(Constants.darkerTintColor, for: .normal)
        button.setBackgroundImage(
            UIImage(size: CGSize(width: 1, height: 1), color: .white),
            for: .normal
        )
        button.setBackgroundImage(
            UIImage(size: CGSize(width: 1, height: 1), color: .white.withAlphaComponent(0.7)),
            for: .highlighted
        )

        #if targetEnvironment(macCatalyst)
        if #available(iOS 14, *) {
            button.role = .primary
        }
        #endif
    }

    public var onboardingButtonSecondary: (_ button: UIButton) -> Void = { button in
        Self.onboardingButton(button)

        button.setTitleColor(UIColor.white, for: .normal)
        button.setBackgroundImage(
            UIImage(size: CGSize(width: 1, height: 1), color: Constants.lighterTintColor),
            for: .normal
        )
        button.setBackgroundImage(
            UIImage(size: CGSize(width: 1, height: 1), color: .white.withAlphaComponent(0.3)),
            for: .highlighted
        )
    }
    #endif
}
