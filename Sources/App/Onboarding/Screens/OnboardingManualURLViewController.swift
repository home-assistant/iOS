import PromiseKit
import Shared
import UIKit

class OnboardingManualURLViewController: UIViewController, UITextFieldDelegate {
    private let urlField = UITextField()
    private var connectButton: UIButton?
    private var connectLoading: UIActivityIndicatorView?
    private var scrollView: UIScrollView?
    private var bottomSpacer: UIView?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        urlField.becomeFirstResponder()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Current.style.onboardingBackground

        let (scrollView, stackView, equalSpacers) = UIView.contentStackView(in: view, scrolling: true)
        self.scrollView = scrollView

        stackView.addArrangedSubview(with(UILabel()) {
            $0.text = L10n.Onboarding.ManualSetup.title
            Current.style.onboardingTitle($0)
        })

        stackView.addArrangedSubview(with(UILabel()) {
            $0.text = L10n.Onboarding.ManualSetup.description
            $0.font = .preferredFont(forTextStyle: .body)
            $0.textColor = Current.style.onboardingLabelSecondary
            $0.textAlignment = .natural
            $0.numberOfLines = 0
        })

        stackView.addArrangedSubview(with(urlField) {
            $0.delegate = self
            $0.backgroundColor = UIColor(white: 0, alpha: 0.12)
            $0.borderStyle = .roundedRect
            $0.placeholder = "http://homeassistant.local:8123"
            $0.textContentType = .URL
            $0.keyboardType = .URL
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
            $0.spellCheckingType = .no
            $0.smartDashesType = .no
            $0.smartQuotesType = .no
            $0.keyboardAppearance = .dark
            $0.returnKeyType = .continue
            $0.enablesReturnKeyAutomatically = true
            $0.clearButtonMode = .whileEditing

            if #available(iOS 13, *) {
            } else {
                $0.textColor = .white
            }

            let font = UIFont.preferredFont(forTextStyle: .body)
            $0.font = font
            $0.heightAnchor.constraint(greaterThanOrEqualToConstant: font.lineHeight * 2.5)
                .isActive = true

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(updateConnectButton),
                name: UITextField.textDidChangeNotification,
                object: $0
            )
        })

        switch traitCollection.userInterfaceIdiom {
        case .pad, .mac:
            urlField.widthAnchor.constraint(equalTo: stackView.readableContentGuide.widthAnchor)
                .isActive = true
        default:
            urlField.widthAnchor.constraint(equalTo: stackView.layoutMarginsGuide.widthAnchor)
                .isActive = true
        }

        let button = with(UIButton(type: .custom)) {
            $0.setTitle(L10n.Onboarding.ManualSetup.connect, for: .normal)
            $0.addTarget(self, action: #selector(connectTapped(_:)), for: .touchUpInside)
            Current.style.onboardingButtonPrimary($0)

            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        let loading: UIActivityIndicatorView = {
            let indicator: UIActivityIndicatorView
            if #available(iOS 13, *) {
                indicator = UIActivityIndicatorView(style: .medium)
            } else {
                indicator = UIActivityIndicatorView(style: .white)
            }

            indicator.hidesWhenStopped = true
            indicator.color = button.titleColor(for: .normal)
            return indicator
        }()

        connectButton = button
        connectLoading = loading

        with(button) {
            $0.addSubview(loading)
            loading.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                loading.centerYAnchor.constraint(equalTo: $0.centerYAnchor),
                loading.trailingAnchor.constraint(equalTo: $0.trailingAnchor, constant: -16),
            ])
        }

        if Current.isCatalyst {
            // iPad and iPhone unconditionally show the input view, but mac never does
            stackView.addArrangedSubview(button)
        } else {
            urlField.inputAccessoryView = with(InputAccessoryView()) {
                $0.directionalLayoutMargins = stackView.directionalLayoutMargins
                $0.contentView = button
            }
        }

        stackView.addArrangedSubview(with(equalSpacers.next()) {
            bottomSpacer = $0
        })

        updateConnectButton()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        connect()
        return false
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        !isConnecting
    }

    @objc private func connectTapped(_ sender: UIButton) {
        Current.Log.verbose("Connect button tapped")
        connect()
    }

    @objc private func updateConnectButton() {
        connectButton?.isEnabled = urlField.text?.isEmpty == false
    }

    private var isConnecting: Bool = false {
        didSet {
            if isConnecting {
                connectLoading?.startAnimating()
                connectButton?.isUserInteractionEnabled = false
            } else {
                connectLoading?.stopAnimating()
                connectButton?.isUserInteractionEnabled = true
            }
        }
    }

    private func connect() {
        guard !isConnecting else { return }

        isConnecting = true

        let authentication = OnboardingAuth()

        firstly {
            validatedURL(from: urlField.text)
        }.recover { [self] error -> Promise<URL> in
            Current.Log.error("Couldn't make a URL: \(error)")

            let alert = UIAlertController(
                title: L10n.Onboarding.ManualSetup.CouldntMakeUrl.title,
                message: L10n.Onboarding.ManualSetup.CouldntMakeUrl.message(self.urlField.text ?? ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default, handler: nil))
            present(alert, animated: true, completion: nil)

            return .init(error: PMKError.cancelled)
        }.then { [self] (url: URL) -> Promise<Server> in
            let instance = DiscoveredHomeAssistant(manualURL: url)
            return authentication.authenticate(to: instance, sender: self)
        }.ensure { [self] in
            isConnecting = false
        }.done { [self] server in
            show(authentication.successController(server: server), sender: self)
        }.catch { [self] error in
            show(authentication.failureController(error: error), sender: self)
        }
    }

    enum ValidateError: Error, CancellableError {
        case emptyString
        case cannotConvert
        case invalidScheme
        case noSchemeCancelled

        var isCancelled: Bool {
            switch self {
            case .emptyString, .cannotConvert, .invalidScheme:
                return false
            case .noSchemeCancelled:
                return true
            }
        }
    }

    private func promptForScheme(for string: String) -> Promise<String> {
        Promise { seal in
            let alert = UIAlertController(
                title: L10n.Onboarding.ManualSetup.NoScheme.title,
                message: L10n.Onboarding.ManualSetup.NoScheme.message,
                preferredStyle: .actionSheet
            )

            with(alert.popoverPresentationController) {
                $0?.sourceView = urlField
                $0?.sourceRect = urlField.bounds
            }

            func action(for scheme: String) -> UIAlertAction {
                UIAlertAction(title: scheme, style: .default, handler: { _ in
                    seal.fulfill(scheme + string)
                })
            }

            alert.addAction(action(for: "http://"))
            alert.addAction(action(for: "https://"))
            alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: { _ in
                seal.reject(ValidateError.noSchemeCancelled)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func validatedURL(from inputString: String?) -> Promise<URL> {
        let start = Promise<String?>.value(inputString)

        return start
            .map { (string: String?) -> String in
                if let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.isEmpty == false {
                    return trimmed
                } else {
                    throw ValidateError.emptyString
                }
            }.then { (string: String) -> Promise<String> in
                if string.starts(with: "http://") || string.starts(with: "https://") {
                    return .value(string)
                } else if string.contains("://") == false {
                    return self.promptForScheme(for: string)
                } else {
                    throw ValidateError.invalidScheme
                }
            }.map { (string: String) -> URL in
                if let url = URL(string: string) {
                    return url
                } else {
                    throw ValidateError.cannotConvert
                }
            }
    }

    @objc private func keyboardWillChangeFrame(_ note: Notification) {
        guard let scrollView = scrollView,
              let frameValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }

        UIView.performWithoutAnimation {
            view.layoutIfNeeded()
        }

        let intersectHeight = view.convert(frameValue.cgRectValue, from: nil).intersection(scrollView.frame).height
        let insetHeight = max(0, intersectHeight - (bottomSpacer?.bounds.height ?? 0))

        scrollView.contentInset.bottom = insetHeight

        if #available(iOS 13, *) {
            scrollView.verticalScrollIndicatorInsets.bottom = insetHeight
        } else {
            scrollView.scrollIndicatorInsets.bottom = insetHeight
        }
    }
}
