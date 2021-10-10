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
    }
    public var onboardingButtonPrimary: (_ button: UIButton) -> Void = { button in
        button.layer.cornerRadius = 6.0
        button.layer.masksToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        button.titleLabel?.font = UIFont.systemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize,
            weight: .bold
        )
        button.setTitleColor(Constants.darkerTintColor, for: .normal)
        button.setBackgroundImage(
            UIImage(size: CGSize(width: 1, height: 1), color: .white),
            for: .normal
        )
        button.setBackgroundImage(
            UIImage(size: CGSize(width: 1, height: 1), color: .white.withAlphaComponent(0.7)),
            for: .highlighted
        )

        if let title = button.title(for: .normal) {
            button.setTitle(title.localizedUppercase, for: .normal)
        }
    }
    #endif
}
