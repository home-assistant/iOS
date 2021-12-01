import AuthenticationServices
import Foundation
import PromiseKit
import Shared

protocol OnboardingAuthLogin {
    func open(authDetails: OnboardingAuthDetails, sender: UIViewController) -> Promise<String>
}

class OnboardingAuthLoginImpl: OnboardingAuthLogin {
    var authenticationSessionClass: ASWebAuthenticationSession.Type = ASWebAuthenticationSession.self
    var macPresentTimer: Timer? {
        didSet {
            if oldValue != macPresentTimer {
                oldValue?.invalidate()
            }
        }
    }

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

        var (promise, resolver) = Promise<String>.pending()
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

        if Current.isCatalyst {
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [promise] _ in
                guard !promise.isResolved else { return }

                let alert = UIAlertController(
                    title: L10n.Onboarding.Connect.MacSafariWarning.title,
                    message: L10n.Onboarding.Connect.MacSafariWarning.message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: { _ in
                    session.cancel()
                }))
                sender.present(alert, animated: true, completion: nil)

                promise.ensure {
                    if sender.presentedViewController == alert {
                        sender.dismiss(animated: true, completion: nil)
                    }
                }.cauterize()
            }
            macPresentTimer = timer

            promise = promise.ensure {
                timer.invalidate()
            }
        }

        promise = promise.ensure {
            // keep the session and its presentation context around until it's done
            withExtendedLifetime(presentationSession) { /* avoiding warnings of write-only */ }

            delegate = nil
            presentationSession = nil
        }

        return promise
    }
}
