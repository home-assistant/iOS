import Alamofire
import AuthenticationServices
import Foundation
import PromiseKit
import Shared

class OnboardingAuthenticationController: NSObject, ASWebAuthenticationPresentationContextProviding {
    enum AuthenticationControllerError: Error {
        case invalidURL
    }

    private weak var lastView: UIView?
    private var lastTestSession: Session?
    private var authenticationSession: ASWebAuthenticationSession?

    func successController() -> UIViewController {
        PermissionWorkflowController().next()
    }

    func failureController(error: Error) -> UIViewController {
        ConnectionErrorViewController(error: error)
    }

    /// Opens a browser to the URL for obtaining an access code.
    func authenticate(
        from instance: DiscoveredHomeAssistant,
        sender: UIView
    ) -> Promise<Void> {
        lastView = sender
        return firstly { () -> Promise<ConnectionInfo> in
            connectionInfo(for: instance)
        }.then { connectionInfo -> Promise<HomeAssistantAPI> in
            firstly { [self] () -> Promise<String> in
                openInBrowser(url: connectionInfo.activeURL)
            }.then { code -> Promise<Void> in
                Current.Log.info("Browser auth succeeded, getting token")
                let tokenManager = TokenManager(tokenInfo: nil, forcedConnectionInfo: connectionInfo)
                return firstly {
                    tokenManager.initialTokenWithCode(code).asVoid()
                }.done {
                    Current.Log.verbose("Got token, storing & registering")
                    Current.settingsStore.connectionInfo = connectionInfo

                    withExtendedLifetime(tokenManager) {
                        // just making it exist longer
                    }
                }
            }.then { () -> Promise<HomeAssistantAPI> in
                Current.resetAPI()
                return Current.api
            }
        }.then { api -> Promise<Void> in
            firstly {
                api.Register().asVoid()
            }.then {
                when(fulfilled: [
                    api.GetConfig().asVoid(),
                    api.RegisterSensors().asVoid(),
                    Current.modelManager.fetch(),
                ])
            }.done {
                NotificationCenter.default.post(
                    name: HomeAssistantAPI.didConnectNotification,
                    object: nil,
                    userInfo: nil
                )
            }
        }.ensure {
            withExtendedLifetime(self) {
                // so deallocating us doesn't necessarily break callers
            }
        }
    }

    // MARK: - Authentication Session

    struct AuthDetails {
        var url: URL
        var scheme: String
    }

