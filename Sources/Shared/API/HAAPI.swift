//
//  HAAPI.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Alamofire
import PromiseKit
import CoreLocation
import Foundation
import KeychainAccess
import ObjectMapper
import RealmSwift
import UserNotifications
import Intents
import Version
import UIKit
#if os(iOS)
import Reachability
#endif

private let keychain = Constants.Keychain

// swiftlint:disable file_length

// swiftlint:disable:next type_body_length
public class HomeAssistantAPI {
    public enum APIError: Error, Equatable {
        case managerNotAvailable
        case invalidResponse
        case cantBuildURL
        case notConfigured
        case updateNotPossible
        case mobileAppComponentNotLoaded
        case mustUpgradeHomeAssistant(Version)
        case unknown
    }

    static let minimumRequiredVersion = Version(major: 0, minor: 92, patch: 2)
    public static let didConnectNotification = Notification.Name(rawValue: "HomeAssistantAPIConnected")

    let prefs = UserDefaults(suiteName: Constants.AppGroupID)!

    public static var LoadedComponents = [String]()

    public private(set) var manager: Alamofire.Session!
    public static var unauthenticatedManager: Alamofire.Session = {
        return configureSessionManager()
    }()

    public var MobileAppComponentLoaded: Bool {
        return HomeAssistantAPI.LoadedComponents.contains("mobile_app")
    }

    let tokenManager: TokenManager

    public func connectionInfo() throws -> ConnectionInfo {
        if let connectionInfo = Current.settingsStore.connectionInfo {
            return connectionInfo
        } else {
            throw HomeAssistantAPI.APIError.notConfigured
        }
    }

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
    public init(tokenInfo: TokenInfo, urlConfig: URLSessionConfiguration = .default) {
        self.tokenManager = TokenManager(tokenInfo: tokenInfo)
        let manager = HomeAssistantAPI.configureSessionManager(
            urlConfig: urlConfig,
            interceptor: newInterceptor()
        )
        self.manager = manager

        removeOldDownloadDirectory()

        Current.sensors.register(observer: self)
    }

    private static func configureSessionManager(
        urlConfig: URLSessionConfiguration = .default,
        interceptor: Interceptor = .init()
    ) -> Session {
        let configuration = urlConfig

        var headers = configuration.httpAdditionalHeaders ?? [:]
        headers["User-Agent"] = Self.userAgent
        configuration.httpAdditionalHeaders = headers

        return Alamofire.Session(configuration: configuration, interceptor: interceptor)
    }

    private func newInterceptor() -> Interceptor {
        .init(
            adapters: [
                Adapter { [weak self] request, session, completion in
                    guard let self = self else {
                        completion(.success(request))
                        return
                    }

                    do {
                        let connectionInfo = try self.connectionInfo()
                        connectionInfo.adapt(request, for: session, completion: completion)
                    } catch {
                        completion(.failure(error))
                    }
                }
            ], retriers: [

            ], interceptors: [
                tokenManager.authenticationInterceptor,
                RetryPolicy()
            ]
        )
    }

    func authenticatedSessionManager() -> Alamofire.Session? {
        guard Current.settingsStore.connectionInfo != nil && Current.settingsStore.tokenInfo != nil else {
            return nil
        }

        return HomeAssistantAPI.configureSessionManager(
            interceptor: newInterceptor()
        )
    }

    convenience init?() {
        guard Current.settingsStore.connectionInfo != nil else {
            return nil
        }

        guard let tokenInfo = Current.settingsStore.tokenInfo else {
            return nil
        }

        self.init(tokenInfo: tokenInfo, urlConfig: .default)
    }

    public func VideoStreamer() -> MJPEGStreamer? {
        guard let newManager = self.authenticatedSessionManager() else {
            return nil
        }

        return MJPEGStreamer(manager: newManager)
    }

    public enum ConnectReason {
        case cold
        case warm
        case periodic

        var updateSensorTrigger: LocationUpdateTrigger {
            switch self {
            case .cold, .warm:
                return .Launch
            case .periodic:
                return .Periodic
            }
        }
    }

