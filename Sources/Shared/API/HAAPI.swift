import Alamofire
import CoreLocation
import Foundation
import HAKit
import Intents
import ObjectMapper
import PromiseKit
import RealmSwift
import UIKit
import Version
#if os(iOS)
import Reachability
#endif
#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

public class HomeAssistantAPI {
    public enum APIError: Error, Equatable {
        case managerNotAvailable
        case invalidResponse
        case cantBuildURL
        case notConfigured
        case updateNotPossible
        case mobileAppComponentNotLoaded
        case mustUpgradeHomeAssistant(current: Version, minimum: Version)
        case noAPIAvailable
        case unknown
    }

    struct TokenFetchFailure: LocalizedError {
        let underlyingType: String
        let shouldDisconnectPermanently: Bool

        var errorDescription: String? {
            "Token fetch failed (\(underlyingType))"
        }
    }

    static func tokenFetchFailure(from error: Error) -> TokenFetchFailure {
        let errorType = String(reflecting: type(of: error))
        let errorDescription = String(describing: error)
        let underlyingInfo = "\(errorType): \(errorDescription)"

        return TokenFetchFailure(
            underlyingType: underlyingInfo,
            shouldDisconnectPermanently: error.authenticationAPIError?.shouldRequireReauthentication == true
        )
    }

    public static let didConnectNotification = Notification.Name(rawValue: "HomeAssistantAPIConnected")

    public private(set) var manager: Alamofire.Session!
    public static let unauthenticatedManager: Alamofire.Session = configureSessionManager()

    public let tokenManager: TokenManager
    public var server: Server
    public internal(set) var connection: HAConnection

    public static var clientVersionDescription: String {
        "\(AppConstants.version) (\(AppConstants.build))"
    }

    public static var userAgent: String {
        // This matches Alamofire's generated string, for consistency with the past
        let bundle = AppConstants.BundleID
        let appVersion = AppConstants.version
        let appBuild = AppConstants.build

        let osNameVersion: String = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

            let notCircularReferenceWrapper = DeviceWrapper()
            let osName = notCircularReferenceWrapper.systemName()
            return "\(osName) \(versionString)"
        }()

