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
        testConnection().then { [self] requiresClientCert -> Promise<Void> in
            if requiresClientCert {
                Current.Log.info("Server requires client certificate (mTLS)")
                return promptForCertificate()
            } else {
                return .value(())
            }
        }
    }
    
    private func testConnection() -> Promise<Bool> {
        Promise { seal in
            // Get base URL (strip /auth/authorize path)
            var components = URLComponents(url: authDetails.url, resolvingAgainstBaseURL: false)
            components?.path = "/"
            components?.queryItems = nil
            
            guard let baseURL = components?.url else {
                seal.fulfill(false)
                return
            }
            
            var request = URLRequest(url: baseURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 10
            
            let delegate = ClientCertTestDelegate(exceptions: authDetails.exceptions)
            let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
            
            let task = session.dataTask(with: request) { _, _, error in
                if delegate.clientCertificateRequested {
                    seal.fulfill(true)
                    return
                }
                
                if let error = error as? URLError {
                    // NSURLErrorClientCertificateRequired = -1206
                    // NSURLErrorClientCertificateRejected = -1205
                    if error.errorCode == -1206 || error.errorCode == -1205 {
                        seal.fulfill(true)
                        return
                    }
                }
                
                seal.fulfill(false)
            }
            task.resume()
        }
    }
    
    private func promptForCertificate() -> Promise<Void> {
        Promise { [weak self] seal in
            guard let self = self, let sender = self.sender else {
                seal.reject(OnboardingAuthError(kind: .clientCertificateRequired))
                return
            }
            
            DispatchQueue.main.async {
                let view = ClientCertificateOnboardingView(
                    onImport: { [weak self] certificate in
                        self?.authDetails.clientCertificate = certificate
                        sender.dismiss(animated: true) {
                            seal.fulfill(())
                        }
                    },
                    onCancel: {
                        sender.dismiss(animated: true) {
                            seal.reject(OnboardingAuthError(kind: .clientCertificateRequired))
                        }
                    }
                )
                
                let hostingController = UIHostingController(rootView: NavigationView { view })
                hostingController.modalPresentationStyle = .pageSheet
                
                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.medium(), .large()]
                    sheet.prefersGrabberVisible = true
                }
                
                sender.present(hostingController, animated: true)
            }
        }
    }
}

// Delegate to detect client certificate requirement
private class ClientCertTestDelegate: NSObject, URLSessionDelegate {
    let exceptions: SecurityExceptions
    var clientCertificateRequested = false
    
    init(exceptions: SecurityExceptions) {
        self.exceptions = exceptions
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            clientCertificateRequested = true
            completionHandler(.cancelAuthenticationChallenge, nil)
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let result = exceptions.evaluate(challenge)
            completionHandler(result.0, result.1)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
