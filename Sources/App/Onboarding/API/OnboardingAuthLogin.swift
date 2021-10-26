import AuthenticationServices
import Foundation
import PromiseKit
import Shared

protocol OnboardingAuthLogin {
    func open(authDetails: OnboardingAuthDetails, sender: UIViewController) -> Promise<String>
}

class OnboardingAuthLoginImpl: OnboardingAuthLogin {
    var authenticationSessionClass: ASWebAuthenticationSession.Type = ASWebAuthenticationSession.self

    func open(authDetails: OnboardingAuthDetails, sender: UIViewController) -> Promise<String> {
        Current.Log.verbose(authDetails.url)

        class PresentationDelegate: NSObject, ASWebAuthenticationPresentationContextProviding {
            let view: UIView
            init(view: UIView) {
                self.view = view
                super.init()
            }

            func presentationAnchor(for: ASWebAuthenticationSession) -> ASPresentationAnchor {
                view.window ?? UIWindow()
            }
        }

        let (promise, resolver) = Promise<String>.pending()
        let session = authenticationSessionClass.init(
            url: authDetails.url,
            callbackURLScheme: authDetails.scheme,
            completionHandler: { url, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    resolver.reject(PMKError.cancelled)
                } else {
                    resolver.resolve(url?.queryItems?["code"], error)
                }
            }
        )

        var delegate: PresentationDelegate? = PresentationDelegate(view: sender.view)
        var presentationSession: ASWebAuthenticationSession? = session

        if #available(iOS 13.0, *) {
            session.presentationContextProvider = delegate
            session.prefersEphemeralWebBrowserSession = true
        }

        session.start()

        promise.ensure {
            // keep the session and its presentation context around until it's done
            withExtendedLifetime(presentationSession) { /* avoiding warnings of write-only */ }

            delegate = nil
            presentationSession = nil
        }.cauterize()

        return promise
    }
}
