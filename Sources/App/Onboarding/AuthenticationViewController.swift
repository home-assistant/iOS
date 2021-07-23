import Alamofire
import AuthenticationServices
import MBProgressHUD
import ObjectMapper
import PromiseKit
import Shared
import UIKit

class AuthenticationViewController: UIViewController {
    let authenticationController = OnboardingAuthenticationController()

    var instance: DiscoveredHomeAssistant!
    var connectionInfo: ConnectionInfo?

    var testResult: Error?

    @IBOutlet var whatsAboutToHappenLabel: UILabel!
    @IBOutlet var connectButton: UIButton!
    @IBOutlet var goBackButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 13.0, *) {
            self.authenticationController.asWebContext = self
        }

        MBProgressHUD.showAdded(to: view, animated: true)

        if let navVC = navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(connectButton)
            navVC.styleButton(goBackButton)
        }

        guard let instance = self.instance, let baseURL = instance.BaseURL else {
            let instanceDesc = String(describing: self.instance)
            let errMsg = "No base URL is set in discovery, this should not be possible! \(instanceDesc)"
            Current.Log.error(errMsg)

            testResult = ConnectionTestResult(kind: .noBaseURLDiscovered, underlying: nil, data: nil)
            perform(segue: StoryboardSegue.Onboarding.showError)
            return
        }

        firstly {
            self.testConnection(baseURL)
        }.get { foundInstance in
            self.instance = foundInstance
        }.done { _ in
            let connInfo = ConnectionInfo(
                externalURL: baseURL, internalURL: nil, cloudhookURL: nil, remoteUIURL: nil, webhookID: "",
                webhookSecret: nil, internalSSIDs: Current.connectivity.currentWiFiSSID().map { [$0] },
                internalHardwareAddresses: Current.connectivity.currentNetworkHardwareAddress().map { [$0] },
                isLocalPushEnabled: true
            )

            self.connectionInfo = connInfo

            self.whatsAboutToHappenLabel.isHidden = false
            self.connectButton.isHidden = false
        }.ensure {
            MBProgressHUD.hide(for: self.view, animated: true)
        }.catch { error in
            if let result = error as? ConnectionTestResult {
                Current.Log.error("Received ConnectionTestResult! \(result)")
            } else {
                Current.Log.error("Received non-ConnectionTestResult error! \(error)")
            }
            self.testResult = error
            Current.Log.error("Error during connection test \(error.localizedDescription)")
            self.perform(segue: StoryboardSegue.Onboarding.showError)
        }
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueType = StoryboardSegue.Onboarding(segue) else { return }
        if segueType == .permissions, let vc = segue.destination as? PermissionsViewController {
            vc.instance = instance
            vc.connectionInfo = connectionInfo
        } else if segueType == .showError, let vc = segue.destination as? ConnectionErrorViewController {
            vc.error = testResult
        }
    }

    @IBAction func connectButtonTapped(_ sender: Any) {
        guard let connectionInfo = self.connectionInfo else {
            Current.Log.error("self.connectionInfo isnt available!")
            return
        }
        Current.Log.verbose("Attempting browser auth to: \(connectionInfo.activeURL)")
        let url = connectionInfo.activeURL
        let initialTokenManager = TokenManager(tokenInfo: nil, forcedConnectionInfo: connectionInfo)
        authenticationController.authenticateWithBrowser(at: url).then { (code: String) -> Promise<TokenInfo> in
            Current.Log.verbose("Browser auth succeeded, getting token")
            return initialTokenManager.initialTokenWithCode(code)
        }.then { tokenInfo -> Promise<ConfigResponse> in
            Current.Log.verbose("Got token info \(tokenInfo)")

            Current.settingsStore.connectionInfo = self.connectionInfo

            return HomeAssistantAPI(tokenInfo: tokenInfo).GetConfig(false)
        }.done { _ in
            self.perform(segue: StoryboardSegue.Onboarding.permissions, sender: nil)
        }.catch { error in
            Current.Log.error("Error during auth \(error.localizedDescription)")
            let alert = UIAlertController(
                title: L10n.errorLabel,
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    fileprivate typealias ErrorReason = AFError.ResponseValidationFailureReason

    private var lastTestSession: Session?

    private func testConnection(_ baseURL: URL) -> Promise<DiscoveredHomeAssistant> {
        let discoveryURL = baseURL.appendingPathComponent("api/discovery_info")
        return Promise { seal in
            let eventMonitor = ClosureEventMonitor()
            eventMonitor.taskDidReceiveChallenge = { _, task, challenge in
                let method = challenge.protectionSpace.authenticationMethod
                Current.Log.verbose("Handling challenge \(method)")
                if method == NSURLAuthenticationMethodServerTrust {
                    Current.Log.verbose("Allowing challenge \(method)")
                } else if method == NSURLAuthenticationMethodHTTPBasic {
                    seal.reject(ConnectionTestResult(kind: .basicAuth, underlying: nil, data: nil))
                    task.cancel()
                } else if method == NSURLAuthenticationMethodClientCertificate {
                    Current.Log.warning("HTTP client certificate encountered")
                    seal.reject(ConnectionTestResult(kind: .clientCertificateRequired, underlying: nil, data: nil))
                    task.cancel()
                } else {
                    Current.Log.warning("Refusing to handle challenge \(challenge)")
                    seal.reject(ConnectionTestResult(kind: .authenticationUnsupported, underlying: nil, data: nil))
                    task.cancel()
                }
            }
            let session = Session(eventMonitors: [eventMonitor])
            lastTestSession = session
            session.request(discoveryURL).responseObject { (response: DataResponse<DiscoveredHomeAssistant, AFError>) in
                Current.Log.verbose("Request: \(String(describing: response.request))")
                Current.Log.verbose("Response: \(String(describing: response.response))")
                Current.Log.verbose("Result: \(response.result)")
                Current.Log.error("Error: \(String(describing: response.error))")

                if let statusCode = response.response?.statusCode, statusCode >= 400 {
                    let reason: ErrorReason = .unacceptableStatusCode(code: statusCode)
                    seal.reject(ConnectionTestResult(
                        kind: .serverError,
                        underlying: AFError.responseValidationFailed(reason: reason),
                        data: response.data
                    ))
                    return
                }

                if let error = response.error {
                    let errorCode = (error as NSError).code
                    if errorCode == NSURLErrorServerCertificateUntrusted ||
                        errorCode == NSURLErrorServerCertificateHasUnknownRoot {
                        seal.reject(ConnectionTestResult(
                            kind: .sslUntrusted,
                            underlying: error,
                            data: response.data
                        ))
                        return
                    } else if errorCode == NSURLErrorServerCertificateHasBadDate ||
                        errorCode == NSURLErrorServerCertificateNotYetValid {
                        seal.reject(ConnectionTestResult(
                            kind: .sslExpired,
                            underlying: error,
                            data: response.data
                        ))
                        return
                    }

                    seal.reject(ConnectionTestResult(
                        kind: .unknownError,
                        underlying: error,
                        data: response.data
                    ))
                    return
                }

                switch response.result {
                case let .success(value):
                    seal.fulfill(value)
                case let .failure(error):
                    seal.reject(error)
                }
            }
        }
    }
}

@available(iOS 13, *)
extension AuthenticationViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
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
        case noBaseURLDiscovered = "no_base_url_discovered"
        case unknownError = "unknown_error"
    }

    let kind: ErrorKind
    let underlying: Error?
    let data: Data?

    public var errorDescription: String? {
        let base: String = {
            let description = underlying?.localizedDescription ?? ""
            switch kind {
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
            case .noBaseURLDiscovered:
                return L10n.Onboarding.ConnectionTestResult.NoBaseUrlDiscovered.description
            case .unknownError:
                return L10n.Onboarding.ConnectionTestResult.UnknownError.description(description)
            }
        }()

        if let data = data, let dataString = String(data: data, encoding: .utf8) {
            let displayDataString: String

            let maximumLength = 200
            if dataString.count > maximumLength {
                displayDataString = dataString.prefix(maximumLength - 1) + "…"
            } else {
                displayDataString = dataString
            }

            return base + "\n\n" + displayDataString
        } else {
            return base
        }
    }

    public var DocumentationURL: URL {
        URL(string: "https://companion.home-assistant.io/docs/troubleshooting/errors#\(kind.rawValue)")!
    }
}
