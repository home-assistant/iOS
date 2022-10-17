import Eureka
import Lottie
import RealmSwift
import SafariServices
import Shared
import UIKit

class OnboardingWelcomeViewController: UIViewController, OnboardingViewController {
    private var animationView: LottieAnimationView?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animationView?.play(toMarker: "Circles Formed")
    }

    var preferredBarAppearance: OnboardingBarAppearance { .hidden }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Current.style.onboardingBackground

        let (_, stackView, equalSpacers) = UIView.contentStackView(in: view, scrolling: true)

        stackView.addArrangedSubview(equalSpacers.next())
        stackView.addArrangedSubview(with(LottieAnimationView(animation: .named("ha-loading"))) {
            animationView = $0
            $0.loopMode = .playOnce

            NSLayoutConstraint.activate([
                with($0.widthAnchor.constraint(equalToConstant: 240.0)) {
                    $0.priority = .defaultHigh
                },
                $0.widthAnchor.constraint(lessThanOrEqualToConstant: 240.0),
                $0.widthAnchor.constraint(equalTo: $0.heightAnchor),
            ])
        })

        stackView.addArrangedSubview(with(UILabel()) {
            $0.text = L10n.Onboarding.Welcome.title(Current.device.systemName())
            Current.style.onboardingTitle($0)
        })

        stackView.addArrangedSubview(with(UILabel()) {
            $0.text = L10n.Onboarding.Welcome.description
            $0.font = .preferredFont(forTextStyle: .body)
            $0.textColor = Current.style.onboardingLabelSecondary
            $0.textAlignment = .center
            $0.numberOfLines = 0
        })
        stackView.addArrangedSubview(with(UIButton(type: .system)) {
            $0.setAttributedTitle(NSAttributedString(
                string: L10n.Nfc.List.learnMore,
                attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue]
            ), for: .normal)
            $0.titleLabel?.font = .preferredFont(forTextStyle: .body)
            $0.setTitleColor(Current.style.onboardingLabelSecondary, for: .normal)
            $0.addTarget(self, action: #selector(learnMoreTapped(_:)), for: .touchUpInside)

            UIView.performWithoutAnimation { [button = $0] in
                // Prevent the button from fading in initially
                button.layoutIfNeeded()
            }
        })

        stackView.addArrangedSubview(equalSpacers.next())

        stackView.addArrangedSubview(with(UIButton(type: .custom)) {
            $0.setTitle(L10n.continueLabel, for: .normal)
            $0.addTarget(self, action: #selector(continueTapped(_:)), for: .touchUpInside)
            Current.style.onboardingButtonPrimary($0)
        })

        updateAnimationHiddenState()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAnimationHiddenState()
    }

    private func updateAnimationHiddenState() {
        let animationHidden = traitCollection.verticalSizeClass == .compact
        animationView?.isHidden = animationHidden
    }

    @objc private func continueTapped(_ sender: UIButton) {
        show(OnboardingScanningViewController(), sender: self)
    }

    @objc private func learnMoreTapped(_ sender: UIButton) {
        present(
            SFSafariViewController(url: .init(string: "http://www.home-assistant.io")!),
            animated: true,
            completion: nil
        )
    }
}
