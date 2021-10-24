import Foundation
import Alamofire
import PromiseKit
import Shared
import UIKit

struct OnboardingAuthStepConnectivity: OnboardingAuthPreStep {
    let authDetails: OnboardingAuthDetails
    init(authDetails: OnboardingAuthDetails, sender: UIViewController) {
        self.authDetails = authDetails
    }

    static var supportedPoints: Set<OnboardingAuthStepPoint> {
        Set([.beforeAuth])
    }

    var prepareSessionConfiguration: ((URLSessionConfiguration) -> Void)?

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Current.Log.verbose()

        let (promise, resolver) = Promise<Void>.pending()

        var clientCertificateErrorOccurred: Bool = false

        let eventMonitor = with(ClosureEventMonitor()) {
            $0.taskDidReceiveChallenge = { _, task, challenge in
                Current.Log.verbose(challenge.protectionSpace.authenticationMethod)

                let errorKind: OnboardingAuthError.ErrorKind? = {
                    switch challenge.protectionSpace.authenticationMethod {
                    case NSURLAuthenticationMethodServerTrust: return nil
                    case NSURLAuthenticationMethodHTTPBasic: return .basicAuth
                    case NSURLAuthenticationMethodClientCertificate:
                        clientCertificateErrorOccurred = true
                        return nil
                    default: return .authenticationUnsupported(challenge.protectionSpace.authenticationMethod)
                    }
                }()

                if let errorKind = errorKind {
                    resolver.reject(OnboardingAuthError(kind: errorKind, data: nil))
                    task.cancel()
                }
            }
        }

        let configuration = URLSessionConfiguration.ephemeral
        prepareSessionConfiguration?(configuration)

        let session = Session(configuration: configuration, eventMonitors: [eventMonitor])
        session.request(authDetails.url).validate().response { response in
            Current.Log.info(response)

            resolver.resolve(response.result.map { _ in () }.mapError { wrapper -> Error in
                let kind: OnboardingAuthError.ErrorKind
                let underlying = wrapper.underlyingError ?? wrapper

                if clientCertificateErrorOccurred {
                    kind = .clientCertificateRequired(underlying)
                } else if let underlying = underlying as? URLError {
                    switch underlying.code {
                    case .serverCertificateUntrusted, .serverCertificateHasUnknownRoot, .serverCertificateHasBadDate,
                            .serverCertificateNotYetValid:
                        kind = .sslUntrusted(underlying)
                    default:
                        kind = .other(underlying)
                    }
                } else {
                    kind = .other(underlying)
                }

                return OnboardingAuthError(kind: kind, data: response.data)
            })

            withExtendedLifetime(session) {
                // keep the session alive
            }
        }

        return promise
    }
}