    public func Connect(reason: ConnectReason) -> Promise<Void> {
        return firstly {
            self.UpdateRegistration()
        }.recover { error -> Promise<MobileAppRegistrationResponse> in
            switch error as? WebhookError {
            case .unmappableValue,
                 .unexpectedType,
                 .unacceptableStatusCode(404),
                 .unacceptableStatusCode(410):
                // cloudhook will send a 404 for deleted
                // ha directly will send a 200 with an empty body for deleted

                let message = "Integration is missing; registering."
                Current.clientEventStore.addEvent(ClientEvent(text: message, type: .networkRequest, payload: [
                    "error": String(describing: error)
                ]))
                return self.Register()
            case .noApi,
                 .unregisteredIdentifier,
                 .unacceptableStatusCode,
                 .none:
                // not a WebhookError, or not one we think requires reintegration
                Current.Log.info("not re-registering, but failed to update registration: \(error)")
                throw error
            }
        }.then { _ in
            return when(fulfilled: [
                self.GetConfig().asVoid(),
                Current.modelManager.fetch(),
                self.UpdateSensors(trigger: reason.updateSensorTrigger).asVoid(),
                self.updateComplications(passively: false).asVoid()
            ]).asVoid()
        }.get { _ in
            NotificationCenter.default.post(name: Self.didConnectNotification,
                                            object: nil, userInfo: nil)
        }
    }

