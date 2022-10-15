import AuthenticationServices
import Foundation
import PromiseKit
import Shared

protocol OnboardingAuthLogin {
    func open(authDetails: OnboardingAuthDetails, sender: UIViewController) -> Promise<String>
}

class OnboardingAuthLoginImpl: OnboardingAuthLogin {
    enum OnboardingAuthLoginError: Error {
        case invalidURL
    }

    var loginViewControllerClass: OnboardingAuthLoginViewController.Type = OnboardingAuthLoginViewControllerImpl.self

    func open(authDetails: OnboardingAuthDetails, sender: UIViewController) -> Promise<String> {
        Current.Log.verbose(authDetails.url)

        let controller = loginViewControllerClass.init(authDetails: authDetails)
        let navigationController = UINavigationController(rootViewController: controller)
        sender.present(navigationController, animated: true, completion: nil)

        return controller.promise.map { url in
            if let code = url.queryItems?["code"] {
                return code
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