    private func authDetails(from baseURL: URL) -> Promise<AuthDetails> {
        Promise<AuthDetails> { seal in
            guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
                throw AuthenticationControllerError.invalidURL
            }

            let redirectURI: String
            let scheme: String
            let clientID: String

            if Current.appConfiguration == .Debug {
                clientID = "https://home-assistant.io/iOS/dev-auth"
                redirectURI = "homeassistant-dev://auth-callback"
                scheme = "homeassistant-dev"
            } else if Current.appConfiguration == .Beta {
                clientID = "https://home-assistant.io/iOS/beta-auth"
                redirectURI = "homeassistant-beta://auth-callback"
                scheme = "homeassistant-beta"
            } else {
                clientID = "https://home-assistant.io/iOS"
                redirectURI = "homeassistant://auth-callback"
                scheme = "homeassistant"
            }

            components.path += "/auth/authorize"
            components.queryItems = [
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
            ]

            guard let authURL = components.url else {
                throw AuthenticationControllerError.invalidURL
            }

            seal.fulfill(.init(url: authURL, scheme: scheme))
        }
    }

    private func openInBrowser(url baseURL: URL) -> Promise<String> {
        Current.Log.verbose("Attempting browser auth to: \(baseURL)")

        return authDetails(from: baseURL).then { [self] authDetails -> Promise<String> in
            let (promise, resolver) = Promise<String>.pending()
            let session = ASWebAuthenticationSession(
                url: authDetails.url,
                callbackURLScheme: authDetails.scheme,
                completionHandler: { url, error in
                    if let error = error as NSError?,
                       error.domain == ASWebAuthenticationSessionErrorDomain,
                       error.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue {
                        resolver.reject(PMKError.cancelled)
                    } else {
                        resolver.resolve(error, url.flatMap(Self.code(fromSuccess:)))
                    }
                }
            )

            if #available(iOS 13.0, *) {
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = true
            }

            session.start()
            authenticationSession = session
            return promise
        }
    }

    private static func code(fromSuccess url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }

        let parameter = components.queryItems?.first(where: { item -> Bool in
            item.name == "code"
        })

        if let codeParamter = parameter, let code = codeParamter.value {
            Current.Log.verbose("Returning from authentication with code \(code)")
            return code
        }

        return nil
    }

    // MARK: - URL Validation/Testing

    private func validate(url: URL) -> Promise<Void> {
        let (promise, resolver) = Promise<Void>.pending()

        var clientCertificateErrorOccurred: Bool = false

        let eventMonitor = with(ClosureEventMonitor()) {
            $0.taskDidReceiveChallenge = { _, task, challenge in
                Current.Log.verbose("Handling challenge \(challenge.protectionSpace.authenticationMethod)")

                let errorKind: ConnectionTestResult.ErrorKind? = {
                    switch challenge.protectionSpace.authenticationMethod {
                    case NSURLAuthenticationMethodServerTrust: return nil
                    case NSURLAuthenticationMethodHTTPBasic: return .basicAuth
                    case NSURLAuthenticationMethodClientCertificate:
                        clientCertificateErrorOccurred = true
                        return nil
                    default: return .authenticationUnsupported
                    }
                }()

                if let errorKind = errorKind {
                    resolver.reject(ConnectionTestResult(kind: errorKind, underlying: nil, data: nil))
                    task.cancel()
                }
            }
        }

        let session = Session(eventMonitors: [eventMonitor])
        lastTestSession = session
        session.request(url).validate().response { response in
            Current.Log.info(response)

            resolver.resolve(response.result.map { _ in () }.mapError { error -> ConnectionTestResult in
                let errorKind: ConnectionTestResult.ErrorKind = {
                    if clientCertificateErrorOccurred {
                        return .clientCertificateRequired
                    }

                    guard let error = error.underlyingError as NSError?, error.domain == URLError.errorDomain else {
                        return .unknownError
                    }

                    switch URLError.Code(rawValue: error.code) {
                    case URLError.serverCertificateUntrusted, URLError.serverCertificateHasUnknownRoot:
                        return .sslUntrusted
                    case URLError.serverCertificateHasBadDate, URLError.serverCertificateNotYetValid:
                        return .sslExpired
                    default:
                        return .unknownError
                    }
                }()

                let underlying = error.underlyingError ?? error
                return ConnectionTestResult(kind: errorKind, underlying: underlying, data: response.data)
            })
        }

        return promise
    }

    private func connectionInfo(for instance: DiscoveredHomeAssistant) -> Promise<ConnectionInfo> {
        firstly {
            authDetails(from: instance.BaseURL)
        }.then { [self] authDetails in
            validate(url: authDetails.url)
        }.map {
            ConnectionInfo(
                externalURL: instance.BaseURL,
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "",
                webhookSecret: nil,
                internalSSIDs: Current.connectivity.currentWiFiSSID().map { [$0] },
                internalHardwareAddresses: Current.connectivity.currentNetworkHardwareAddress().map { [$0] },
                isLocalPushEnabled: true
            )
        }
    }

    // - MARK: ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        lastView?.window ?? UIWindow()
    }
}

public struct ConnectionTestResult: LocalizedError {
    enum ErrorKind: String {
        case basicAuth = "basic_auth"
        case authenticationUnsupported = "authentication_unsupported"
        case sslUntrusted = "ssl_untrusted"
        case sslExpired = "ssl_expired"
        case clientCertificateRequired = "client_certificate"
        case serverError = "server_error"
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
                if description.isEmpty {
                    return L10n.Onboarding.ConnectionTestResult.SslUntrusted.description(description)
                } else {
                    return description
                }
            case .basicAuth:
                return L10n.Onboarding.ConnectionTestResult.BasicAuth.description
            case .authenticationUnsupported:
                return L10n.Onboarding.ConnectionTestResult.AuthenticationUnsupported.description(description)
            case .sslExpired:
                return L10n.Onboarding.ConnectionTestResult.SslExpired.description
            case .clientCertificateRequired:
                return L10n.Onboarding.ConnectionTestResult.ClientCertificate.description
            case .serverError:
                return L10n.Onboarding.ConnectionTestResult.ServerError.description(description)
            case .unknownError:
                return description
            }
        }()

        if let data = data, let dataString = String(data: data, encoding: .utf8) {
            let displayDataString: String

            let maximumLength = 1024
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
}