    public func CreateEvent(eventType: String, eventData: [String: Any]) -> Promise<Void> {
        let intent = FireEventIntent(eventName: eventType, payload: eventData)
        INInteraction(intent: intent, response: nil).donate(completion: nil)

        return Current.webhooks.send(
            identifier: .unhandled,
            request: .init(type: "fire_event", data: [
                "event_type": eventType,
                "event_data": eventData
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
        return Promise { seal in

            var finalURL = url

            let dataManager: Alamofire.Session = needsAuth ? self.manager : Self.unauthenticatedManager

            if needsAuth {
                let activeURL = try connectionInfo().activeURL

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
                return (downloadPath, [.removePreviousFile, .createIntermediateDirectories])
            }

            dataManager.download(finalURL, to: destination).validate().responseData { downloadResponse in
                switch downloadResponse.result {
                case .success:
                    seal.fulfill(downloadResponse.fileURL!)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    public func GetConfig(_ useWebhook: Bool = true) -> Promise<ConfigResponse> {
        let promise: Promise<ConfigResponse>

        if useWebhook {
            promise = Current.webhooks.sendEphemeral(request: .init(type: "get_config", data: [:]))
        } else {
            promise = request(path: "config", callingFunctionName: "\(#function)")
        }

        return promise.then { config -> Promise<ConfigResponse> in
            HomeAssistantAPI.LoadedComponents = config.Components

            guard self.MobileAppComponentLoaded else {
                Current.Log.error("mobile_app component is not loaded!")
                throw HomeAssistantAPI.APIError.mobileAppComponentNotLoaded
            }

            let connectionInfo = try self.connectionInfo()
            connectionInfo.cloudhookURL = config.CloudhookURL
            connectionInfo.setAddress(config.RemoteUIURL, .remoteUI)

            self.prefs.setValue(config.LocationName, forKey: "location_name")
            self.prefs.setValue(config.Latitude, forKey: "latitude")
            self.prefs.setValue(config.Longitude, forKey: "longitude")
            self.prefs.setValue(config.TemperatureUnit, forKey: "temperature_unit")
            self.prefs.setValue(config.LengthUnit, forKey: "length_unit")
            self.prefs.setValue(config.MassUnit, forKey: "mass_unit")
            self.prefs.setValue(config.PressureUnit, forKey: "pressure_unit")
            self.prefs.setValue(config.VolumeUnit, forKey: "volume_unit")
            self.prefs.setValue(config.Timezone, forKey: "time_zone")
            self.prefs.setValue(config.Version, forKey: "version")
            self.prefs.setValue(config.ThemeColor, forKey: "themeColor")

            Current.crashReporter.setUserProperty(value: config.Version, name: "HA_Version")

            return Promise.value(config)
        }
    }

    public func GetEvents() -> Promise<[EventsResponse]> {
        return self.request(path: "events", callingFunctionName: "\(#function)")
    }

    public func GetStates() -> Promise<[Entity]> {
        return self.request(path: "states", callingFunctionName: "\(#function)")
    }

    public func GetScenes() -> Promise<[Scene]> {
        return self.request(path: "states", callingFunctionName: "\(#function)")
    }

    public func GetServices() -> Promise<[ServicesResponse]> {
        return self.request(path: "services", callingFunctionName: "\(#function)")
    }

    public func CallService(domain: String, service: String, serviceData: [String: Any],
                            shouldLog: Bool = true) -> Promise<Void> {
        let intent = CallServiceIntent(domain: domain, service: service, payload: serviceData)
        INInteraction(intent: intent, response: nil).donate(completion: nil)

        return Current.webhooks.send(
            identifier: .serviceCall,
            request: .init(type: "call_service", data: [
                "domain": domain,
                "service": service,
                "service_data": serviceData
            ])
        )
    }

    public enum TemplateError: LocalizedError {
        case unknownError
        case error(String)

        public var errorDescription: String? {
            switch self {
            case .error(let error): return error
            case .unknownError: return L10n.HaApi.ApiError.unknown
            }
        }
    }

    public func RenderTemplate(templateStr: String, variables: [String: Any] = [:]) -> Promise<Any> {
        return firstly { () -> Promise<Any> in
            Current.webhooks.sendEphemeral(
                request: .init(type: "render_template", data: [
                    "tpl": [
                        "template": templateStr,
                        "variables": variables
                    ]
                ])
            )
        }.map { value in
            if let value = value as? [String: Any], let rendered = value["tpl"] {
                return rendered
            } else {
                throw TemplateError.unknownError
            }
        }.get { value in
            if let value = value as? [String: Any], let error = value["error"] as? String {
                // the only error response for the template is {"error": "message"}
                throw TemplateError.error(error)
            }
        }
    }

    public func GetCameraImage(cameraEntityID: String) -> Promise<UIImage> {
        return Promise { seal in
            let connectionInfo = try self.connectionInfo()

            let queryUrl = connectionInfo.activeAPIURL.appendingPathComponent("camera_proxy/\(cameraEntityID)")
            _ = manager.request(queryUrl)
                .validate()
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        if let image = UIImage(data: data) {
                            seal.fulfill(image)
                        }
                    case .failure(let error):
                        Current.Log.error("Error when attemping to GetCameraImage(): \(error)")
                        seal.reject(error)
                    }
                }
        }
    }

    public func Register() -> Promise<MobileAppRegistrationResponse> {
        return self.request(path: "mobile_app/registrations", callingFunctionName: "\(#function)", method: .post,
                            parameters: buildMobileAppRegistration(), encoding: JSONEncoding.default)
            .then { (resp: MobileAppRegistrationResponse) -> Promise<MobileAppRegistrationResponse> in
                Current.Log.verbose("Registration response \(resp)")

                let connectionInfo = try self.connectionInfo()
                connectionInfo.setAddress(resp.RemoteUIURL, .remoteUI)
                connectionInfo.cloudhookURL = resp.CloudhookURL
                connectionInfo.webhookID = resp.WebhookID
                connectionInfo.webhookSecret = resp.WebhookSecret

                return Promise.value(resp)
        }
    }

    public func UpdateRegistration() -> Promise<MobileAppRegistrationResponse> {
        Current.webhooks.sendEphemeral(request: .init(
            type: "update_registration",
            data: buildMobileAppUpdateRegistration()
        ))
    }

    public func GetZones() -> Promise<[Zone]> {
        Current.webhooks.sendEphemeral(request: .init(type: "get_zones", data: [:]))
    }

    public func GetMobileAppConfig() -> Promise<MobileAppConfig> {
        return firstly { () -> Promise<MobileAppConfig> in
            if let version = Current.serverVersion(), version < .actionSyncing {
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
        Current.webhooks.sendEphemeral(request: .init(
            type: "stream_camera",
            data: ["camera_entity_id": entityId]
        ))
    }

    private func buildMobileAppRegistration() -> [String: Any] {
        let ident = mobileAppRegistrationRequestModel()
        var json = Mapper().toJSON(ident)

        if let version = Current.serverVersion(), version < .canSendDeviceID {
            // device_id was added in 0.104, but prior it would error for unknown keys
            json.removeValue(forKey: "device_id")
        }

        return json
    }

    private func mobileAppRegistrationRequestModel() -> MobileAppRegistrationRequest {
        return with(MobileAppRegistrationRequest()) {
            if let pushID = Current.settingsStore.pushID {
                $0.AppData = [
                    "push_url": "https://mobile-apps.home-assistant.io/api/sendPushNotification",
                    "push_token": pushID
                ]
            }

            $0.AppIdentifier = Constants.BundleID
            $0.AppName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            $0.AppVersion = HomeAssistantAPI.clientVersionDescription
            $0.DeviceID = Current.settingsStore.integrationDeviceID
            $0.DeviceName = Current.settingsStore.overrideDeviceName ?? Current.device.deviceName()
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

    public func SubmitLocation(updateType: LocationUpdateTrigger,
                               location: CLLocation?, zone: RLMZone?) -> Promise<Void> {
        firstly {
            .value(WebhookUpdateLocation(
                trigger: updateType,
                location: location,
                zone: zone
            ))
        }.map { (update: WebhookUpdateLocation?) -> WebhookUpdateLocation in
            if let update = update {
                return update
            } else {
                throw HomeAssistantAPI.APIError.updateNotPossible
            }
        }.get { payload in
            let realm = Current.realm()
            try realm.write {
                var jsonPayload = "{\"missing\": \"payload\"}"
                if let p = payload.toJSONString(prettyPrint: false) {
                    jsonPayload = p
                }

                realm.add(LocationHistoryEntry(updateType: updateType, location: payload.cllocation,
                                               zone: zone, payload: jsonPayload))
            }
        }.map { payload -> [String: Any] in
            let payloadDict: [String: Any] = Mapper<WebhookUpdateLocation>().toJSON(payload)
            Current.Log.info("Location update payload: \(payloadDict)")
            return payloadDict
        }.then { payload in
            return when(resolved:
                self.UpdateSensors(trigger: updateType, location: location).asVoid(),
                Current.webhooks.send(
                    identifier: .location,
                    request: .init(
                        type: "update_location",
                        data: payload,
                        localMetadata: WebhookResponseLocation.localMetdata(
                            trigger: updateType,
                            zone: zone
                        )
                    )
                )
            )
        }.asVoid()
    }

    public func GetAndSendLocation(
        trigger: LocationUpdateTrigger?,
        zone: RLMZone? = nil,
        maximumBackgroundTime: TimeInterval? = nil
    ) -> Promise<Void> {
        var updateTrigger: LocationUpdateTrigger = .Manual
        if let trigger = trigger {
            updateTrigger = trigger
        }
        Current.Log.verbose("getAndSendLocation called via \(String(describing: updateTrigger))")

        return firstly { () -> Promise<CLLocation> in
            return CLLocationManager.oneShotLocation(
                timeout: updateTrigger.oneShotTimeout(maximum: maximumBackgroundTime)
            )
        }.then { location in
            self.SubmitLocation(updateType: updateTrigger, location: location, zone: zone)
        }.asVoid()
    }

    private func sendLocalNotification(withZone: RLMZone?, updateType: LocationUpdateTrigger,
                                       payloadDict: [String: Any]) {
        let zoneName = withZone?.Name ?? "Unknown zone"
        let notificationOptions = updateType.notificationOptionsFor(zoneName: zoneName)
        Current.clientEventStore.addEvent(ClientEvent(text: notificationOptions.body, type: .locationUpdate,
                                                      payload: payloadDict))
        if notificationOptions.shouldNotify {
            let content = UNMutableNotificationContent()
            content.title = notificationOptions.title
            content.body = notificationOptions.body
            content.sound = UNNotificationSound.default

            let notificationRequest =
                UNNotificationRequest.init(identifier: notificationOptions.identifier ?? "",
                                           content: content, trigger: nil)
            UNUserNotificationCenter.current().add(notificationRequest)
        }
    }

    public class var sharedEventDeviceInfo: [String: String] { [
        "sourceDevicePermanentID": Constants.PermanentID,
        "sourceDeviceName": Current.settingsStore.overrideDeviceName ?? Current.device.deviceName(),
        "sourceDeviceID": Current.settingsStore.deviceID
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

    public class func notificationActionEvent(
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

    public class func actionEvent(
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

    public class func actionScene(
        actionID: String,
        source: ActionSource
    ) -> (serviceDomain: String, serviceName: String, serviceData: [String: String]) {
        return (serviceDomain: "scene", serviceName: "turn_on", serviceData: [ "entity_id": actionID ])
    }

    public class func tagEvent(
        tagPath: String
    ) -> (eventType: String, eventData: [String: String]) {
        var eventData = [String: String]()
        eventData["tag_id"] = tagPath
        if let version = Current.serverVersion(), version < .tagWebhookAvailable {
            eventData["device_id"] = Current.settingsStore.integrationDeviceID
        }
        return (eventType: "tag_scanned", eventData: eventData)
    }

    @available(watchOS, unavailable)
    public class func zoneStateEvent(
        region: CLRegion,
        state: CLRegionState,
        zone: RLMZone
    ) -> (eventType: String, eventData: [String: Any]) {
        var eventData: [String: Any] = sharedEventDeviceInfo
        eventData["zone"] = zone.ID
        if region.identifier.contains("@"), let subId = region.identifier.split(separator: "@").last {
            eventData["multi_region_zone_id"] = String(subId)
        }
        if state == .inside {
            return (eventType: "ios.zone_entered", eventData: eventData)
        } else {
            return (eventType: "ios.zone_exited", eventData: eventData)
        }
    }

    public class func shareEvent(
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

    public func handlePushAction(
        identifier: String,
        category: String?,
        userInfo: [AnyHashable: Any],
        userInput: String?
    ) -> Promise<Void> {
        let action = Self.notificationActionEvent(
            identifier: identifier,
            category: category,
            actionData: userInfo["homeassistant"],
            textInput: userInput
        )

        Current.Log.verbose("Sending action: \(action.eventType) payload: \(action.eventData)")

        return Current.api.then { api in
            api.CreateEvent(eventType: action.eventType, eventData: action.eventData)
        }
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
            let actionInfo = Self.actionEvent(actionID: action.ID, actionName: action.Name, source: source)
            Current.Log.verbose("Sending action: \(actionInfo.eventType) payload: \(actionInfo.eventData)")

            return Current.api.then { api in
                api.CreateEvent(
                    eventType: actionInfo.eventType,
                    eventData: actionInfo.eventData
                )
            }
        case .scene:
            let serviceInfo = Self.actionScene(actionID: action.ID, source: source)
            Current.Log.verbose("activating scene: \(action.ID)")

            return Current.api.then { api in
                api.CallService(
                    domain: serviceInfo.serviceDomain,
                    service: serviceInfo.serviceName,
                    serviceData: serviceInfo.serviceData
                )
            }
        }
    }

    public func RegisterSensors() -> Promise<Void> {
        return firstly {
            Current.sensors.sensors(reason: .registration).map(\.sensors)
        }.get { sensors in
            Current.Log.verbose("Registering sensors \(sensors.map { $0.UniqueID  })")
        }.thenMap { sensor in
            Current.webhooks.send(request: .init(type: "register_sensor", data: sensor.toJSON()))
        }.tap { result in
            Current.Log.info("finished registering sensors: \(result)")
        }.asVoid()
    }

    public func UpdateSensors(trigger: LocationUpdateTrigger,
                              location: CLLocation? = nil) -> Promise<Void> {
        return firstly {
            Current.sensors.sensors(
                reason: .trigger(trigger.rawValue),
                location: location
            )
        }.map { sensorResponse -> (SensorResponse, [[String: Any]]) in
            Current.Log.info("updating sensors \(sensorResponse.sensors.map { $0.UniqueID ?? "unknown" })")
            let mapper = Mapper<WebhookSensor>(
                context: WebhookSensorContext(update: true),
                shouldIncludeNilValues: false
            )
            return (sensorResponse, mapper.toJSONArray(sensorResponse.sensors))
        }.then { (sensorResponse, payload) -> Promise<Void> in
            firstly { () -> Promise<Void> in
                if payload.isEmpty {
                    Current.Log.info("skipping network request for unchanged sensor update")
                    return .value(())
                } else {
                    return Current.webhooks.send(
                        identifier: .updateSensors,
                        request: .init(type: "update_sensor_states", data: payload)
                    )
                }
            }.done {
                sensorResponse.didPersist()
            }
        }
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
        case .mustUpgradeHomeAssistant(let current):
            return L10n.HaApi.ApiError.mustUpgradeHomeAssistant(current.description,
                                                                HomeAssistantAPI.minimumRequiredVersion.description)
        case .unknown:
            return L10n.HaApi.ApiError.unknown
        }
    }
}

extension HomeAssistantAPI: SensorObserver {
    public func sensorContainerDidSignalForUpdate(_ container: SensorContainer) {
        Current.backgroundTask(withName: "signaled-update-sensors") { _ in
            UpdateSensors(trigger: .Signaled)
        }.cauterize()
    }

    public func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        // we don't do anything for this
    }
}
