import PromiseKit
import Shared
import UIKit

class ManualSetupViewController: UIViewController {
    @IBOutlet var connectButton: UIButton!
    @IBOutlet var urlField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let navVC = navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(connectButton)
        }

        // Keyboard avoidance adapted from https://stackoverflow.com/a/27135992/486182
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(notification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @IBAction func connectButtonTapped(_ sender: UIButton) {
        Current.Log.verbose("Connect button tapped")

        firstly {
            validatedURL(from: urlField.text)
        }.done { updated in
            self.urlField.text = updated
            self.perform(segue: StoryboardSegue.Onboarding.setupManualInstance)
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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueType = StoryboardSegue.Onboarding(segue) else { return }
        if segueType == .setupManualInstance, let vc = segue.destination as? AuthenticationViewController {
            guard let fieldVal = urlField.text else {
                Current.Log
                    .error(
                        "Unable to get text! Field is \(String(describing: urlField)), text \(String(describing: urlField.text))"
                    )
                return
            }
            guard let url = URL(string: fieldVal) else {
                Current.Log.error("Unable to convert text to URL! Text was \(fieldVal)")
                return
            }

            vc.instance = DiscoveredHomeAssistant(baseURL: url, name: "Manual", version: "0.92.0")
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

    private func validatedURL(from inputString: String?) -> Promise<String> {
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
            }.map { (string: String) -> String in
                if URL(string: string) != nil {
                    return string
                } else {
                    throw ValidateError.cannotConvert
                }
            }
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        guard let keyboardSize = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        if view.frame.origin.y == 0 {
            view.frame.origin.y -= keyboardSize.cgRectValue.height / 2
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        guard let keyboardSize = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        if view.frame.origin.y != 0 {
            view.frame.origin.y += keyboardSize.cgRectValue.height / 2
        }
    }
}
