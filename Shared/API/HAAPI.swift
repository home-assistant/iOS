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
import DeviceKit
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
    public enum APIError: Error {
        case managerNotAvailable
        case invalidResponse
        case cantBuildURL
        case notConfigured
        case mobileAppComponentNotLoaded
        case webhookGone
        case mustUpgradeHomeAssistant(Version)
        case unacceptableStatusCode(Int)
        case unknown
    }

    static let minimumRequiredVersion = Version(major: 0, minor: 92, patch: 2)
    public static let didConnectNotification = Notification.Name(rawValue: "HomeAssistantAPIConnected")

    let prefs = UserDefaults(suiteName: Constants.AppGroupID)!

    public static var LoadedComponents = [String]()

    public private(set) var manager: Alamofire.SessionManager!
    public static var unauthenticatedManager: Alamofire.SessionManager = {
        return configureSessionManager()
    }()

    public var MobileAppComponentLoaded: Bool {
        return HomeAssistantAPI.LoadedComponents.contains("mobile_app")
    }

    var tokenManager: TokenManager?
    public var connectionInfo: ConnectionInfo

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
            let osName: String = Device.current.systemName ?? "Unknown"
            return "\(osName) \(versionString)"
        }()

        return "Home Assistant/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion))"
    }

    /// Initialize an API object with an authenticated tokenManager.
    public init(connectionInfo: ConnectionInfo, tokenInfo: TokenInfo, urlConfig: URLSessionConfiguration = .default) {
        self.connectionInfo = connectionInfo

        self.tokenManager = TokenManager(connectionInfo: connectionInfo, tokenInfo: tokenInfo)
        let manager = HomeAssistantAPI.configureSessionManager(urlConfig: urlConfig)
        manager.retrier = self.tokenManager
        manager.adapter = self.tokenManager
        self.manager = manager

        removeOldDownloadDirectory()
    }

    private static func configureSessionManager(urlConfig: URLSessionConfiguration = .default) -> SessionManager {
        let configuration = urlConfig

        var headers = configuration.httpAdditionalHeaders ?? [:]
        headers["User-Agent"] = Self.userAgent
        configuration.httpAdditionalHeaders = headers

        return Alamofire.SessionManager(configuration: configuration)
    }

    func authenticatedSessionManager() -> Alamofire.SessionManager? {
        guard Current.settingsStore.connectionInfo != nil && Current.settingsStore.tokenInfo != nil else {
            return nil
        }

        let manager = HomeAssistantAPI.configureSessionManager()
        manager.retrier = self.tokenManager
        manager.adapter = self.tokenManager
        return manager
    }

    private static var sharedAPI: HomeAssistantAPI?

    public static func authenticatedAPI(urlConfig: URLSessionConfiguration = .default,
                                        forceInit: Bool = false) -> HomeAssistantAPI? {
        if let api = sharedAPI, forceInit == false {
            return api
        }

        guard let connectionInfo = Current.settingsStore.connectionInfo else {
            return nil
        }

        if let tokenInfo = Current.settingsStore.tokenInfo {
            let api = HomeAssistantAPI(connectionInfo: connectionInfo,
                                       tokenInfo: tokenInfo, urlConfig: urlConfig)
            self.sharedAPI = api
        }

        return self.sharedAPI
    }

    public static var authenticatedAPIPromise: Promise<HomeAssistantAPI> {
        return Promise { seal in
            if let api = self.authenticatedAPI() {
                seal.fulfill(api)
                return
            }
            seal.reject(APIError.notConfigured)
        }
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
            guard (error as NSError).domain != NSURLErrorDomain, !(error is BackgroundTaskError) else {
                Current.Log.info("not re-registering because of network error")
                throw error
            }

            let message = "Failed to update integration; trying to register instead."
            Current.clientEventStore.addEvent(ClientEvent(text: message, type: .networkRequest, payload: [
                "error": String(describing: error)
            ]))
            return self.Register()
        }.then { _ in
            return when(fulfilled: [
                self.GetConfig().asVoid(),
                Current.modelManager.fetch(),
                self.UpdateSensors(trigger: reason.updateSensorTrigger).asVoid(),
                self.updateComplications().asVoid()
            ]).asVoid()
        }.get { _ in
            NotificationCenter.default.post(name: Self.didConnectNotification,
                                            object: nil, userInfo: nil)
        }
    }

    public func CreateEvent(eventType: String, eventData: [String: Any]) -> Promise<Void> {
        if #available(iOS 12, *) {
            let intent = FireEventIntent(eventName: eventType, payload: eventData)
            INInteraction(intent: intent, response: nil).donate(completion: nil)
        }

        return Current.webhooks.send(
            identifier: .unhandled,
            request: .init(type: "fire_event", data: [
                "event_type": eventType,
                "event_data": eventData
            ])
        )
    }

    private func getTemporaryDownloadDataPath(_ downloadingURL: URL) -> URL? {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(downloadingURL.lastPathComponent, isDirectory: false)
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

            let dataManager: Alamofire.SessionManager = needsAuth ? self.manager : Self.unauthenticatedManager

            if needsAuth {
                if !url.absoluteString.hasPrefix(self.connectionInfo.activeURL.absoluteString) {
                    Current.Log.verbose("URL does not contain base URL, prepending base URL to \(url.absoluteString)")
                    finalURL = self.connectionInfo.activeURL.appendingPathComponent(url.absoluteString)
                }

                Current.Log.verbose("Data download needs auth!")
            }

            guard let downloadPath = self.getTemporaryDownloadDataPath(finalURL) else {
                Current.Log.error("Unable to get download path!")
                seal.reject(APIError.cantBuildURL)
                return
            }

            let destination: DownloadRequest.DownloadFileDestination = { _, _ in
                return (downloadPath, [.removePreviousFile, .createIntermediateDirectories])
            }

            dataManager.download(finalURL, to: destination).responseData { downloadResponse in
                switch downloadResponse.result {
                case .success:
                    seal.fulfill(downloadResponse.destinationURL!)
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

            self.connectionInfo.cloudhookURL = config.CloudhookURL
            self.connectionInfo.setAddress(config.RemoteUIURL, .remoteUI)

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

            Current.setUserProperty?(config.Version, "HA_Version")

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
        if #available(iOS 12, *) {
            let intent = CallServiceIntent(domain: domain, service: service, payload: serviceData)
            INInteraction(intent: intent, response: nil).donate(completion: nil)
        }

        return Current.webhooks.send(
            identifier: .serviceCall,
            request: .init(type: "call_service", data: [
                "domain": domain,
                "service": service,
                "service_data": serviceData
            ])
        )
    }

    public func RenderTemplate(templateStr: String, variables: [String: Any] = [:]) -> Promise<String> {
        let hookPayload: [String: [String: Any]] = ["tpl": ["template": templateStr, "variables": variables]]
        let req: Promise<Any> = Current.webhooks.sendEphemeral(
            request: .init(type: "render_template", data: hookPayload)
        )
        return req.then { (resp: Any) -> Promise<String> in
            guard let jsonDict = resp as? [String: String] else {
                return Promise.value("Error")
            }

            guard let rendered = jsonDict["tpl"] else {
                return Promise.value("Error")
            }

            return Promise.value(rendered)
        }
    }

    public func GetCameraImage(cameraEntityID: String) -> Promise<UIImage> {
        return Promise { seal in
            let queryUrl = self.connectionInfo.activeAPIURL.appendingPathComponent("camera_proxy/\(cameraEntityID)")
            _ = manager.request(queryUrl)
                .validate()
                .responseData { response in
                    switch response.result {
                    case .success:
                        if let data = response.result.value, let image = UIImage(data: data) {
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

                self.connectionInfo.setAddress(resp.RemoteUIURL, .remoteUI)

                self.connectionInfo.cloudhookURL = resp.CloudhookURL
                self.connectionInfo.webhookID = resp.WebhookID
                self.connectionInfo.webhookSecret = resp.WebhookSecret

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
        if Current.serverVersion() < .actionSyncing {
            return firstly { () -> Promise<MobileAppConfigPush> in
                requestImmutable(path: "ios/push", callingFunctionName: "\(#function)")
            }.recover { error -> Promise<MobileAppConfigPush> in
                if case AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404)) = error {
                    Current.Log.info("ios component is not loaded; pretending there's no push config")
                    return .value(.init())
                }

                throw error
            }.map {
                MobileAppConfig(push: $0)
            }
        } else {
            return Current.webhooks.sendEphemeral(request: .init(type: "get_yaml_config", data: [:]))
        }
    }

    public func StreamCamera(entityId: String) -> Promise<StreamCameraResponse> {
        Current.webhooks.sendEphemeral(request: .init(
            type: "stream_camera",
            data: ["camera_entity_id": entityId]
        ))
    }

    private func buildMobileAppRegistration() -> [String: Any] {
        let deviceKitDevice = Device.current

        let ident = MobileAppRegistrationRequest()
        if let pushID = Current.settingsStore.pushID {
            ident.AppData = [
                "push_url": "https://mobile-apps.home-assistant.io/api/sendPushNotification",
                "push_token": pushID
            ]
        }

        ident.AppIdentifier = Constants.BundleID
        ident.AppName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
        ident.AppVersion = HomeAssistantAPI.clientVersionDescription
        ident.DeviceID = Current.settingsStore.integrationDeviceID
        ident.DeviceName = Current.settingsStore.overrideDeviceName ?? deviceKitDevice.name
        ident.Manufacturer = "Apple"
        ident.Model = deviceKitDevice.description
        ident.OSName = deviceKitDevice.systemName
        ident.OSVersion = deviceKitDevice.systemVersion
        ident.SupportsEncryption = true

        var json = Mapper().toJSON(ident)

        if Current.serverVersion() < .canSendDeviceID {
            // device_id was added in 0.104, but prior it would error for unknown keys
            json.removeValue(forKey: "device_id")
        }

        return json
    }

    private func buildMobileAppUpdateRegistration() -> [String: Any] {
        let deviceKitDevice = Device.current

        let ident = MobileAppUpdateRegistrationRequest()
        if let pushID = Current.settingsStore.pushID {
            ident.AppData = [
                "push_url": "https://mobile-apps.home-assistant.io/api/sendPushNotification",
                "push_token": pushID
            ]
        }
        ident.AppVersion = HomeAssistantAPI.clientVersionDescription
        ident.DeviceName = Current.settingsStore.overrideDeviceName ?? deviceKitDevice.name
        ident.Manufacturer = "Apple"
        ident.Model = deviceKitDevice.description
        ident.OSVersion = deviceKitDevice.systemVersion

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
        }.map { payload -> [String: Any] in
            let realm = Current.realm()
            // swiftlint:disable:next force_try
            try! realm.write {
                var jsonPayload = "{\"missing\": \"payload\"}"
                if let p = payload.toJSONString(prettyPrint: false) {
                    jsonPayload = p
                }

                realm.add(LocationHistoryEntry(updateType: updateType, location: payload.cllocation,
                                               zone: zone, payload: jsonPayload))
            }

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
                ),
                self.updateComplications().asVoid()
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

        Current.isPerformingSingleShotLocationQuery = true
        return firstly { () -> Promise<CLLocation> in
            return CLLocationManager.oneShotLocation(
                timeout: updateTrigger.oneShotTimeout(maximum: maximumBackgroundTime)
            )
        }.ensure {
            Current.isPerformingSingleShotLocationQuery = false
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

    private class var sharedEventDeviceInfo: [String: String] { [
        "sourceDevicePermanentID": Constants.PermanentID,
        "sourceDeviceName": Device.current.name ?? "Unknown",
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
        eventData["device_id"] = Current.settingsStore.integrationDeviceID
        return (eventType: "tag_scanned", eventData: eventData)
    }

    public func HandleAction(actionID: String, source: ActionSource) -> Promise<Void> {
        return Promise { seal in
            guard let api = HomeAssistantAPI.authenticatedAPI() else {
                throw APIError.notConfigured
            }

            guard let action = Current.realm().object(ofType: Action.self, forPrimaryKey: actionID) else {
                Current.Log.error("couldn't find action with id \(actionID)")
                throw HomeAssistantAPI.APIError.cantBuildURL
            }

            if #available(iOS 12, *) {
                let intent = PerformActionIntent(action: action)
                INInteraction(intent: intent, response: nil).donate(completion: nil)
            }

            switch action.triggerType {
            case .event:
                let actionInfo = Self.actionEvent(actionID: action.ID, actionName: action.Name, source: source)
                Current.Log.verbose("Sending action: \(actionInfo.eventType) payload: \(actionInfo.eventData)")

                api.CreateEvent(
                    eventType: actionInfo.eventType,
                    eventData: actionInfo.eventData
                ).pipe(to: { seal.resolve($0) })
            case .scene:
                let serviceInfo = Self.actionScene(actionID: action.ID, source: source)
                Current.Log.verbose("activating scene: \(action.ID)")

                api.CallService(
                    domain: serviceInfo.serviceDomain,
                    service: serviceInfo.serviceName,
                    serviceData: serviceInfo.serviceData
                ).pipe(to: { seal.resolve($0) })
            }
        }
    }

    public func RegisterSensors() -> Promise<Void> {
        return firstly {
            Current.sensors.sensors(request: .init(reason: .registration))
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
            Current.sensors.sensors(request: .init(
                reason: .trigger(trigger.rawValue),
                location: location
            ))
        }.map { sensors in
            Current.Log.info("updating sensors \(sensors.map { $0.UniqueID ?? "unknown" })")

            let mapper = Mapper<WebhookSensor>(context: WebhookSensorContext(update: true),
                                               shouldIncludeNilValues: false)
            return mapper.toJSONArray(sensors)
        }.then { (payload) -> Promise<Void> in
            Current.webhooks.send(
                identifier: .updateSensors,
                request: .init(type: "update_sensor_states", data: payload)
            )
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
        case .mobileAppComponentNotLoaded:
            return L10n.HaApi.ApiError.mobileAppComponentNotLoaded
        case .webhookGone:
            return L10n.HaApi.ApiError.webhookGone
        case .mustUpgradeHomeAssistant(let current):
            return L10n.HaApi.ApiError.mustUpgradeHomeAssistant(current.description,
                                                                HomeAssistantAPI.minimumRequiredVersion.description)
        case .unknown, .unacceptableStatusCode:
            return L10n.HaApi.ApiError.unknown
        }
    }
}
