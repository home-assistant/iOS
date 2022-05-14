import Foundation
import PromiseKit
import Shared
import UIKit
import QuickLook

class OnboardingAuthStepConnectivity: NSObject, OnboardingAuthPreStep, URLSessionDelegate {
    let authDetails: OnboardingAuthDetails
    let sender: UIViewController

    required init(authDetails: OnboardingAuthDetails, sender: UIViewController) {
        self.authDetails = authDetails
        self.sender = sender
        super.init()
    }

    static var supportedPoints: Set<OnboardingAuthStepPoint> {
        Set([.beforeAuth])
    }

    var prepareSessionConfiguration: ((URLSessionConfiguration) -> Void)?

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Current.Log.verbose()

        let (promise, resolver) = Promise<Void>.pending()
        self.pendingResolver = resolver

        performConnection()
        return promise


//        var clientCertificateErrorOccurred: Bool = false
//
//        let eventMonitor = with(ClosureEventMonitor()) {
//            $0.taskDidReceiveChallenge = { _, task, challenge in
//                Current.Log.verbose(challenge.protectionSpace.authenticationMethod)
//
//                let errorKind: OnboardingAuthError.ErrorKind? = {
//                    switch challenge.protectionSpace.authenticationMethod {
//                    case NSURLAuthenticationMethodServerTrust:
//                        guard let secTrust = challenge.protectionSpace.serverTrust else {
//                            // weird stuff is abound
//                            return nil
//                        }
//
//                        var error: CFError?
//                        let isTrusted = SecTrustEvaluateWithError(secTrust, &error)
//
//                        guard !isTrusted, let error = error as Error? else {
//                            // continue normally
//                            return nil
//                        }
//
//                        Current.Log.error("received SSL error: \((error as NSError).debugDescription)")
//
//                        var errors = [Error]()
//                        errors.append(error)
//
//                        if let underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error {
//                            // higher-level error is like:
//                            // > “fake.example.com” certificate is not trusted
//                            // underlying error is like:
//                            // > “fake.example.com” has errors: SSL hostname does not match name(s) in certificate,
//                            // > Extended key usage does not match certificate usage, Root is not trusted;
//                            errors.append(underlying)
//                        }
//
//                        return .sslUntrusted(errors)
//                    case NSURLAuthenticationMethodHTTPBasic: return .basicAuth
//                    case NSURLAuthenticationMethodClientCertificate:
//                        clientCertificateErrorOccurred = true
//                        return nil
//                    default: return .authenticationUnsupported(challenge.protectionSpace.authenticationMethod)
//                    }
//                }()
//
//                if let errorKind = errorKind {
//                    resolver.reject(OnboardingAuthError(kind: errorKind, data: nil))
//                    task.cancel()
//                }
//            }
//        }
//
//
//
//
//
//
//        return promise
    }

    private func performConnection() {
        guard let pendingResolver = pendingResolver else { return }

        let configuration = URLSessionConfiguration.ephemeral
        prepareSessionConfiguration?(configuration)
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)

        session.dataTask(.promise, with: authDetails.url)
            .validate()
            .map { _ in () }
            .recover { [self] error throws -> Void in
                let kind: OnboardingAuthError.ErrorKind
                let data: Data?

                switch error as? PMKHTTPError {
                case let .badStatusCode(_, badStatusCodeData, _):
                    data = badStatusCodeData
                case .none:
                    data = nil
                }

                if clientCertificateErrorOccurred {
                    kind = .clientCertificateRequired(error)
                } else if let error = error as? URLError {
                    switch error.code {
                    case .serverCertificateUntrusted, .serverCertificateHasUnknownRoot, .serverCertificateHasBadDate,
                            .serverCertificateNotYetValid:
                        kind = .sslUntrusted([error])
                    default:
                        kind = .other(error)
                    }
                } else {
                    kind = .other(error)
                }

                throw OnboardingAuthError(kind: kind, data: data)
            }
            .pipe(to: pendingResolver.resolve)
    }

    private var clientCertificateErrorOccurred = false
    private var pendingResolver: Resolver<Void>?

    private func confirm(secTrust: SecTrust, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let pendingResolver = pendingResolver else {
            completionHandler(.rejectProtectionSpace, nil)
            return
        }

        do {
            try authDetails.exceptions.evaluate(secTrust)
            completionHandler(.performDefaultHandling, nil)
        } catch {
            Current.Log.error("received SSL error: \((error as NSError).debugDescription)")

            var errors = [Error]()
            errors.append(error)

            if let underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error {
                // higher-level error is like:
                // > “fake.example.com” certificate is not trusted
                // underlying error is like:
                // > “fake.example.com” has errors: SSL hostname does not match name(s) in certificate,
                // > Extended key usage does not match certificate usage, Root is not trusted;
                errors.append(underlying)
            }

            let alert = UIAlertController(title: "Could not make secure connection", message: errors.map { $0.localizedDescription }.joined(separator: "\n\n"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Trust Certificate", style: .destructive, handler: { [self] _ in
                authDetails.exceptions.add(for: secTrust)
                confirm(secTrust: secTrust, completionHandler: completionHandler)
            }))

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                pendingResolver.reject(OnboardingAuthError(kind: .sslUntrusted(errors)))
                completionHandler(.rejectProtectionSpace, nil)
            }))

            sender.present(alert, animated: true)
        }
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let pendingResolver = pendingResolver else {
            completionHandler(.rejectProtectionSpace, nil)
            return
        }

        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            guard let secTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.rejectProtectionSpace, nil)
                return
            }

            confirm(secTrust: secTrust, completionHandler: completionHandler)
        case NSURLAuthenticationMethodHTTPBasic:
            pendingResolver.reject(OnboardingAuthError(kind: .basicAuth))
            completionHandler(.rejectProtectionSpace, nil)
        case NSURLAuthenticationMethodClientCertificate:
            clientCertificateErrorOccurred = true
            completionHandler(.performDefaultHandling, nil)
        default:
            pendingResolver.reject(OnboardingAuthError(kind: .authenticationUnsupported(challenge.protectionSpace.authenticationMethod)))
            completionHandler(.rejectProtectionSpace, nil)
        }
    }
}
