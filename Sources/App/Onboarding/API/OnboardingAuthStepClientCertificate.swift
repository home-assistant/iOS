import Foundation
import PromiseKit
import Shared
import SwiftUI
import UniformTypeIdentifiers

/// Pre-step that detects if server requires client certificate and prompts user to import
final class OnboardingAuthStepClientCertificate: OnboardingAuthPreStep {
    static let supportedPoints: Set<OnboardingAuthStepPoint> = [.beforeAuth]

    let authDetails: OnboardingAuthDetails
    weak var sender: UIViewController?

    required init(authDetails: OnboardingAuthDetails, sender: UIViewController) {
        self.authDetails = authDetails
        self.sender = sender
    }

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Current.Log.info("[mTLS] OnboardingAuthStepClientCertificate starting")
        return testConnection().then { [self] requiresClientCert -> Promise<Void> in
            Current.Log.info("[mTLS] Test result: requiresClientCert = \(requiresClientCert)")
            if requiresClientCert {
                return promptForCertificate()
            } else {
                return .value(())
            }
        }
    }

    private func testConnection() -> Promise<Bool> {
        Promise { seal in
            // Get base URL
            var components = URLComponents(url: authDetails.url, resolvingAgainstBaseURL: false)
            components?.path = "/"
            components?.queryItems = nil

            guard let baseURL = components?.url else {
                Current.Log.error("[mTLS] Failed to construct base URL")
                seal.fulfill(false)
                return
            }

            Current.Log.info("[mTLS] Testing connection to: \(baseURL.absoluteString)")

            var request = URLRequest(url: baseURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 15

            let delegate = ClientCertTestDelegate()
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 15
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

            let task = session.dataTask(with: request) { data, response, error in
                Current.Log
                    .info(
                        "[mTLS] Response received - error: \(String(describing: error)), statusCode: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
                    )

                // Check HTTP 400 with nginx SSL certificate message
                if let httpResponse = response as? HTTPURLResponse {
                    Current.Log.info("[mTLS] HTTP status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 400 {
                        if let data, let body = String(data: data, encoding: .utf8) {
                            Current.Log.info("[mTLS] Response body: \(body.prefix(200))")
                            if body.contains("SSL certificate") || body.contains("client certificate") {
                                Current.Log.info("[mTLS] Detected mTLS requirement via 400 response")
                                seal.fulfill(true)
                                return
                            }
                        }
                        // Even without the specific message, 400 on root might indicate mTLS
                        Current.Log.info("[mTLS] Got 400 but no SSL certificate message")
                    }
                }

                // Check for SSL errors
                if let error = error as? URLError {
                    Current.Log.info("[mTLS] URLError code: \(error.errorCode)")
                    if error.errorCode == -1206 || error.errorCode == -1205 {
                        Current.Log.info("[mTLS] Detected mTLS via error code")
                        seal.fulfill(true)
                        return
                    }
                }

                // Check delegate
                if delegate.clientCertificateRequested {
                    Current.Log.info("[mTLS] Detected via delegate")
                    seal.fulfill(true)
                    return
                }

                Current.Log.info("[mTLS] No mTLS requirement detected")
                seal.fulfill(false)
            }
            task.resume()
        }
    }

    private func promptForCertificate() -> Promise<Void> {
        Current.Log.info("[mTLS] Showing certificate import prompt")
        return Promise { [weak self] seal in
            guard let self, let sender else {
                seal.reject(OnboardingAuthError(kind: .clientCertificateRequired))
                return
            }

            DispatchQueue.main.async {
                let view = ClientCertificateOnboardingView(
                    onImport: { [weak self] certificate in
                        Current.Log.info("[mTLS] Certificate imported: \(certificate.displayName)")
                        self?.authDetails.clientCertificate = certificate
                        sender.dismiss(animated: true) {
                            seal.fulfill(())
                        }
                    },
                    onCancel: {
                        Current.Log.info("[mTLS] Certificate import cancelled")
                        sender.dismiss(animated: true) {
                            seal.reject(OnboardingAuthError(kind: .clientCertificateRequired))
                        }
                    }
                )

                let hostingController = UIHostingController(
                    rootView: NavigationView { view }
                        .navigationViewStyle(.stack)
                )
                hostingController.modalPresentationStyle = .pageSheet

                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.medium()]
                    sheet.prefersGrabberVisible = false
                }

                sender.present(hostingController, animated: true)
            }
        }
    }
}

private class ClientCertTestDelegate: NSObject, URLSessionDelegate {
    var clientCertificateRequested = false

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let method = challenge.protectionSpace.authenticationMethod
        Current.Log.info("[mTLS] Delegate received challenge: \(method)")

        if method == NSURLAuthenticationMethodClientCertificate {
            clientCertificateRequested = true
            completionHandler(.cancelAuthenticationChallenge, nil)
        } else if method == NSURLAuthenticationMethodServerTrust {
            // Accept any server certificate for this test
            if let trust = challenge.protectionSpace.serverTrust {
                Current.Log.info("[mTLS] Accepting server trust")
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
