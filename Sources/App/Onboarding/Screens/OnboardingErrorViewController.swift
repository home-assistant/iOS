import Lottie
import Shared
import UIKit

class OnboardingErrorViewController: UIViewController {
    private var animationView: LottieAnimationView?
    private var moreInfoButton: UIButton?
    private var goBackButton: UIButton?

    let error: Error
    init(error: Error) {
        self.error = error
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Current.style.onboardingBackground

        let (_, stackView, equalSpacers) = UIView.contentStackView(in: view, scrolling: true)

        stackView.addArrangedSubview(with(UILabel()) {
            $0.text = L10n.Onboarding.ConnectionError.title
            Current.style.onboardingTitle($0)
        })

        stackView.addArrangedSubview(with(LottieAnimationView()) {
            $0.animation = LottieAnimation.named("error")
            $0.loopMode = .playOnce
            $0.play()
        })

        stackView.addArrangedSubview(with(UITextView()) {
            var errorComponents: [NSAttributedString] = [
                NSAttributedString(string: error.localizedDescription),
            ]

            func errorCode(_ value: String) -> NSAttributedString {
                NSAttributedString(string: L10n.Onboarding.ConnectionTestResult.errorCode + "\n" + value)
            }

            if let error = error as? OnboardingAuthError {
                if let code = error.errorCode {
                    errorComponents.append(errorCode(code))
                }

                if let source = error.responseString {
                    let font: UIFont

                    font = .monospacedSystemFont(ofSize: 14.0, weight: .regular)

                    errorComponents.append(NSAttributedString(
                        string: source,
                        attributes: [.font: font]
                    ))
                }
            } else {
                let nsError = error as NSError
                errorComponents.append(errorCode(String(format: "%@ %d", nsError.domain, nsError.code)))
            }

            $0.isScrollEnabled = false
            $0.isEditable = false
            $0.isSelectable = true
            $0.backgroundColor = .clear
            $0.textContainer.lineFragmentPadding = 0
            $0.textContainerInset = .zero
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: Current.style.onboardingLabel,
            ]
            $0.attributedText = errorComponents.reduce(into: NSMutableAttributedString()) { base, added in
                if base.length > 0 {
                    base.append(NSAttributedString(string: "\n\n", attributes: baseAttributes))
                }

                base.append(with(NSMutableAttributedString(attributedString: added)) {
                    $0.addMissingAttributes(baseAttributes)
                })
            }
        })

        stackView.addArrangedSubview(equalSpacers.next())
        stackView.addArrangedSubview(with(UIButton(type: .custom)) {
            $0.setTitle(Current.Log.exportTitle, for: .normal)
            $0.addTarget(self, action: #selector(exportTapped(_:)), for: .touchUpInside)
            Current.style.onboardingButtonSecondary($0)
        })
        stackView.addArrangedSubview(with(UIButton(type: .custom)) {
            $0.setTitle(L10n.Onboarding.ConnectionError.moreInfoButton, for: .normal)
            $0.isHidden = !(error is OnboardingAuthError)
            $0.addTarget(self, action: #selector(moreInfoTapped(_:)), for: .touchUpInside)
            Current.style.onboardingButtonPrimary($0)
        })
    }

    private func documentationURL(for error: Error) -> URL {
        var string = "https://companion.home-assistant.io/docs/troubleshooting/errors"

        if let error = error as? OnboardingAuthError {
            string += "#\(error.kind.documentationAnchor)"
        }

        return URL(string: string)!
    }

    @objc private func moreInfoTapped(_ sender: UIButton) {
        openURLInBrowser(documentationURL(for: error), self)
    }

    @objc private func exportTapped(_ sender: UIButton) {
        Current.Log.export(from: self, sender: sender, openURLHandler: { url in
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        })
    }
}
