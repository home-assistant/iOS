import AuthenticationServices
import Foundation
import PromiseKit
import Shared

protocol OnboardingAuthLogin {
    func open(authDetails: OnboardingAuthDetails, sender: UIViewController) -> Promise<String>
}

class OnboardingAuthLoginImpl: OnboardingAuthLogin {
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
        let session = ASWebAuthenticationSession(
            url: authDetails.url,
            callbackURLScheme: authDetails.scheme,
            completionHandler: { url, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    resolver.reject(PMKError.cancelled)
                } else {
                    resolver.resolve(error, url.flatMap(Self.code(fromSuccess:)))
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

    private static func code(fromSuccess url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }

        let parameter = components.queryItems?.first(where: { item -> Bool in
            item.name == "code"
        })

        if let codeParamter = parameter, let code = codeParamter.value {
            Current.Log.verbose("Returning from authentication with code \(code)")
            return code
        }

        return nil
    }
}
