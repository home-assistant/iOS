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
            
            Current.Log.info("Testing mTLS requirement for: \(baseURL)")
            
            var request = URLRequest(url: baseURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 10
            
            let delegate = ClientCertTestDelegate()
            let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
            
            let task = session.dataTask(with: request) { data, response, error in
                Current.Log.info("mTLS test - clientCertRequested: \(delegate.clientCertificateRequested), response: \(String(describing: response)), error: \(String(describing: error))")
                
                // Check if delegate detected client cert request
                if delegate.clientCertificateRequested {
                    Current.Log.info("mTLS detected via delegate")
                    seal.fulfill(true)
                    return
                }
                
                // Check for HTTP 400 with "SSL certificate" message (nginx response)
                if let httpResponse = response as? HTTPURLResponse, 
                   httpResponse.statusCode == 400 {
                    if let data = data, 
                       let body = String(data: data, encoding: .utf8),
                       body.contains("SSL certificate") {
                        Current.Log.info("mTLS detected via 400 response")
                        seal.fulfill(true)
                        return
                    }
                }
                
                // Check for specific SSL errors
                if let error = error as? URLError {
                    // NSURLErrorClientCertificateRequired = -1206
                    // NSURLErrorClientCertificateRejected = -1205
                    if error.errorCode == -1206 || error.errorCode == -1205 {
                        Current.Log.info("mTLS detected via URLError: \(error.errorCode)")
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
// Accepts ANY server certificate to allow the connection to proceed
private class ClientCertTestDelegate: NSObject, URLSessionDelegate {
    var clientCertificateRequested = false
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let method = challenge.protectionSpace.authenticationMethod
        Current.Log.info("mTLS test received challenge: \(method)")
        
        if method == NSURLAuthenticationMethodClientCertificate {
            clientCertificateRequested = true
            // Cancel - we just needed to detect it
            completionHandler(.cancelAuthenticationChallenge, nil)
        } else if method == NSURLAuthenticationMethodServerTrust {
            // Accept ANY server certificate for this test
            if let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