        return "Home Assistant/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion))"
    }

    /// "Mobile/BUILD_NUMBER" is what CodeMirror sniffs for to decide iOS or not; other things likely look for Safari
    public static var applicationNameForUserAgent: String {
        HomeAssistantAPI.userAgent + " Mobile/HomeAssistant, like Safari"
    }

    /// Initialize an API object with an authenticated tokenManager.
    public init(server: Server, urlConfig: URLSessionConfiguration = .default) {
        self.server = server
        let tokenManager = TokenManager(server: server)
        self.tokenManager = tokenManager

        #if !os(watchOS)
        // Create URLSession for HAKit REST API calls with certificate handling
        Current.Log.info("[mTLS] Creating HAKit URLSession for server: \(server.info.name)")
        Current.Log.info("[mTLS] Has client certificate: \(server.info.connection.clientCertificate != nil)")
        Current.Log.info("[mTLS] Has security exceptions: \(server.info.connection.securityExceptions.hasExceptions)")

        let hakitURLSession: URLSession
        if server.info.connection.clientCertificate != nil || server.info.connection.securityExceptions.hasExceptions {
            // Use HAKit's certificate provider protocol
            Current.Log.info("[mTLS] Using HAKit certificate provider")
            let certificateProvider = HomeAssistantCertificateProvider(server: server)
            let delegate = HAURLSessionDelegate(certificateProvider: certificateProvider)
            let configuration = URLSessionConfiguration.ephemeral
            hakitURLSession = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        } else {
            Current.Log.info("[mTLS] Using default URLSession for HAKit")
            hakitURLSession = URLSession(configuration: .ephemeral)
        }
        #else
        let hakitURLSession = URLSession(configuration: .ephemeral)
        #endif

        let underlyingConnection = HAKit.connection(
            configuration: .init(
                connectionInfo: {
                    do {
                        if let activeURL = server.info.connection.activeURL() {
                            #if !os(watchOS)
                            // Prepare client identity (SecIdentity) for mTLS if configured
                            let clientIdentityProvider: HAConnectionInfo.ClientIdentityProvider?
                            if let clientCert = server.info.connection.clientCertificate {
                                clientIdentityProvider = {
                                    try? ClientCertificateManager.shared.retrieveIdentity(for: clientCert)
                                }
                            } else {
                                clientIdentityProvider = nil
                            }

                            return try .init(
                                url: activeURL,
                                userAgent: HomeAssistantAPI.userAgent,
                                evaluateCertificate: { secTrust, completion in
                                    completion(
                                        Swift.Result<Void, Error> {
                                            try server.info.connection.securityExceptions.evaluate(secTrust)
                                        }
                                    )
                                },
                                clientIdentity: clientIdentityProvider
                            )
                            #else
                            return try .init(
                                url: activeURL,
                                userAgent: HomeAssistantAPI.userAgent,
                                evaluateCertificate: { secTrust, completion in
                                    completion(
                                        Swift.Result<Void, Error> {
                                            try server.info.connection.securityExceptions.evaluate(secTrust)
                                        }
                                    )
                                }
                            )
                            #endif
                        } else {
                            Current.clientEventStore.addEvent(.init(
                                text: "No active URL available to interact with API, please check if you have internal or external URL available, for internal URL you need to specify your network SSID otherwise for security reasons it won't be available.",
                                type: .networkRequest
                            ))
                            Current.Log.error("activeURL was not available when HAAPI called initializer")
                            return nil
                        }
                    } catch {
                        Current.Log.error("couldn't create connection info: \(error)")
                        return nil
                    }
                },
                fetchAuthToken: { completion in
                    tokenManager.bearerToken.done {
                        completion(.success($0.0))
                    }.catch { error in
                        let errorType = String(reflecting: type(of: error))
                        let errorDescription = String(describing: error)
                        Current.Log
                            .error("HAKit token fetch failed with error type: \(errorType), error: \(errorDescription)")
                        completion(.failure(Self.tokenFetchFailure(from: error)))
                    }
                }
            ),
            connectAutomatically: false,
            urlSession: hakitURLSession
        )
        self.connection = RetryAwareHAConnection(underlying: underlyingConnection)
        connection.delegate = self

        #if !os(watchOS)
        // Use custom delegate that supports client certificates (mTLS)
        let sessionDelegate: SessionDelegate = server.info.connection.clientCertificate != nil
            ? ClientCertificateSessionDelegate(server: server)
            : SessionDelegate()
        #else
        let sessionDelegate = SessionDelegate()
        #endif

        let manager = HomeAssistantAPI.configureSessionManager(
            urlConfig: urlConfig,
            delegate: sessionDelegate,
            interceptor: newInterceptor(),
            trustManager: newServerTrustManager()
        )
        self.manager = manager

        removeOldDownloadDirectory()

        Current.sensors.register(observer: self)
    }

    convenience init?() {
        if let server = Current.servers.all.first {
            self.init(server: server, urlConfig: .default)
        } else {
            return nil
        }
    }

    private static func configureSessionManager(
        urlConfig: URLSessionConfiguration = .default,
        delegate: SessionDelegate = SessionDelegate(),
        interceptor: Interceptor = .init(),
        trustManager: ServerTrustManager? = nil
    ) -> Session {
        let configuration = urlConfig

        var headers = configuration.httpAdditionalHeaders ?? [:]
        headers["User-Agent"] = Self.userAgent
        configuration.httpAdditionalHeaders = headers

        return Alamofire.Session(
            configuration: configuration,
            delegate: delegate,
            interceptor: interceptor,
            serverTrustManager: trustManager
        )
    }

    private func newInterceptor() -> Interceptor {
        .init(
            adapters: [
                ServerRequestAdapter(server: server),
            ], retriers: [
            ], interceptors: [
                tokenManager.authenticationInterceptor,
                RetryPolicy(),
            ]
        )
    }

    private func newServerTrustManager() -> ServerTrustManager {
        CustomServerTrustManager(server: server)
    }

    public func VideoStreamer() -> MJPEGStreamer {
        #if !os(watchOS)
        let delegate: SessionDelegate = server.info.connection.clientCertificate != nil
            ? MJPEGCertificateSessionDelegate(server: server)
            : MJPEGStreamerSessionDelegate()
        #else
        let delegate = MJPEGStreamerSessionDelegate()
        #endif
        return MJPEGStreamer(manager: HomeAssistantAPI.configureSessionManager(
            delegate: delegate,
            interceptor: newInterceptor(),
            trustManager: newServerTrustManager()
        ))
    }

    public enum ConnectReason {
        case cold
        case warm
        case periodic
        case background

        var updateSensorTrigger: LocationUpdateTrigger {
            switch self {
            case .cold, .warm, .background:
                return .Launch
            case .periodic:
                return .Periodic
            }
        }
    }

    static func shouldAttemptAutomaticWebSocketConnect(for state: HAConnectionState) -> Bool {
        switch state {
        case .disconnected(reason: .disconnected):
            return true
        case .disconnected(reason: .waitingToReconnect),
             .disconnected(reason: .rejected),
             .connecting,
             .authenticating,
             .ready:
            return false
        }
    }

    public func connectWebSocketIfNeeded() {
        let state = connection.state

        guard Self.shouldAttemptAutomaticWebSocketConnect(for: state) else {
            Current.Log.info("skipping automatic websocket connect while state is \(state)")
            return
        }

        connection.connect()
    }

    public func Connect(reason: ConnectReason) -> Promise<Void> {
        Current.Log.info("running connect for \(reason)")

        // websocket
        connectWebSocketIfNeeded()

        return firstly { () -> Promise<Void> in
            guard !Current.isAppExtension else {
                Current.Log.info("skipping registration changes in extension")
                return Promise<Void>.value(())
            }

            return updateRegistration().asVoid().recover { [self] error -> Promise<Void> in
                switch error as? WebhookError {
                case .unmappableValue,
                     .unexpectedType,
                     .unacceptableStatusCode(404),
                     .unacceptableStatusCode(410):
                    // cloudhook will send a 404 for deleted
                    // ha directly will send a 200 with an empty body for deleted

                    let message = "Integration is missing; registering."
                    Current.clientEventStore
                        .addEvent(ClientEvent(text: message, type: .networkRequest, payload: [
                            "error": String(describing: error),
                        ]))
                    return register()
                case .unregisteredIdentifier,
                     .unacceptableStatusCode,
                     .replaced,
                     .none:
                    // not a WebhookError, or not one we think requires reintegration
                    Current.Log.info("not re-registering, but failed to update registration: \(error)")
                    throw error
                }
            }
        }.then { [self] () -> Promise<Void> in
            var promises: [Promise<Void>] = []

            if !Current.isAppExtension {
                promises.append(getConfig())
                promises.append(Current.modelManager.fetch(apis: [self]))
                promises.append(updateComplications(passively: false).asVoid())
            }

            promises.append(UpdateSensors(trigger: reason.updateSensorTrigger).asVoid())

            return when(fulfilled: promises).asVoid()
        }.get { _ in
            NotificationCenter.default.post(
                name: Self.didConnectNotification,
                object: nil,
                userInfo: nil
            )
        }
    }

    public func CreateEvent(eventType: String, eventData: [String: Any]) -> Promise<Void> {
        let intent = FireEventIntent(eventName: eventType, payload: eventData)
        INInteraction(intent: intent, response: nil).donate(completion: nil)

        return Current.webhooks.sendEphemeral(
            server: server,
            request: .init(type: "fire_event", data: [
                "event_type": eventType,
                "event_data": eventData,
            ])
        )
    }

    public func temporaryDownloadFileURL(appropriateFor downloadingURL: URL? = nil) -> URL? {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            // using a random file name so we always have one, see https://github.com/home-assistant/iOS/issues/1068
            .appendingPathComponent(UUID().uuidString, isDirectory: false)

        if let downloadingURL {
            return url.appendingPathExtension(downloadingURL.pathExtension)
        } else {
            return url
        }
    }

    private func removeOldDownloadDirectory() {
        let fileManager = FileManager.default

        if let downloadDataDir = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.AppGroupID
        )?.appendingPathComponent("downloadedData", isDirectory: true) {
            try? fileManager.removeItem(at: downloadDataDir)
        }
    }

    public func DownloadDataAt(url: URL, needsAuth: Bool) -> Promise<URL> {
        Promise { seal in
            var finalURL = url

            let dataManager: Alamofire.Session = needsAuth ? self.manager : Self.unauthenticatedManager

            if needsAuth {
                guard let activeURL = server.info.connection.activeURL() else {
                    seal.reject(ServerConnectionError.noActiveURL(server.info.name))
                    return
                }

                if !url.absoluteString.hasPrefix(activeURL.absoluteString) {
                    Current.Log.verbose("URL does not contain base URL, prepending base URL to \(url.absoluteString)")
                    finalURL = activeURL.appendingPathComponent(url.absoluteString)
                }

                Current.Log.verbose("Data download needs auth!")
            }

            guard let downloadPath = temporaryDownloadFileURL(appropriateFor: finalURL) else {
                Current.Log.error("Unable to get download path!")
                seal.reject(APIError.cantBuildURL)
                return
            }

            let destination: DownloadRequest.Destination = { _, _ in
                (downloadPath, [.removePreviousFile, .createIntermediateDirectories])
            }

            dataManager.download(finalURL, to: destination).validate().responseData { downloadResponse in
                switch downloadResponse.result {
                case .success:
                    seal.fulfill(downloadResponse.fileURL!)
                case let .failure(error):
                    seal.reject(error)
                }
            }
        }
    }

    public func getConfig() -> Promise<Void> {
        let promise: Promise<ConfigResponse> = Current.webhooks.sendEphemeral(
            server: server,
            request: .init(type: "get_config", data: [:])
        )

        return promise.done { [self] config in
            server.update { serverInfo in
                serverInfo.connection.cloudhookURL = config.CloudhookURL
                serverInfo.connection.set(address: config.RemoteUIURL, for: .remoteUI)
                serverInfo.remoteName = config.LocationName ?? ServerInfo.defaultName
                serverInfo.hassDeviceId = config.hassDeviceId

                if let version = try? Version(hassVersion: config.Version) {
                    serverInfo.version = version
                }
            }

            Current.crashReporter.setUserProperty(value: config.Version, name: "HA_Version")
        }
    }

    public func GetLogbook() -> Promise<[LogbookEntry]> {
        request(path: "logbook", callingFunctionName: "\(#function)")
    }

    public func CallService(
        domain: String,
        service: String,
        serviceData: [String: Any],
        triggerSource: AppTriggerSource,
        shouldLog: Bool = true
    ) -> Promise<Void> {
        let intent = CallServiceIntent(domain: domain, service: service, payload: serviceData)
        INInteraction(intent: intent, response: nil).donate(completion: nil)

        return Current.webhooks.send(
            identifier: .serviceCall,
            server: server,
            request: .init(type: "call_service", data: [
                "domain": domain,
                "service": service,
                "service_data": serviceData,
            ])
        )
    }

    public func turnOnScript(scriptEntityId: String, triggerSource: AppTriggerSource) -> Promise<Void> {
        CallService(domain: Domain.script.rawValue, service: Service.turnOn.rawValue, serviceData: [
            "entity_id": scriptEntityId,
        ], triggerSource: triggerSource)
    }

    public func getCameraSnapshot(cameraEntityID: String) -> Promise<UIImage> {
        Promise { seal in
            guard let queryUrl = server.info.connection.activeAPIURL()?
                .appendingPathComponent("camera_proxy/\(cameraEntityID)") else {
                seal.reject(ServerConnectionError.noActiveURL(server.info.name))
                return
            }
            _ = manager.request(queryUrl)
                .validate()
                .responseData { response in
                    switch response.result {
                    case let .success(data):
                        if let image = UIImage(data: data) {
                            seal.fulfill(image)
                        }
                    case let .failure(error):
                        Current.Log.error("Error when attemping to GetCameraImage(): \(error)")
                        seal.reject(error)
                    }
                }
        }
    }

    public func register() -> Promise<Void> {
        request(
            path: "mobile_app/registrations",
            callingFunctionName: "\(#function)",
            method: .post,
            parameters: buildMobileAppRegistration(),
            encoding: JSONEncoding.default
        ).recover { error -> Promise<MobileAppRegistrationResponse> in
            if case AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404)) = error {
                throw APIError.mobileAppComponentNotLoaded
            }

            throw error
        }.done { [server] (resp: MobileAppRegistrationResponse) in
            Current.Log.verbose("Registration response \(resp)")

            server.update { server in
                server.connection.set(address: resp.RemoteUIURL, for: .remoteUI)
                server.connection.cloudhookURL = resp.CloudhookURL
                server.connection.webhookID = resp.WebhookID
                server.connection.webhookSecret = resp.WebhookSecret
            }
        }
    }

    public func updateRegistration() -> Promise<MobileAppRegistrationResponse> {
        Current.webhooks.sendEphemeral(
            server: server,
            request: .init(
                type: "update_registration",
                data: buildMobileAppUpdateRegistration()
            )
        )
    }

    public func StreamCamera(entityId: String) -> Promise<StreamCameraResponse> {
        Current.webhooks.sendEphemeral(
            server: server,
            request: .init(
                type: "stream_camera",
                data: ["camera_entity_id": entityId]
            )
        )
    }

    private func buildMobileAppRegistration() -> [String: Any] {
        let ident = mobileAppRegistrationRequestModel()
        var json = Mapper().toJSON(ident)

        if server.info.version < .canSendDeviceID {
            // device_id was added in 0.104, but prior it would error for unknown keys
            json.removeValue(forKey: "device_id")
        }

        return json
    }

    private func mobileAppRegistrationRequestModel() -> MobileAppRegistrationRequest {
        with(MobileAppRegistrationRequest()) {
            if let pushID = Current.settingsStore.pushID {
                var appData: [String: Any] = [
                    "push_url": "https://mobile-apps.home-assistant.io/api/sendPushNotification",
                    "push_token": pushID,
                ]

                #if os(iOS) && !targetEnvironment(macCatalyst)
                if #available(iOS 17.2, *) {
                    // Advertise Live Activity support so HA can send activity push tokens
                    // to the relay server. areActivitiesEnabled reflects the user's Settings
                    // toggle and returns true on both iPhone and iPad (iPadOS 17+).
                    appData["supports_live_activities"] = ActivityAuthorizationInfo().areActivitiesEnabled
                    appData["supports_live_activities_frequent_updates"] =
                        ActivityAuthorizationInfo().frequentPushesEnabled

                    // Push-to-start token (stored in Keychain at launch, updated via stream).
                    // The relay server uses this token to start a Live Activity entirely via APNs.
                    if let pushToStartToken = LiveActivityRegistry.storedPushToStartToken {
                        appData["live_activity_push_to_start_token"] = pushToStartToken
                        appData["live_activity_push_to_start_apns_environment"] = Current.apnsEnvironment
                    }
                }
                #endif

                $0.AppData = appData
            }

            $0.AppIdentifier = AppConstants.BundleID
            $0.AppName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            $0.AppVersion = HomeAssistantAPI.clientVersionDescription
            $0.DeviceID = Current.settingsStore.integrationDeviceID
            $0.DeviceName = server.info.setting(for: .overrideDeviceName) ?? Current.device.deviceName()
            $0.Manufacturer = "Apple"
            $0.Model = Current.device.systemModel()
            $0.OSName = Current.device.systemName()
            $0.OSVersion = Current.device.systemVersion()
            $0.SupportsEncryption = true
        }
    }

    private func buildMobileAppUpdateRegistration() -> [String: Any] {
        let registerRequest = mobileAppRegistrationRequestModel()

        let ident = with(MobileAppUpdateRegistrationRequest()) {
            $0.AppData = registerRequest.AppData
            $0.AppVersion = registerRequest.AppVersion
            $0.DeviceName = registerRequest.DeviceName
            $0.Manufacturer = registerRequest.Manufacturer
            $0.Model = registerRequest.Model
            $0.OSVersion = registerRequest.OSVersion
        }

        return Mapper().toJSON(ident)
    }

    public func SubmitLocation(
        updateType: LocationUpdateTrigger,
        location rawLocation: CLLocation?,
        zone: RLMZone?
    ) -> Promise<Void> {
        let update: WebhookUpdateLocation
        let location: CLLocation?
        let localMetadata = WebhookResponseLocation.localMetdata(
            trigger: updateType,
            zone: zone
        )

        switch server.info.setting(for: .locationPrivacy) {
        case .exact:
            update = .init(trigger: updateType, location: rawLocation, zone: zone)
            location = rawLocation
        case .zoneOnly:
            if updateType == .BeaconRegionEnter {
                update = .init(trigger: updateType, usingNameOf: zone)
            } else if let rawLocation {
                // note this is a different zone than the event - e.g. the zone may be the one we are exiting
                update = .init(trigger: updateType, usingNameOf: RLMZone.zone(of: rawLocation, in: server))
            } else {
                update = .init(trigger: updateType)
            }
            location = nil
        case .never:
            update = .init(trigger: updateType)
            location = nil
        }

        return firstly {
            let realm = Current.realm()
            return when(resolved: realm.reentrantWrite {
                let accuracyAuthorization: CLAccuracyAuthorization = CLLocationManager().accuracyAuthorization

                realm.add(LocationHistoryEntry(
                    updateType: updateType,
                    location: location,
                    zone: zone,
                    accuracyAuthorization: accuracyAuthorization,
                    payload: update.toJSONString(prettyPrint: false) ?? "(unknown)"
                ))
            }).asVoid()
        }.map { () -> [String: Any] in
            let payloadDict = Mapper<WebhookUpdateLocation>().toJSON(update)
            Current.Log.info("Location update payload: \(payloadDict)")
            return payloadDict
        }.then { [self] payload in
            when(
                resolved:
                UpdateSensors(trigger: updateType, location: location).asVoid(),
                Current.webhooks.send(
                    identifier: .location,
                    server: server,
                    request: .init(
                        type: "update_location",
                        data: payload,
                        localMetadata: localMetadata
                    )
                )
            )
        }.asVoid()
    }

    public var sharedEventDeviceInfo: [String: String] {
        [
            "sourceDevicePermanentID": AppConstants.PermanentID,
            "sourceDeviceName": server.info.setting(for: .overrideDeviceName) ?? Current.device.deviceName(),
            "sourceDeviceID": Current.settingsStore.deviceID,
        ]
    }

    public func mobileAppNotificationActionEvent(
        identifier: String,
        category: String?,
        actionData: Any?,
        textInput: String?
    ) -> (eventType: String, eventData: [String: Any]) {
        var eventData = [String: Any]()
        eventData["action"] = identifier

        if let actionData {
            eventData["action_data"] = actionData
        }
        if let textInput {
            eventData["reply_text"] = textInput
        }

        return (eventType: "mobile_app_notification_action", eventData: eventData)
    }

    public func actionScene(
        actionID: String,
        source: AppTriggerSource
    ) -> (serviceDomain: String, serviceName: String, serviceData: [String: String]) {
        (
            serviceDomain: Domain.scene.rawValue,
            serviceName: Service.turnOn.rawValue,
            serviceData: ["entity_id": actionID]
        )
    }

    public func tagEvent(
        tagPath: String
    ) -> (eventType: String, eventData: [String: String]) {
        var eventData: [String: String] = sharedEventDeviceInfo
        eventData["tag_id"] = tagPath
        if server.info.version < .tagWebhookAvailable {
            eventData["device_id"] = Current.settingsStore.integrationDeviceID
        }
        return (eventType: "tag_scanned", eventData: eventData)
    }

    public func shareEvent(
        entered: String,
        url: URL?,
        text: String?
    ) -> (eventType: String, eventData: [String: String]) {
        var eventData = sharedEventDeviceInfo
        eventData["entered"] = entered
        eventData["url"] = url?.absoluteString
        eventData["text"] = text

        return (
            eventType: "mobile_app.share",
            eventData: eventData
        )
    }

    public struct PushActionInfo: ImmutableMappable {
        public var identifier: String
        public var category: String?
        public var textInput: String?
        public var actionData: Any?

        public init?(response: UNNotificationResponse) {
            guard response.actionIdentifier != UNNotificationDefaultActionIdentifier else {
                return nil
            }

            self.identifier = UNNotificationContent.uncombinedAction(from: response.actionIdentifier)
            self.category = response.notification.request.content.categoryIdentifier
            self.actionData = response.notification.request.content.userInfo["homeassistant"]
            self.textInput = (response as? UNTextInputNotificationResponse)?.userText
        }

        public init(map: ObjectMapper.Map) throws {
            self.identifier = try map.value("identifier")
            self.category = try? map.value("category")
            self.textInput = try? map.value("textInput")
            self.actionData = try? map.value("actionData")
        }

        public func mapping(map: ObjectMapper.Map) {
            identifier >>> map["identifier"]
            category >>> map["category"]
            textInput >>> map["textInput"]
            actionData >>> map["actionData"]
        }
    }

    public func handlePushAction(for info: PushActionInfo) -> Promise<Void> {
        let action = mobileAppNotificationActionEvent(
            identifier: info.identifier,
            category: info.category,
            actionData: info.actionData,
            textInput: info.textInput
        )
        Current.Log.verbose("Sending action: \(action.eventType) payload: \(action.eventData)")
        return CreateEvent(eventType: action.eventType, eventData: action.eventData)
    }

    public func HandleAction(actionID: String, source: AppTriggerSource) -> Promise<Void> {
        guard let action = Current.realm().object(ofType: Action.self, forPrimaryKey: actionID) else {
            Current.Log.error("couldn't find action with id \(actionID)")
            return .init(error: HomeAssistantAPI.APIError.cantBuildURL)
        }

        let intent = PerformActionIntent(action: action)
        INInteraction(intent: intent, response: nil).donate(completion: nil)

        let serviceInfo = actionScene(actionID: action.ID, source: source)
        Current.Log.verbose("activating scene: \(action.ID)")

        return CallService(
            domain: serviceInfo.serviceDomain,
            service: serviceInfo.serviceName,
            serviceData: serviceInfo.serviceData,
            triggerSource: source
        )
    }

    public func executeActionForDomainType(domain: Domain, entityId: String, state: String) -> Promise<Void> {
        var request: HATypedRequest<HAResponseVoid>?

        // Lock requires state-aware action
        if domain == .lock {
            guard let state = Domain.State(rawValue: state) else { return .value }
            switch state {
            case .unlocking, .unlocked, .opening:
                request = .lockLock(entityId: entityId)
            case .locked, .locking:
                request = .unlockLock(entityId: entityId)
            default:
                break
            }
        } else {
            // Use domain's main action for all other domains
            request = .executeMainAction(domain: domain, entityId: entityId)
        }

        if let request {
            return connection.send(request).promise
                .map { _ in () }
        } else {
            return .value
        }
    }

    public func registerSensors() -> Promise<Void> {
        firstly {
            Current.sensors.sensors(reason: .registration, server: server).map(\.sensors)
        }.get { sensors in
            Current.Log.verbose("Registering sensors \(sensors.map(\.UniqueID))")
        }.thenMap { [server] sensor in
            Current.webhooks.send(server: server, request: .init(type: "register_sensor", data: sensor.toJSON()))
        }.tap { result in
            Current.Log.info("finished registering sensors: \(result)")
        }.asVoid()
    }

    public func UpdateSensors(
        trigger: LocationUpdateTrigger,
        location: CLLocation? = nil
    ) -> Promise<Void> {
        UpdateSensors(trigger: trigger, limitedTo: nil, location: location)
    }

    func UpdateSensors(
        trigger: LocationUpdateTrigger,
        limitedTo: [SensorProvider.Type]?,
        location: CLLocation? = nil
    ) -> Promise<Void> {
        firstly {
            Current.sensors.sensors(
                reason: .trigger(trigger.rawValue),
                limitedTo: limitedTo,
                location: location,
                server: server
            )
        }.map { sensorResponse -> (SensorResponse, [[String: Any]]) in
            Current.Log.info("updating sensors \(sensorResponse.sensors.map { $0.UniqueID ?? "unknown" })")
            let mapper = Mapper<WebhookSensor>(
                context: WebhookSensorContext(update: true),
                shouldIncludeNilValues: false
            )
            return (sensorResponse, mapper.toJSONArray(sensorResponse.sensors))
        }.then { [server] _, payload -> Promise<Void> in
            if payload.isEmpty {
                Current.Log.info("skipping network request for unchanged sensor update")
                return .value(())
            } else {
                return Current.webhooks.send(
                    identifier: .updateSensors,
                    server: server,
                    request: .init(type: "update_sensor_states", data: payload)
                )
            }
        }
    }

    #if os(iOS)
    public enum ManualUpdateType {
        case userRequested
        case appOpened
        case programmatic

        var allowsTemporaryAccess: Bool {
            switch self {
            case .userRequested, .appOpened: return true
            case .programmatic: return false
            }
        }
    }

    public static func manuallyUpdate(
        applicationState: UIApplication.State,
        type: ManualUpdateType
    ) -> Promise<Void> {
        Current.backgroundTask(withName: BackgroundTask.manualLocationUpdate.rawValue) { _ in
            firstly { () -> Guarantee<Void> in
                Guarantee { seal in
                    let locationManager = CLLocationManager()

                    guard locationManager.accuracyAuthorization != .fullAccuracy else {
                        // already have full accuracy, don't need to request
                        return seal(())
                    }

                    guard type.allowsTemporaryAccess else {
                        return seal(())
                    }

                    Current.Log.info("requesting full accuracy for manual update")
                    locationManager.requestTemporaryFullAccuracyAuthorization(
                        withPurposeKey: "TemporaryFullAccuracyReasonManualUpdate"
                    ) { error in
                        Current.Log.info("got temporary full accuracy result: \(String(describing: error))")

                        withExtendedLifetime(locationManager) {
                            seal(())
                        }
                    }
                }
            }.then { () -> Promise<Void> in
                func updateWithoutLocation() -> Promise<Void> {
                    when(fulfilled: Current.apis.map { $0.UpdateSensors(trigger: .Manual) })
                }

                if Current.settingsStore.isLocationEnabled(for: applicationState) {
                    return firstly {
                        Current.location.oneShotLocation(.Manual, nil)
                    }.then { location in
                        when(fulfilled: Current.apis.map { api in
                            api.SubmitLocation(updateType: .Manual, location: location, zone: nil)
                        }).asVoid()
                    }.recover { error -> Promise<Void> in
                        if error is CLError || error is OneShotError {
                            Current.Log.info("couldn't get location, sending remaining sensor data")
                            return updateWithoutLocation()
                        } else {
                            throw error
                        }
                    }
                } else {
                    return updateWithoutLocation()
                }
            }
        }
    }
    #endif

    private final class ProfilePictureCancellable: HACancellable {
        private(set) var isCancelled = false
        private var cancellables = [HACancellable]()
        private var downloadRequest: Request?

        func add(_ cancellable: HACancellable) {
            if isCancelled {
                cancellable.cancel()
            } else {
                cancellables.append(cancellable)
            }
        }

        func setDownloadRequest(_ request: Request) {
            if isCancelled {
                request.cancel()
            } else {
                downloadRequest = request
            }
        }

        func cancel() {
            guard !isCancelled else { return }

            isCancelled = true
            cancellables.forEach { $0.cancel() }
            downloadRequest?.cancel()
            cancellables.removeAll()
            downloadRequest = nil
        }
    }

    @discardableResult
    public func currentUser(completion: @escaping (HAResponseCurrentUser?) -> Void) -> HACancellable {
        connection.send(HATypedRequest<HAResponseCurrentUser>.fetchCurrentUser()) { result in
            switch result {
            case let .success(user):
                completion(user)
            case let .failure(error):
                Current.Log.error("Failed to retrieve current user: \(error)")
                completion(nil)
            }
        }
    }

    @discardableResult
    public func profilePictureURL(
        for user: HAResponseCurrentUser,
        completion: @escaping (URL?) -> Void
    ) -> HACancellable {
        connection.send(HATypedRequest<[HAEntity]>.fetchStates()) { [weak self] result in
            switch result {
            case let .success(states):
                guard let person = states.first(where: { $0.attributes["user_id"] as? String == user.id }) else {
                    Current.Log.error("Profile picture: No person found for user \(user.id)")
                    completion(nil)
                    return
                }

                guard let path = person.attributes["entity_picture"] as? String else {
                    Current.Log.error("Profile picture: Missing URL for user entity picture, user id \(user.id)")
                    completion(nil)
                    return
                }

                guard let url = self?.resolvedProfilePictureURL(from: path) else {
                    Current.Log.error("Profile picture: Invalid URL for user entity picture, user id \(user.id)")
                    completion(nil)
                    return
                }

                completion(url)
            case let .failure(error):
                Current.Log.error("Failed to retrieve states for profile picture: \(error)")
                completion(nil)
            }
        }
    }

    @discardableResult
    public func profilePictureURL(completion: @escaping (URL?) -> Void) -> HACancellable {
        let cancellable = ProfilePictureCancellable()

        cancellable.add(currentUser { [weak self] user in
            guard !cancellable.isCancelled else { return }
            guard let self, let user else {
                completion(nil)
                return
            }

            cancellable.add(profilePictureURL(for: user) { url in
                guard !cancellable.isCancelled else { return }
                completion(url)
            })
        })

        return cancellable
    }

    @discardableResult
    public func profilePicture(
        for user: HAResponseCurrentUser,
        completion: @escaping (UIImage?) -> Void
    ) -> HACancellable {
        let cancellable = ProfilePictureCancellable()

        cancellable.add(profilePictureURL(for: user) { [weak self] url in
            guard !cancellable.isCancelled else { return }
            guard let self, let url else {
                completion(nil)
                return
            }

            let request = manager.download(url).validate()
            cancellable.setDownloadRequest(request)
            request.responseData { response in
                guard !cancellable.isCancelled else { return }
                switch response.result {
                case let .success(data):
                    completion(UIImage(data: data))
                case let .failure(error):
                    Current.Log.error("Failed to download profile picture: \(error)")
                    completion(nil)
                }
            }
        })

        return cancellable
    }

    @discardableResult
    public func profilePicture(completion: @escaping (UIImage?) -> Void) -> HACancellable {
        let cancellable = ProfilePictureCancellable()

        cancellable.add(currentUser { [weak self] user in
            guard !cancellable.isCancelled else { return }
            guard let self, let user else {
                completion(nil)
                return
            }

            cancellable.add(profilePicture(for: user) { image in
                guard !cancellable.isCancelled else { return }
                completion(image)
            })
        })

        return cancellable
    }

    private func resolvedProfilePictureURL(from path: String) -> URL? {
        guard let activeURL = server.info.connection.activeURL() else {
            return nil
        }

        guard let url = URL(string: path, relativeTo: activeURL)?.absoluteURL else {
            return nil
        }

        guard url.hasSameOrigin(as: activeURL) else {
            return nil
        }

        return url
    }
}

