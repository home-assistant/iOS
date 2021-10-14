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

                let errorKind: ConnectionTestError.ErrorKind? = {
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
                    resolver.reject(ConnectionTestError(kind: errorKind, data: nil))
                    task.cancel()
                }
            }
        }

        let session = Session(eventMonitors: [eventMonitor])
        lastTestSession = session
        session.request(url).validate().response { response in
            Current.Log.info(response)

            resolver.resolve(response.result.map { _ in () }.mapError { wrapper -> Error in
                let kind: ConnectionTestError.ErrorKind
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

                return ConnectionTestError(kind: kind, data: response.data)
            })
        }

        return promise
    }

    private func connectionInfo(for instance: DiscoveredHomeAssistant) -> Promise<ConnectionInfo> {
        firstly {
            authDetails(from: instance.internalOrExternalURL)
        }.then { [self] authDetails in
            validate(url: authDetails.url)
        }.map {
            with(ConnectionInfo(
                externalURL: instance.externalURL,
                internalURL: instance.internalURL,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "",
                webhookSecret: nil,
                internalSSIDs: Current.connectivity.currentWiFiSSID().map { [$0] },
                internalHardwareAddresses: Current.connectivity.currentNetworkHardwareAddress().map { [$0] },
                isLocalPushEnabled: true
            )) {
                // if we have internal+external, we're on the internal network doing discovery
                // but we don't yet have location permission to know we're on an internal ssid
                if $0.internalSSIDs == [] || $0.internalSSIDs == nil,
                   $0.internalURL != nil && $0.externalURL != nil {
                    $0.overrideActiveURLType = .internal
                }
            }
        }
    }

    // - MARK: ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        lastView?.window ?? UIWindow()
    }
}

public struct ConnectionTestError: LocalizedError {
    enum ErrorKind {
        case basicAuth
        case authenticationUnsupported(String)
        case sslUntrusted(Error)
        case clientCertificateRequired(Error)
        case other(Error)

        var documentationAnchor: String {
            switch self {
            case .basicAuth: return "basic_auth"
            case .authenticationUnsupported: return "authentication_unsupported"
            case .sslUntrusted: return "ssl_untrusted"
            case .clientCertificateRequired: return "client_certificate"
            case .other: return "unknown_error"
            }
        }
    }

    let kind: ErrorKind
    let data: Data?

    public var errorCode: String? {
        switch kind {
        case .basicAuth: return nil
        case .authenticationUnsupported: return nil
        case let .sslUntrusted(underlying as NSError),
            let .clientCertificateRequired(underlying as NSError),
            let .other(underlying as NSError):
            return String(format: "%@ %d", underlying.domain, underlying.code)
        }
    }

    public var errorDescription: String? {
        let base: String = {
            switch kind {
            case .basicAuth:
                return L10n.Onboarding.ConnectionTestResult.BasicAuth.description
            case let .authenticationUnsupported(method):
                return L10n.Onboarding.ConnectionTestResult.AuthenticationUnsupported.description(" " + method)
            case let .clientCertificateRequired(underlying):
                return L10n.Onboarding.ConnectionTestResult.ClientCertificate.description
                    + "\n\n" + underlying.localizedDescription
            case let .sslUntrusted(underlying),
                let .other(underlying):
                return underlying.localizedDescription
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
