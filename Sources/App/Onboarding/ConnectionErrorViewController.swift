import Lottie
import Shared
import UIKit

class ConnectionErrorViewController: UIViewController {
    private var animationView: AnimationView?
    private var moreInfoButton: UIButton?
    private var goBackButton: UIButton?

    let error: Error
    init(error: Error) {
        self.error = error
        super.init(nibName: nil, bundle: nil)
    }

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

        stackView.addArrangedSubview(with(AnimationView()) {
            $0.animation = Animation.named("error")
            $0.loopMode = .playOnce
            $0.play()
        })

        stackView.addArrangedSubview(with(UITextView()) {
            let errorText: String

            if let error = error as? ConnectionTestResult {
                if error.kind == .sslExpired || error.kind == .sslUntrusted {
                    errorText = L10n.Onboarding.ConnectionTestResult.SslContainer.description(error.localizedDescription)
                } else {
                    errorText = error.localizedDescription
                }
            } else {
                errorText = error.localizedDescription
            }

            $0.isScrollEnabled = false
            $0.isEditable = false
            $0.isSelectable = true
            $0.backgroundColor = .clear
            $0.textContainer.lineFragmentPadding = 0
            $0.textContainerInset = .zero
            $0.text = errorText
            $0.font = .preferredFont(forTextStyle: .body)
            $0.textColor = Current.style.onboardingLabel
        })

        stackView.addArrangedSubview(equalSpacers.next())
        stackView.addArrangedSubview(with(UIButton(type: .custom)) {
            $0.setTitle(L10n.Onboarding.ConnectionError.moreInfoButton, for: .normal)
            $0.isHidden = !(error is ConnectionTestResult)
            $0.addTarget(self, action: #selector(moreInfoTapped(_:)), for: .touchUpInside)
            Current.style.onboardingButtonPrimary($0)
        })
    }

    @objc private func moreInfoTapped(_ sender: UIButton) {
        guard let error = self.error as? ConnectionTestResult else { return }
        openURLInBrowser(error.DocumentationURL, self)
    }
}