private extension URL {
    func hasSameOrigin(as other: URL) -> Bool {
        guard let scheme = scheme?.lowercased(),
              let otherScheme = other.scheme?.lowercased(),
              let host = host?.lowercased(),
              let otherHost = other.host?.lowercased() else {
            return false
        }

        return scheme == otherScheme &&
            host == otherHost &&
            normalizedOriginPort == other.normalizedOriginPort
    }

    private var normalizedOriginPort: Int? {
        if let port {
            return port
        }

        switch scheme?.lowercased() {
        case "http":
            return 80
        case "https":
            return 443
        default:
            return nil
        }
    }
}

#if !os(watchOS)
/// Certificate provider implementation for Home Assistant servers
private class HomeAssistantCertificateProvider: HACertificateProvider {
    private let server: Server

    init(server: Server) {
        self.server = server
    }

    func provideClientCertificate(
        for challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        Current.Log.info("[mTLS HAKit] Client certificate requested")

        guard let clientCertificate = server.info.connection.clientCertificate else {
            Current.Log.warning("[mTLS HAKit] Client certificate requested but none configured")
            completionHandler(.performDefaultHandling, nil)
            return
        }

        do {
            let credential = try ClientCertificateManager.shared.urlCredential(for: clientCertificate)
            Current.Log.info("[mTLS HAKit] Using client certificate: \(clientCertificate.displayName)")
            completionHandler(.useCredential, credential)
        } catch {
            Current.Log.error("[mTLS HAKit] Failed to get credential: \(error)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    func evaluateServerTrust(
        _ serverTrust: SecTrust,
        forHost host: String,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        Current.Log.info("[mTLS HAKit] Evaluating server trust for: \(host)")

        do {
            try server.info.connection.securityExceptions.evaluate(serverTrust)
            Current.Log.info("[mTLS HAKit] Server trust validation successful")
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } catch {
            Current.Log.error("[mTLS HAKit] Server trust validation failed: \(error)")
            completionHandler(.rejectProtectionSpace, nil)
        }
    }
}
#endif

/// Prevents pending websocket work from resetting HAKit's reconnect backoff.
final class RetryAwareHAConnection: HAConnection {
    private let underlying: HAConnection

    weak var delegate: HAConnectionDelegate?

    var configuration: HAConnectionConfiguration {
        get { underlying.configuration }
        set { underlying.configuration = newValue }
    }

    var state: HAConnectionState {
        underlying.state
    }

    var caches: HACachesContainer {
        underlying.caches
    }

    var callbackQueue: DispatchQueue {
        get { underlying.callbackQueue }
        set { underlying.callbackQueue = newValue }
    }

    init(underlying: HAConnection) {
        self.underlying = underlying
        underlying.delegate = self
    }

    func connect() {
        underlying.connect()
    }

    func disconnect() {
        underlying.disconnect()
    }

    @discardableResult
    func send(
        _ request: HARequest,
        completion: @escaping RequestCompletion
    ) -> HACancellable {
        connectIfNeeded(for: request)
        return underlying.send(request, completion: completion)
    }

    @discardableResult
    func send<T>(
        _ request: HATypedRequest<T>,
        completion: @escaping (Swift.Result<T, HAError>) -> Void
    ) -> HACancellable {
        connectIfNeeded(for: request.request)
        return underlying.send(request, completion: completion)
    }

    @discardableResult
    func subscribe(
        to request: HARequest,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        connectIfNeeded(for: request)
        return underlying.subscribe(to: request, handler: handler)
    }

    @discardableResult
    func subscribe(
        to request: HARequest,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        connectIfNeeded(for: request)
        return underlying.subscribe(to: request, initiated: initiated, handler: handler)
    }

    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        connectIfNeeded(for: request.request)
        return underlying.subscribe(to: request, handler: handler)
    }

    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        connectIfNeeded(for: request.request)
        return underlying.subscribe(to: request, initiated: initiated, handler: handler)
    }

