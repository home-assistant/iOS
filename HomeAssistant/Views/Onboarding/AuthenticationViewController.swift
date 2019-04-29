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
import MBProgressHUD

class AuthenticationViewController: UIViewController {

    let authenticationController: AuthenticationController = AuthenticationController()

    var instance: DiscoveredHomeAssistant!
    var connectionInfo: ConnectionInfo?
    var tokenManager: TokenManager?

    var testResult: ConnectionTestResult?

    @IBOutlet weak var whatsAboutToHappenLabel: UILabel!
    @IBOutlet weak var connectButton: MDCButton!
    @IBOutlet weak var goBackButton: MDCButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        MBProgressHUD.showAdded(to: self.view, animated: true)

        if let navVC = self.navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(self.connectButton)
            navVC.styleButton(self.goBackButton)
        }

        guard let baseURL = self.instance.BaseURL else {
            let errMsg = "No base URL is set in discovery, this should not be possible!"
            Current.Log.error(errMsg)
            fatalError(errMsg)
        }

        firstly {
            return self.testConnection(baseURL)
        }.done {
            var ssids: [String] = []
            if let currentSSID = ConnectionInfo.CurrentWiFiSSID {
                ssids.append(currentSSID)
            }
            self.connectionInfo = ConnectionInfo(baseURL: baseURL, internalBaseURL: nil, internalSSIDs: ssids)
            self.whatsAboutToHappenLabel.isHidden = false
            self.connectButton.isHidden = false
        }.ensure {
            MBProgressHUD.hide(for: self.view, animated: true)
        }.catch { error in
            guard let result = error as? ConnectionTestResult else {
                Current.Log.error("Received non-ConnectionTestResult error! \(error)")
                return
            }
            self.testResult = result
            Current.Log.error("Error during connection test \(result.localizedDescription)")
            self.perform(segue: StoryboardSegue.Onboarding.showError)
        }
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueType = StoryboardSegue.Onboarding(segue) else { return }
        if segueType == .setupInstance, let vc = segue.destination as? ConnectInstanceViewController {
            vc.instance = self.instance
            vc.connectionInfo = self.connectionInfo
            vc.tokenManager = self.tokenManager
        } else if segueType == .showError, let vc = segue.destination as? ConnectionErrorViewController {
            vc.error = self.testResult
        }
    }

    @IBAction func connectButtonTapped(_ sender: Any) {
        guard let connectionInfo = self.connectionInfo else {
            Current.Log.error("self.connectionInfo isnt available!")
            return
        }
        Current.Log.verbose("Attempting browser auth to: \(connectionInfo.activeURL)")
        let url = connectionInfo.activeURL
        let tokenManager = TokenManager(connectionInfo: connectionInfo, tokenInfo: nil)
        self.authenticationController.authenticateWithBrowser(at: url).then { (code: String) -> Promise<TokenInfo> in
            Current.Log.verbose("Browser auth succeeded, getting token")
            return tokenManager.initialTokenWithCode(code)
        }.then { tokenInfo -> Promise<ConfigResponse> in
            Current.Log.verbose("Got token info \(tokenInfo)")

            self.tokenManager = tokenManager
            Current.tokenManager = tokenManager

            Current.settingsStore.connectionInfo = self.connectionInfo

            return HomeAssistantAPI(connectionInfo: connectionInfo, tokenInfo: tokenInfo).GetConfig(false)
        }.done { _ in
            self.perform(segue: StoryboardSegue.Onboarding.setupInstance, sender: nil)
        }.catch { error in
            Current.Log.error("Error during auth \(error.localizedDescription)")
        }
    }

    // swiftlint:disable:next function_body_length
    private func testConnection(_ baseURL: URL) -> Promise<Void> {
        let discoveryInfoURL = baseURL.appendingPathComponent("api/discovery_info")
        return Promise { seal in
            let sessionManager = Alamofire.SessionManager.default
            let delegate: Alamofire.SessionDelegate = sessionManager.delegate
            delegate.taskDidReceiveChallengeWithCompletion = { session, task, challenge, completion in
                let method = challenge.protectionSpace.authenticationMethod
                Current.Log.verbose("Handling challenge \(method)")
                if method == NSURLAuthenticationMethodServerTrust {
                    Current.Log.verbose("Allowing challenge \(method)")
                    completion(.performDefaultHandling, nil)
                } else if method == NSURLAuthenticationMethodHTTPBasic {
                    seal.reject(ConnectionTestResult(kind: .basicAuth, underlying: nil))
                    completion(.cancelAuthenticationChallenge, nil)
                } else if method == NSURLAuthenticationMethodClientCertificate {
                    Current.Log.warning("HTTP client certificate encountered")
                    seal.reject(ConnectionTestResult(kind: .clientCertificateRequired, underlying: nil))
                    completion(.cancelAuthenticationChallenge, nil)
                } else {
                    Current.Log.warning("Refusing to handle challenge \(challenge)")
                    seal.reject(ConnectionTestResult(kind: .authenticationUnsupported, underlying: nil))
                    completion(.cancelAuthenticationChallenge, nil)
                }
            }
            sessionManager.request(discoveryInfoURL).validate().responseJSON { response in
                Current.Log.verbose("Request: \(String(describing: response.request))")
                Current.Log.verbose("Response: \(String(describing: response.response))")
                Current.Log.verbose("Result: \(response.result)")
                Current.Log.error("Error: \(response.error)")

                if let error = response.error {
                    let errorCode = (error as NSError).code
                    if errorCode == NSURLErrorServerCertificateUntrusted ||
                        errorCode == NSURLErrorServerCertificateHasUnknownRoot {
                        seal.reject(ConnectionTestResult(kind: .sslUntrusted, underlying: error))
                        return
                    } else if errorCode == NSURLErrorServerCertificateHasBadDate ||
                        errorCode == NSURLErrorServerCertificateNotYetValid {
                        seal.reject(ConnectionTestResult(kind: .sslExpired, underlying: error))
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

public struct ConnectionTestResult: LocalizedError {
    enum ErrorKind: String {
        case basicAuth = "basic_auth"
        case authenticationUnsupported = "authentication_unsupported"
        case sslUntrusted = "ssl_untrusted"
        case sslExpired = "ssl_expired"
        case clientCertificateRequired = "client_certificate"
        case connectionError = "connection_error"
        case serverError = "server_error"
        case tooOld = "too_old"
        case unknownError = "unknown_error"
    }

    let kind: ErrorKind
    let underlying: Error?

    public var errorDescription: String? {
        let description = self.underlying?.localizedDescription ?? ""
        switch self.kind {
        case .sslUntrusted:
            return L10n.Onboarding.ConnectionTestResult.SslUntrusted.description(description)
        case .basicAuth:
            return L10n.Onboarding.ConnectionTestResult.BasicAuth.description
        case .authenticationUnsupported:
            return L10n.Onboarding.ConnectionTestResult.AuthenticationUnsupported.description(description)
        case .sslExpired:
            return L10n.Onboarding.ConnectionTestResult.SslExpired.description
        case .clientCertificateRequired:
            return L10n.Onboarding.ConnectionTestResult.ClientCertificate.description
        case .connectionError:
            return L10n.Onboarding.ConnectionTestResult.ConnectionError.description(description)
        case .serverError:
            return L10n.Onboarding.ConnectionTestResult.ServerError.description(description)
        case .tooOld:
            return L10n.Onboarding.ConnectionTestResult.TooOld.description
        default:
            return L10n.Onboarding.ConnectionTestResult.UnknownError.description(description)
        }
    }

    public var DocumentationURL: URL {
        return URL(string: "https://companion.home-assistant.io/en/misc/errors#\(self.kind.rawValue)")!
    }
}
