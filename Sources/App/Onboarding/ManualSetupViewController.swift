import PromiseKit
import Shared
import UIKit

class ManualSetupViewController: UIViewController, UITextFieldDelegate {
    private let urlField = UITextField()
    private var connectButton: UIButton?
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
        
        stackView.alignment = .fill

        stackView.addArrangedSubview(with(UILabel()) {
            $0.text = "What is your Home Assistant's URL?"
            $0.font = .preferredFont(forTextStyle: .title1)
            $0.textColor = Current.style.onboardingLabel
            $0.textAlignment = .center
            $0.numberOfLines = 0
        })

        stackView.addArrangedSubview(with(UILabel()) {
            $0.text = "It must be a fully formed URL of the format \"http://homeassistant.local:8123\" (that is, containing a scheme/protocol, hostname and port)."
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
            $0.smartDashesType = .no
            $0.smartQuotesType = .no
            $0.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            $0.keyboardAppearance = .dark
            $0.returnKeyType = .go

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(updateConnectButton),
                name: UITextField.textDidChangeNotification,
                object: $0
            )
        })

        stackView.addArrangedSubview(with(UIButton(type: .custom)) {
            connectButton = $0
            $0.setTitle("Connect", for: .normal)
            $0.addTarget(self, action: #selector(connectTapped(_:)), for: .touchUpInside)
            Current.style.onboardingButtonPrimary($0)
        })

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

    @objc private func connectTapped(_ sender: UIButton) {
        Current.Log.verbose("Connect button tapped")
        connect()
    }

    @objc private func updateConnectButton() {
        connectButton?.isEnabled = urlField.text?.isEmpty == false
    }

    private func connect() {
        firstly {
            validatedURL(from: urlField.text)
        }.done { url in
            self.urlField.text = url.absoluteString

            let controller = StoryboardScene.Onboarding.authentication.instantiate()
            controller.instance = DiscoveredHomeAssistant(baseURL: url, name: "Manual", version: "2021.1")
            self.show(controller, sender: self)
        }.catch { error in
            Current.Log.error("Couldn't make a URL: \(error)")

            let alert = UIAlertController(
                title: L10n.Onboarding.ManualSetup.CouldntMakeUrl.title,
                message: L10n.Onboarding.ManualSetup.CouldntMakeUrl.message(self.urlField.text ?? ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    enum ValidateError: Error {
        case emptyString
        case cannotConvert
        case noScheme
        case invalidScheme
    }

    private func promptForScheme(for string: String) -> Promise<String> {
        Promise { seal in
            let alert = UIAlertController(
                title: L10n.Onboarding.ManualSetup.NoScheme.title,
                message: L10n.Onboarding.ManualSetup.NoScheme.message,
                preferredStyle: .alert
            )

            func action(for scheme: String) -> UIAlertAction {
                UIAlertAction(title: scheme, style: .default, handler: { _ in
                    seal.fulfill(scheme + string)
                })
            }

            alert.addAction(action(for: "http://"))
            alert.addAction(action(for: "https://"))
            alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: { _ in
                seal.reject(ValidateError.noScheme)
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

        view.layoutIfNeeded()

        let intersectHeight = view.convert(frameValue.cgRectValue, from: nil).intersection(scrollView.frame).height
        let insetHeight = max(0, intersectHeight - (bottomSpacer?.bounds.height ?? 0))

        scrollView.contentInset.bottom = insetHeight
        scrollView.scrollIndicatorInsets.bottom = insetHeight
    }
}