    private func connectIfNeeded(for request: HARequest) {
        switch request.type {
        case .rest:
            return
        case .webSocket, .sttData:
            break
        }

        guard HomeAssistantAPI.shouldAttemptAutomaticWebSocketConnect(for: underlying.state) else {
            return
        }

        underlying.connect()
    }
}

extension RetryAwareHAConnection: HAConnectionDelegate {
    func connection(_ connection: HAConnection, didTransitionTo state: HAConnectionState) {
        delegate?.connection(self, didTransitionTo: state)
        NotificationCenter.default.post(
            name: HAConnectionState.didTransitionToStateNotification,
            object: self
        )
    }
}

extension HomeAssistantAPI.APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .managerNotAvailable:
            return L10n.HaApi.ApiError.managerNotAvailable
        case .invalidResponse:
            return L10n.HaApi.ApiError.invalidResponse
        case .cantBuildURL:
            return L10n.HaApi.ApiError.cantBuildUrl
        case .notConfigured:
            return L10n.HaApi.ApiError.notConfigured
        case .updateNotPossible:
            return L10n.HaApi.ApiError.updateNotPossible
        case .mobileAppComponentNotLoaded:
            return L10n.HaApi.ApiError.mobileAppComponentNotLoaded
        case let .mustUpgradeHomeAssistant(current: current, minimum: minimum):
            return L10n.HaApi.ApiError.mustUpgradeHomeAssistant(
                current.description,
                minimum.description
            )
        case .noAPIAvailable:
            return L10n.HaApi.ApiError.noAvailableApi
        case .unknown:
            return L10n.HaApi.ApiError.unknown
        }
    }
}

extension HomeAssistantAPI: SensorObserver {
    public func sensorContainer(
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason,
        lastUpdate: SensorObserverUpdate?
    ) {
        Current.backgroundTask(withName: BackgroundTask.signaledUpdateSensors.rawValue) { _ in
            UpdateSensors(trigger: .Signaled)
        }.cauterize()
    }

    public func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        // we don't do anything for this
    }
}

extension HomeAssistantAPI: HAConnectionDelegate {
    public func connection(_ connection: HAConnection, didTransitionTo state: HAConnectionState) {
        guard case let .disconnected(reason: .waitingToReconnect(lastError: error, atLatest: _, retryCount: _)) = state,
              let tokenFetchFailure = error as? TokenFetchFailure,
              tokenFetchFailure.shouldDisconnectPermanently else {
            return
        }

        Current.Log.info("stopping websocket reconnects after fatal auth token fetch failure")
        connection.disconnect()
    }
}
