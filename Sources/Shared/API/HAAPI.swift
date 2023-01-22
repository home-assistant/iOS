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

public class HomeAssistantAPI {
    public enum APIError: Error, Equatable {
        case managerNotAvailable
        case invalidResponse
        case cantBuildURL
        case notConfigured
        case updateNotPossible
        case mobileAppComponentNotLoaded
        case mustUpgradeHomeAssistant(current: Version, minimum: Version)
        case unknown
    }

    public static let didConnectNotification = Notification.Name(rawValue: "HomeAssistantAPIConnected")

    public private(set) var manager: Alamofire.Session!
    public static var unauthenticatedManager: Alamofire.Session = configureSessionManager()

    public let tokenManager: TokenManager
    public var server: Server
    public internal(set) var connection: HAConnection

    public static var clientVersionDescription: String {
        "\(Constants.version) (\(Constants.build))"
    }

    public static var userAgent: String {
        // This matches Alamofire's generated string, for consistency with the past
        let bundle = Constants.BundleID
        let appVersion = Constants.version
        let appBuild = Constants.build

        let osNameVersion: String = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

            let notCircularReferenceWrapper = DeviceWrapper()
            let osName = notCircularReferenceWrapper.systemName()
            return "\(osName) \(versionString)"
        }()

        return "Home Assistant/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion))"
    }

    /// Initialize an API object with an authenticated tokenManager.
    public init(server: Server, urlConfig: URLSessionConfiguration = .default) {
        self.server = server
        let tokenManager = TokenManager(server: server)
        self.tokenManager = tokenManager
        self.connection = HAKit.connection(configuration: .init(
            connectionInfo: {
                do {
                    return try .init(
                        url: server.info.connection.activeURL(),
                        userAgent: HomeAssistantAPI.userAgent,
                        evaluateCertificate: { secTrust, completion in
                            completion(
                                Swift.Result<Void, Error> {
                                    try server.info.connection.securityExceptions.evaluate(secTrust)
                                }
                            )
                        }
                    )
                } catch {
                    Current.Log.error("couldn't create connection info: \(error)")
                    return nil
                }
            },
            fetchAuthToken: { completion in
                tokenManager.bearerToken.done {
                    completion(.success($0.0))
                }.catch {
                    completion(.failure($0))
                }
            }
        ))
        let manager = HomeAssistantAPI.configureSessionManager(
            urlConfig: urlConfig,
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
        MJPEGStreamer(manager: HomeAssistantAPI.configureSessionManager(
            delegate: MJPEGStreamerSessionDelegate(),
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

    public func Connect(reason: ConnectReason) -> Promise<Void> {
        Current.Log.info("running connect for \(reason)")

        // websocket
        connection.connect()

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
                    return Current.clientEventStore
                        .addEvent(ClientEvent(text: message, type: .networkRequest, payload: [
                            "error": String(describing: error),
                        ])).then { [self] in
                            register()
                        }
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

        if let downloadingURL = downloadingURL {
            return url.appendingPathExtension(downloadingURL.pathExtension)
        } else {
            return url
        }
    }

    private func removeOldDownloadDirectory() {
        let fileManager = FileManager.default

        if let downloadDataDir = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.AppGroupID
        )?.appendingPathComponent("downloadedData", isDirectory: true) {
            try? fileManager.removeItem(at: downloadDataDir)
        }
    }

    public func DownloadDataAt(url: URL, needsAuth: Bool) -> Promise<URL> {
        Promise { seal in

            var finalURL = url

            let dataManager: Alamofire.Session = needsAuth ? self.manager : Self.unauthenticatedManager

            if needsAuth {
                let activeURL = server.info.connection.activeURL()

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
            server.update { server in
                server.connection.cloudhookURL = config.CloudhookURL
                server.connection.set(address: config.RemoteUIURL, for: .remoteUI)
                server.remoteName = config.LocationName ?? ServerInfo.defaultName

                if let version = try? Version(hassVersion: config.Version) {
                    server.version = version
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

    public func GetCameraImage(cameraEntityID: String) -> Promise<UIImage> {
        Promise { seal in
            let queryUrl = server.info.connection.activeAPIURL()
                .appendingPathComponent("camera_proxy/\(cameraEntityID)")
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

    public func GetMobileAppConfig() -> Promise<MobileAppConfig> {
        firstly { () -> Promise<MobileAppConfig> in
            if server.info.version < .actionSyncing {
                let old: Promise<MobileAppConfigPush> = requestImmutable(
                    path: "ios/push",
                    callingFunctionName: "\(#function)"
                )
                return old.map { MobileAppConfig(push: $0) }
            } else {
                return requestImmutable(path: "ios/config", callingFunctionName: "\(#function)")
            }
        }.recover { error -> Promise<MobileAppConfig> in
            if case AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404)) = error {
                Current.Log.info("ios component is not loaded; pretending there's no push config")
                return .value(.init())
            }

            throw error
        }
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
                $0.AppData = [
                    "push_url": "https://mobile-apps.home-assistant.io/api/sendPushNotification",
                    "push_token": pushID,
                ]
            }

            $0.AppIdentifier = Constants.BundleID
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
            } else if let rawLocation = rawLocation {
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
                let accuracyAuthorization: CLAccuracyAuthorization

                if #available(iOS 14, watchOS 7, *) {
                    accuracyAuthorization = CLLocationManager().accuracyAuthorization
                } else {
                    accuracyAuthorization = .fullAccuracy
                }

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

    public var sharedEventDeviceInfo: [String: String] { [
        "sourceDevicePermanentID": Constants.PermanentID,
        "sourceDeviceName": server.info.setting(for: .overrideDeviceName) ?? Current.device.deviceName(),
        "sourceDeviceID": Current.settingsStore.deviceID,
    ] }

    public enum ActionSource: String, CaseIterable, CustomStringConvertible {
        case Watch = "watch"
        case Widget = "widget"
        case AppShortcut = "appShortcut" // UIApplicationShortcutItem
        case Preview = "preview"
        case SiriShortcut = "siriShortcut"
        case URLHandler = "urlHandler"

        public var description: String {
            rawValue
        }
    }

    public func legacyNotificationActionEvent(
        identifier: String,
        category: String?,
        actionData: Any?,
        textInput: String?
    ) -> (eventType: String, eventData: [String: Any]) {
        var eventData: [String: Any] = sharedEventDeviceInfo
        eventData["actionName"] = identifier

        if let category = category {
            eventData["categoryName"] = category
        }
        if let actionData = actionData {
            eventData["action_data"] = actionData
        }
        if let textInput = textInput {
            eventData["response_info"] = textInput
            eventData["textInput"] = textInput
        }

        return (eventType: "ios.notification_action_fired", eventData: eventData)
    }

    public func mobileAppNotificationActionEvent(
        identifier: String,
        category: String?,
        actionData: Any?,
        textInput: String?
    ) -> (eventType: String, eventData: [String: Any]) {
        var eventData = [String: Any]()
        eventData["action"] = identifier

        if let actionData = actionData {
            eventData["action_data"] = actionData
        }
        if let textInput = textInput {
            eventData["reply_text"] = textInput
        }

        return (eventType: "mobile_app_notification_action", eventData: eventData)
    }

    public func actionEvent(
        actionID: String,
        actionName: String,
        source: ActionSource
    ) -> (eventType: String, eventData: [String: String]) {
        var eventData = sharedEventDeviceInfo
        eventData["actionName"] = actionName
        eventData["actionID"] = actionID
        eventData["triggerSource"] = source.description

        return (eventType: "ios.action_fired", eventData: eventData)
    }

    public func actionScene(
        actionID: String,
        source: ActionSource
    ) -> (serviceDomain: String, serviceName: String, serviceData: [String: String]) {
        return (serviceDomain: "scene", serviceName: "turn_on", serviceData: ["entity_id": actionID])
    }

    public func tagEvent(
        tagPath: String
    ) -> (eventType: String, eventData: [String: String]) {
        var eventData = [String: String]()
        eventData["tag_id"] = tagPath
        if server.info.version < .tagWebhookAvailable {
            eventData["device_id"] = Current.settingsStore.integrationDeviceID
        }
        return (eventType: "tag_scanned", eventData: eventData)
    }

    @available(watchOS, unavailable)
    public func zoneStateEvent(
        region: CLRegion,
        state: CLRegionState,
        zone: RLMZone
    ) -> (eventType: String, eventData: [String: Any]) {
        var eventData: [String: Any] = sharedEventDeviceInfo
        eventData["zone"] = zone.entityId
        if region.identifier.contains("@"), let subId = region.identifier.split(separator: "@").last {
            eventData["multi_region_zone_id"] = String(subId)
        }
        if state == .inside {
            return (eventType: "ios.zone_entered", eventData: eventData)
        } else {
            return (eventType: "ios.zone_exited", eventData: eventData)
        }
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
        let actions = [
            legacyNotificationActionEvent(
                identifier: info.identifier,
                category: info.category,
                actionData: info.actionData,
                textInput: info.textInput
            ),
            mobileAppNotificationActionEvent(
                identifier: info.identifier,
                category: info.category,
                actionData: info.actionData,
                textInput: info.textInput
            ),
        ]

        return when(resolved: actions.map { action -> Promise<Void> in
            Current.Log.verbose("Sending action: \(action.eventType) payload: \(action.eventData)")
            return CreateEvent(eventType: action.eventType, eventData: action.eventData)
        }).asVoid()
    }

    public func HandleAction(actionID: String, source: ActionSource) -> Promise<Void> {
        guard let action = Current.realm().object(ofType: Action.self, forPrimaryKey: actionID) else {
            Current.Log.error("couldn't find action with id \(actionID)")
            return .init(error: HomeAssistantAPI.APIError.cantBuildURL)
        }

        let intent = PerformActionIntent(action: action)
        INInteraction(intent: intent, response: nil).donate(completion: nil)

        switch action.triggerType {
        case .event:
            let actionInfo = actionEvent(actionID: action.ID, actionName: action.Name, source: source)
            Current.Log.verbose("Sending action: \(actionInfo.eventType) payload: \(actionInfo.eventData)")

            return CreateEvent(
                eventType: actionInfo.eventType,
                eventData: actionInfo.eventData
            )
        case .scene:
            let serviceInfo = actionScene(actionID: action.ID, source: source)
            Current.Log.verbose("activating scene: \(action.ID)")

            return CallService(
                domain: serviceInfo.serviceDomain,
                service: serviceInfo.serviceName,
                serviceData: serviceInfo.serviceData
            )
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

    internal func UpdateSensors(
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
        case programmatic

        var allowsTemporaryAccess: Bool {
            switch self {
            case .userRequested: return true
            case .programmatic: return false
            }
        }
    }

    public static func manuallyUpdate(
        applicationState: UIApplication.State,
        type: ManualUpdateType
    ) -> Promise<Void> {
        Current.backgroundTask(withName: "manual-location-update") { _ in
            firstly { () -> Guarantee<Void> in
                Guarantee { seal in
                    guard #available(iOS 14, *) else {
                        return seal(())
                    }

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
                        if error is CLError {
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
        case .unknown:
            return L10n.HaApi.ApiError.unknown
        }
    }
}

extension HomeAssistantAPI: SensorObserver {
    public func sensorContainer(
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason
    ) {
        Current.backgroundTask(withName: "signaled-update-sensors") { _ in
            UpdateSensors(trigger: .Signaled)
        }.cauterize()
    }

    public func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        // we don't do anything for this
    }
}
