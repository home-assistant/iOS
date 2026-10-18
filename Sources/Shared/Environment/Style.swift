import HADesignSystem
import ObjectiveC.runtime
import UIKit

public struct Style {
    #if os(iOS)
    public var onboardingTitle: (_ label: UILabel) -> Void = { label in
        label.font = .boldSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .title1).pointSize)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityTraits.insert(.header)
    }

    private class WiderButton: UIButton {
        private var readableWidthConstraint: NSLayoutConstraint?

        override func didMoveToSuperview() {
            super.didMoveToSuperview()

            readableWidthConstraint?.isActive = false
            readableWidthConstraint = superview.map {
                widthAnchor.constraint(equalTo: $0.readableContentGuide.widthAnchor)
            }
            updateReadableWidthConstraint()
        }

        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)

            if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
                updateReadableWidthConstraint()
            }
        }

        // The size class isn't final until the button is in a window, so the constraint is re-evaluated
        // on trait changes rather than fixed at add time.
        private func updateReadableWidthConstraint() {
            readableWidthConstraint?.isActive = traitCollection.horizontalSizeClass == .regular
        }
    }

    private static func onboardingButton(_ button: UIButton) {
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true

        var config = UIButton.Configuration.filled()
        config.contentInsets = .init(
            top: DesignSystem.Spaces.two,
            leading: DesignSystem.Spaces.two,
            bottom: DesignSystem.Spaces.two,
            trailing: DesignSystem.Spaces.two
        )
        button.configuration = config

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

        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .haPrimary

        button.setBackgroundImage(
            UIImage(size: CGSize(width: 1, height: 1), color: .white),
            for: .normal
        )
        button.setBackgroundImage(
            UIImage(size: CGSize(width: 1, height: 1), color: .white.withAlphaComponent(0.7)),
            for: .highlighted
        )

        button.role = .primary
    }

    public var onboardingButtonSecondary: (_ button: UIButton) -> Void = { button in
        Self.onboardingButton(button)

        button.setTitleColor(UIColor.white, for: .normal)
        button.setBackgroundImage(
            UIImage(size: CGSize(width: 1, height: 1), color: AppConstants.lighterTintColor),
            for: .normal
        )
        button.setBackgroundImage(
            UIImage(size: CGSize(width: 1, height: 1), color: .white.withAlphaComponent(0.3)),
            for: .highlighted
        )
    }
    #endif
}
