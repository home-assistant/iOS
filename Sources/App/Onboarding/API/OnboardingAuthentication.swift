import Alamofire
import AuthenticationServices
import Foundation
import HAKit
import PromiseKit
import Shared

class OnboardingAuthentication: NSObject {
    static func successController() -> UIViewController {
        OnboardingPermissionViewControllerFactory.next()
    }

    static func failureController(error: Error) -> UIViewController {
        OnboardingErrorViewController(error: error)
    }

    static func authenticate(to instance: DiscoveredHomeAssistant, sender: UIViewController) -> Promise<Void> {
        firstly { () -> Promise<ConnectionInfo> in
            connectionInfo(for: instance)
        }.then { connectionInfo -> Promise<(HomeAssistantAPI, HAConnection)> in
            firstly { () -> Promise<String> in
                openInBrowser(url: connectionInfo.activeURL, sender: sender)
            }.then { code -> Promise<(HomeAssistantAPI, HAConnection)> in
                configuredAPI(code: code, connectionInfo: connectionInfo)
            }
        }.then { api, connection -> Promise<(HomeAssistantAPI, HAConnection)> in
            checkDeviceName(connection: connection, sender: sender).map { (api, connection) }
        }.then { api, connection -> Promise<Void> in
            connect(api: api, connection: connection)
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

    private static func openInBrowser(url baseURL: URL, sender: UIViewController) -> Promise<String> {
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

            var delegate: PresentationDelegate? = PresentationDelegate(view: sender.view)
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

    private static func configuredAPI(
        code: String,
        connectionInfo: ConnectionInfo
    ) -> Promise<(HomeAssistantAPI, HAConnection)> {
        Current.Log.verbose()
        let tokenManager = TokenManager(tokenInfo: nil, forcedConnectionInfo: connectionInfo)
        let token: Promise<Void> = tokenManager.initialTokenWithCode(code).asVoid()

        return token.get {
            Current.Log.verbose()
            Current.settingsStore.connectionInfo = connectionInfo

            withExtendedLifetime(tokenManager) {
                // just making it exist longer
            }

            Current.resetAPI()
            Current.apiConnection.connect()
        }.then {
            Current.api.map { ($0, Current.apiConnection) }
        }
    }

    private static func connect(api: HomeAssistantAPI, connection: HAConnection) -> Promise<Void> {
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

            Current.onboardingObservation.didConnect()
        }
    }

    // MARK: - Device dedupe

    struct RegisteredDevice {
        var name: String
        var id: String

        init?(data: HAData) throws {
            self.name = try data.decode("name")
            self.id = try {
                let identifiers: [[String]] = try data.decode("identifiers")
                for identifier in identifiers {
                    if identifier.count == 2, identifier.starts(with: ["mobile_app"]) {
                        return identifier[1]
                    }
                }

                throw HADataError.couldntTransform(key: "identifiers")
            }()
        }

        func matches(name other: String) -> Bool {
            name.lowercased() == other.lowercased()
        }
    }

    private static func checkDeviceName(connection: HAConnection, sender: UIViewController) -> Promise<Void> {
        firstly { () -> Promise<[HAData]> in
            connection.send(.init(type: "config/device_registry/list")).promise.compactMap {
                if case let .array(value) = $0 {
                    return value
                } else {
                    return nil
                }
            }
        }.compactMapValues { value -> RegisteredDevice? in
            try? RegisteredDevice(data: value)
        }.recover { _ in
            .value([])
        }.then { registeredDevices -> Promise<Void> in
            guard !registeredDevices.contains(where: { $0.id == Current.settingsStore.integrationDeviceID }) else {
                // if the integration is registered already, we will take over that one, so we don't need to look
                return .value(())
            }

            return promptForDeviceName(
                deviceName: Current.device.deviceName(),
                registeredDevices: registeredDevices,
                sender: sender
            )
        }
    }

    private static func promptForDeviceName(
        deviceName: String,
        registeredDevices: [RegisteredDevice],
        sender: UIViewController
    ) -> Promise<Void> {
        guard registeredDevices.contains(where: { $0.matches(name: deviceName) }) else {
            // if the device name is not already taken, we can safely use it and don't need to prompt
            return .value(())
        }

        return Promise<Void> { seal in
            let alert = UIAlertController(
                title: L10n.Onboarding.DeviceNameCheck.Error.title(deviceName),
                message: L10n.Onboarding.DeviceNameCheck.Error.prompt,
                preferredStyle: .alert
            )

            alert.addTextField { textField in
                textField.keyboardType = .default
                textField.placeholder = Current.device.deviceName()
                textField.text = Current.device.deviceName()
                textField.enablesReturnKeyAutomatically = true
                textField.autocapitalizationType = .words
            }

            alert.addAction(.init(title: L10n.cancelLabel, style: .cancel, handler: { _ in
                Current.api.map(\.tokenManager)
                    .then { $0.revokeToken().asVoid() }
                    .ensure {
                        Current.settingsStore.tokenInfo = nil
                        Current.settingsStore.connectionInfo = nil
                        Current.apiConnection.disconnect()
                    }.recover { _ in
                        Guarantee<Void>.value(())
                    }.done {
                        seal.reject(PMKError.cancelled)
                    }
            }))

            alert
                .addAction(.init(
                    title: L10n.Onboarding.DeviceNameCheck.Error.renameAction,
                    style: .default,
                    handler: { _ in
                        let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces)

                        guard let name = name, name.isEmpty == false,
                              !registeredDevices.contains(where: { $0.matches(name: name) }) else {
                            promptForDeviceName(
                                deviceName: name ?? deviceName,
                                registeredDevices: registeredDevices,
                                sender: sender
                            ).pipe(to: seal.resolve)
                            return
                        }

                        Current.settingsStore.overrideDeviceName = name
                        seal.fulfill(())
                    }
                ))

            sender.present(alert, animated: true, completion: nil)
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
