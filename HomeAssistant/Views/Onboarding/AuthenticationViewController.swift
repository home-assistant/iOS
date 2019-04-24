//
//  AuthenticationViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/22/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Shared
import PromiseKit
import Alamofire
import MaterialComponents.MaterialButtons

class AuthenticationViewController: UIViewController {

    var instance: DiscoveredHomeAssistant!
    var connectionInfo: ConnectionInfo?
    var tokenManager: TokenManager?

    @IBOutlet weak var connectButton: MDCButton!
    @IBOutlet weak var goBackButton: MDCButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let navVC = self.navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(self.connectButton)
            navVC.styleButton(self.goBackButton)
        }

        guard let baseURL = self.instance.BaseURL else {
            fatalError("No base URL is set in discovery, this should not be possible!")
        }

        firstly {
            return self.testConnection(baseURL)
        }.done {
            self.connectionInfo = ConnectionInfo(baseURL: baseURL, internalBaseURL: nil, internalSSIDs: nil,
                                                 basicAuthCredentials: nil)
        }.catch { error in
            Current.Log.error("Error during connection test \(error.localizedDescription)")
        }
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "setupInstance", let vc = segue.destination as? ConnectInstanceViewController {
            vc.instance = self.instance
            vc.connectionInfo = self.connectionInfo
            vc.tokenManager = self.tokenManager
        }
    }

    @IBAction func connectButtonTapped(_ sender: Any) {
        guard let connectionInfo = self.connectionInfo else {
            Current.Log.error("self.connectionInfo isnt available!")
            return
        }
        Current.Log.verbose("Attempting browser auth to: \(connectionInfo.activeURL)")
        let url = connectionInfo.activeURL
        AuthenticationController().authenticateWithBrowser(at: url).then { (code: String) -> Promise<String> in
            Current.Log.verbose("Browser auth succeeded, getting token")
            let tokenManager = TokenManager(connectionInfo: connectionInfo, tokenInfo: nil)
            self.tokenManager = tokenManager
            return tokenManager.initialTokenWithCode(code)
        }.then { (token: String) -> Promise<ConfigResponse> in
            Current.Log.verbose("Got confirmed token \(token)")

            Current.tokenManager = self.tokenManager

            return HomeAssistantAPI(connectionInfo: connectionInfo,
                                    tokenInfo: Current.settingsStore.tokenInfo!).GetConfig(false)
        }.done { _ in
            Current.settingsStore.connectionInfo = self.connectionInfo
            self.performSegue(withIdentifier: "setupInstance", sender: nil)
        }.catch { error in
            Current.Log.error("Error during auth \(error.localizedDescription)")
        }
    }

    private struct ConnectionTestResult: LocalizedError {
        // swiftlint:disable:next nesting
        enum ErrorKind {
            case basicAuth
            case authenticationUnsupported
            case sslUntrusted
            case sslExpired
            case sslUnknownError
            case clientCertificateRequired
            case connectionError
            case serverError
            case tooOld
            case httpOnly
            case unknownError
        }

        let kind: ErrorKind
        let underlying: Error?

        public var errorDescription: String? {
            var description = "No underlying error"
            if let desc = self.underlying?.localizedDescription {
                description = desc
            }
            switch self.kind {
            case .sslUntrusted:
                return "Untrusted SSL certificate \(description)"
            case .basicAuth:
                return "HTTP Basic auth required"
            case .authenticationUnsupported:
                return "Authentication type is unsupported \(description)"
            case .sslExpired:
                return "SSL certificate is expired"
            case .sslUnknownError:
                return "Unknown SSL error \(description)"
            case .clientCertificateRequired:
                return "Client Certificate Authentication is not supported"
            case .connectionError:
                return "General connection error \(description)"
            case .serverError:
                return "Server error \(description)"
            case .tooOld:
                return "HA Version too old"
            case .httpOnly:
                return "HTTP only instances not supported anymore"
            default:
                return "Unknown error \(description)"
            }
        }
    }

    private func testConnection(_ baseURL: URL) -> Promise<Void> {
        let discoveryInfoURL = baseURL.appendingPathComponent("api/discovery_info")
        return Promise { seal in
            let sessionManager = Alamofire.SessionManager.default
            let delegate: Alamofire.SessionDelegate = sessionManager.delegate
            delegate.taskDidReceiveChallenge = { session, task, challenge in
                let method = challenge.protectionSpace.authenticationMethod
                Current.Log.verbose("Handling challenge \(method)")
                if method == NSURLAuthenticationMethodServerTrust {
                    Current.Log.verbose("Allowing challenge \(method)")
                    return (.performDefaultHandling, nil)
                } else if method == NSURLAuthenticationMethodHTTPBasic {
                    Current.Log.warning("HTTP Basic auth encountered")
                    seal.reject(ConnectionTestResult(kind: .basicAuth, underlying: nil))
                    return (.cancelAuthenticationChallenge, nil)
                } else if method == NSURLAuthenticationMethodClientCertificate {
                    Current.Log.warning("HTTP client certificate encountered")
                    seal.reject(ConnectionTestResult(kind: .clientCertificateRequired, underlying: nil))
                    return (.cancelAuthenticationChallenge, nil)
                } else {
                    Current.Log.warning("Refusing to handle challenge \(challenge)")
                    seal.reject(ConnectionTestResult(kind: .authenticationUnsupported, underlying: nil))
                    return (.cancelAuthenticationChallenge, nil)
                }
            }
            sessionManager.request(discoveryInfoURL).validate().responseJSON { response in
                print("Request: \(String(describing: response.request))")   // original url request
                print("Response: \(String(describing: response.response))") // http url response
                print("Result: \(response.result)")                         // response serialization result
                print("Error: \(response.error)")

                if let error = response.error {
                    let errorCode = (error as NSError).code
                    if errorCode == NSURLErrorServerCertificateUntrusted {
                        seal.reject(ConnectionTestResult(kind: .sslUntrusted, underlying: error))
                        return
                    } else if errorCode == NSURLErrorServerCertificateHasBadDate ||
                        errorCode == NSURLErrorServerCertificateHasUnknownRoot ||
                        errorCode == NSURLErrorServerCertificateNotYetValid {
                        seal.reject(ConnectionTestResult(kind: .sslUnknownError, underlying: error))
                        return
                    }

                    seal.reject(ConnectionTestResult(kind: .unknownError, underlying: error))
                    return
                }

                if let statusCode = response.response?.statusCode, statusCode > 500 {
                    seal.reject(ConnectionTestResult(kind: .serverError, underlying: nil))
                    return
                }

                seal.fulfill_()
            }
        }
    }
}
