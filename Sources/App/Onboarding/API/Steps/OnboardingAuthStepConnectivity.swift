import Foundation
import PromiseKit
import QuickLook
import Shared
import UIKit

class OnboardingAuthStepConnectivity: NSObject, OnboardingAuthPreStep, URLSessionTaskDelegate {
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

    private var taskIdentifierToResolver = [Int: Resolver<Void>]()
    var prepareSessionConfiguration: ((URLSessionConfiguration) -> Void)?

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Current.Log.verbose()

        let (promise, resolver) = Promise<Void>.pending()
        performConnection(resolver: resolver)
        return promise
    }

    private func performConnection(resolver: Resolver<Void>) {
        let configuration = URLSessionConfiguration.ephemeral
        prepareSessionConfiguration?(configuration)
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)

        let (requestPromise, requestResolver) = Promise<(data: Data, response: URLResponse)>.pending()

        let task = session.dataTask(with: authDetails.url) { data, response, error in
            if let data, let response {
                requestResolver.fulfill((data, response))
            } else {
                requestResolver.resolve(nil, error)
            }
        }
        taskIdentifierToResolver[task.taskIdentifier] = resolver
        task.resume()

        requestPromise
            .validate()
            .ensure {
                withExtendedLifetime(session) {
                    // keep the session around
                }
            }
            .map { _ in () }
            .recover { [self] error throws in
                let kind: OnboardingAuthError.ErrorKind
                let data: Data?

                switch error as? PMKHTTPError {
                case let .badStatusCode(_, badStatusCodeData, _):
                    data = badStatusCodeData
                case .none:
                    data = nil
                }

                if clientCertificateRequiredOccurred[task.taskIdentifier] == true {
                    kind = .clientCertificateRequired
                } else if clientCertificateErrorOccurred[task.taskIdentifier] == true {
                    kind = .clientCertificateError(error)
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
            .pipe(to: resolver.resolve)
    }

    private var clientCertificateErrorOccurred = [Int: Bool]()
    private var clientCertificateRequiredOccurred = [Int: Bool]()

    private func confirm(
        secTrust: SecTrust,
        resolver: Resolver<Void>,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        do {
            try authDetails.exceptions.evaluate(secTrust)
            completionHandler(.useCredential, .init(trust: secTrust))
        } catch {
            Current.Log.error("received SSL error: \((error as NSError).debugDescription)")

            var errors = [Error]()
            errors.append(error)

            if let underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error {
                errors.append(underlying)
            }

            // swiftformat:disable:next preferKeyPath
            let alertMessage = errors.map { $0.localizedDescription }.joined(separator: "\n\n")

            let alert = UIAlertController(
                title: L10n.Onboarding.ConnectionTestResult.CertificateError.title,
                message: alertMessage,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(
                title: L10n.Onboarding.ConnectionTestResult.CertificateError.actionTrust,
                style: .destructive,
                handler: { [self] _ in
                    authDetails.exceptions.add(for: secTrust)
                    confirm(secTrust: secTrust, resolver: resolver, completionHandler: completionHandler)
                }
            ))

            alert.addAction(UIAlertAction(
                title: L10n.Onboarding.ConnectionTestResult.CertificateError.actionDontTrust,
                style: .cancel,
                handler: { _ in
                    resolver.reject(OnboardingAuthError(kind: .sslUntrusted(errors)))
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
            ))

            sender.present(alert, animated: true)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let pendingResolver = taskIdentifierToResolver[task.taskIdentifier] else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            guard let secTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            confirm(secTrust: secTrust, resolver: pendingResolver, completionHandler: completionHandler)
        case NSURLAuthenticationMethodHTTPBasic:
            pendingResolver.reject(OnboardingAuthError(kind: .basicAuth))
            completionHandler(.cancelAuthenticationChallenge, nil)
        case NSURLAuthenticationMethodClientCertificate:
            // Use imported client certificate if available
            #if !os(watchOS)
            if let clientCert = authDetails.clientCertificate {
                Current.Log.info("[mTLS] Using client certificate: \(clientCert.displayName)")
                do {
                    let credential = try ClientCertificateManager.shared.urlCredential(for: clientCert)
                    completionHandler(.useCredential, credential)
                    return
                } catch {
                    Current.Log.error("[mTLS] Failed to get credential: \(error)")
                    clientCertificateErrorOccurred[task.taskIdentifier] = true
                    completionHandler(.performDefaultHandling, nil)
                    return
                }
            }
            #endif
            // No certificate available - server requires one
            Current.Log.warning("[mTLS] Client certificate requested but none available")
            clientCertificateRequiredOccurred[task.taskIdentifier] = true
            completionHandler(.performDefaultHandling, nil)
        default:
            pendingResolver
                .reject(OnboardingAuthError(kind: .authenticationUnsupported(
                    challenge.protectionSpace.authenticationMethod
                )))
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
