import AuthenticationServices
import Foundation
import PromiseKit
import Shared

struct OnboardingAuthLoginResult {
    let code: String
    /// Server base URL the web view ended on; may differ in port/scheme from the URL we started with.
    let resolvedURL: URL?
}

protocol OnboardingAuthLogin {
    func open(authDetails: OnboardingAuthDetails, sender: UIViewController) -> Promise<OnboardingAuthLoginResult>
}

class OnboardingAuthLoginImpl: OnboardingAuthLogin {
    enum OnboardingAuthLoginError: Error {
        case invalidURL
    }

    var loginViewControllerClass: OnboardingAuthLoginViewController.Type = OnboardingAuthLoginViewControllerImpl.self

    func open(authDetails: OnboardingAuthDetails, sender: UIViewController) -> Promise<OnboardingAuthLoginResult> {
        Current.Log.verbose(authDetails.url)

        let controller = loginViewControllerClass.init(authDetails: authDetails)
        let navigationController = UINavigationController(rootViewController: controller)
        sender.present(navigationController, animated: true, completion: nil)

        return controller.promise.map { url in
            if let code = url.queryItems?["code"] {
                return OnboardingAuthLoginResult(code: code, resolvedURL: controller.resolvedServerURL)
            } else {
                throw OnboardingAuthLoginError.invalidURL
            }
        }.ensureThen {
            Guarantee<Void> { seal in
                navigationController.dismiss(animated: true, completion: {
                    seal(())
                })
            }
        }
    }
}
