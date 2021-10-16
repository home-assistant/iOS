import Alamofire
import AuthenticationServices
import Foundation
import PromiseKit
import Shared

class OnboardingAuthentication: NSObject {
    static func successController() -> UIViewController {
        OnboardingPermissionWorkflowController().next()
    }

    static func failureController(error: Error) -> UIViewController {
        OnboardingErrorViewController(error: error)
    }

    static func authenticate(to instance: DiscoveredHomeAssistant, sender: UIView) -> Promise<Void> {
        firstly { () -> Promise<ConnectionInfo> in
            connectionInfo(for: instance)
        }.then { connectionInfo -> Promise<HomeAssistantAPI> in
            firstly { () -> Promise<String> in
                openInBrowser(url: connectionInfo.activeURL, sender: sender)
            }.then { code -> Promise<HomeAssistantAPI> in
                configuredAPI(code: code, connectionInfo: connectionInfo)
            }
        }.then { api -> Promise<Void> in
            connect(to: api)
        }
    }

    // MARK: - Authentication Session

    private struct AuthDetails {
        var url: URL
        var scheme: String
    }

    private static func authDetails(from baseURL: URL) -> Promise<AuthDetails> {
        Promise<AuthDetails> { seal in
            guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
                throw OnboardingAuthenticationError(kind: .invalidURL)
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
                throw OnboardingAuthenticationError(kind: .invalidURL)
            }

            seal.fulfill(.init(url: authURL, scheme: scheme))
        }
    }

    private static func openInBrowser(url baseURL: URL, sender: UIView) -> Promise<String> {
        Current.Log.verbose(baseURL)

        class PresentationDelegate: NSObject, ASWebAuthenticationPresentationContextProviding {
            let view: UIView
            init(view: UIView) {
                self.view = view
                super.init()
            }

            func presentationAnchor(for: ASWebAuthenticationSession) -> ASPresentationAnchor {
                view.window ?? UIWindow()
            }
        }

        return authDetails(from: baseURL).then { authDetails -> Promise<String> in
            let (promise, resolver) = Promise<String>.pending()
            let session = ASWebAuthenticationSession(
                url: authDetails.url,
                callbackURLScheme: authDetails.scheme,
                completionHandler: { url, error in
                    if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                        resolver.reject(PMKError.cancelled)
                    } else {
                        resolver.resolve(error, url.flatMap(code(fromSuccess:)))
                    }
                }
            )

            var delegate: PresentationDelegate? = PresentationDelegate(view: sender)
            var presentationSession: ASWebAuthenticationSession? = session

            if #available(iOS 13.0, *) {
                session.presentationContextProvider = delegate
                session.prefersEphemeralWebBrowserSession = true
            }

            session.start()

            promise.ensure {
                // keep the session and its presentation context around until it's done
                withExtendedLifetime(presentationSession) { /* avoiding warnings of write-only */ }

                delegate = nil
                presentationSession = nil
            }.cauterize()

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

    // MARK: - Authorizing

    private static func configuredAPI(code: String, connectionInfo: ConnectionInfo) -> Promise<HomeAssistantAPI> {
        Current.Log.verbose()
        let tokenManager = TokenManager(tokenInfo: nil, forcedConnectionInfo: connectionInfo)
        return firstly {
            tokenManager.initialTokenWithCode(code).asVoid()
        }.then { _ -> Promise<HomeAssistantAPI> in
            Current.Log.verbose()
            Current.settingsStore.connectionInfo = connectionInfo

            withExtendedLifetime(tokenManager) {
                // just making it exist longer
            }

            Current.resetAPI()
            return Current.api
        }
    }

    private static func connect(to api: HomeAssistantAPI) -> Promise<Void> {
        Current.Log.verbose()
        return firstly {
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
            Current.apiConnection.connect()
        }
    }

    // MARK: - URL Validation/Testing

    private static func validate(url: URL) -> Promise<Void> {
        Current.Log.verbose()

        let (promise, resolver) = Promise<Void>.pending()

        var clientCertificateErrorOccurred: Bool = false

        let eventMonitor = with(ClosureEventMonitor()) {
            $0.taskDidReceiveChallenge = { _, task, challenge in
                Current.Log.verbose(challenge.protectionSpace.authenticationMethod)

                let errorKind: OnboardingAuthenticationError.ErrorKind? = {
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
                    resolver.reject(OnboardingAuthenticationError(kind: errorKind, data: nil))
                    task.cancel()
                }
            }
        }

        let session = Session(eventMonitors: [eventMonitor])
        session.request(url).validate().response { response in
            Current.Log.info(response)

            resolver.resolve(response.result.map { _ in () }.mapError { wrapper -> Error in
                let kind: OnboardingAuthenticationError.ErrorKind
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

                return OnboardingAuthenticationError(kind: kind, data: response.data)
            })

            withExtendedLifetime(session) {
                // keep the session alive
            }
        }

        return promise
    }

    private static func connectionInfo(for instance: DiscoveredHomeAssistant) -> Promise<ConnectionInfo> {
        firstly {
            authDetails(from: instance.internalOrExternalURL)
        }.then { authDetails in
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
                   $0.internalURL != nil, $0.externalURL != nil {
                    $0.overrideActiveURLType = .internal
                }
            }
        }
    }
}
