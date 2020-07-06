//
//  HAAPI.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Alamofire
import AlamofireImage
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
        case unknown
    }

    static let minimumRequiredVersion = Version(major: 0, minor: 92, patch: 2)
    public static let didConnectNotification = Notification.Name(rawValue: "HomeAssistantAPIConnected")

    let prefs = UserDefaults(suiteName: Constants.AppGroupID)!

    public static var LoadedComponents = [String]()

    public private(set) var manager: Alamofire.SessionManager!

    public var MobileAppComponentLoaded: Bool {
        return HomeAssistantAPI.LoadedComponents.contains("mobile_app")
    }

    var tokenManager: TokenManager?
    public var connectionInfo: ConnectionInfo

    /// Initialize an API object with an authenticated tokenManager.
    public init(connectionInfo: ConnectionInfo, tokenInfo: TokenInfo, urlConfig: URLSessionConfiguration = .default) {
        self.connectionInfo = connectionInfo

        self.tokenManager = TokenManager(connectionInfo: connectionInfo, tokenInfo: tokenInfo)
        let manager = HomeAssistantAPI.configureSessionManager(urlConfig: urlConfig)
        manager.retrier = self.tokenManager
        manager.adapter = self.tokenManager
        self.manager = manager
    }

    private static func configureSessionManager(urlConfig: URLSessionConfiguration = .default) -> SessionManager {
        let configuration = urlConfig
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

    public internal(set) var webhookManager = with(WebhookManager()) {
        $0.register(responseHandler: WebhookResponseUpdateSensors.self, for: .updateSensors)
        $0.register(responseHandler: WebhookResponseLocation.self, for: .location)
        $0.register(responseHandler: WebhookResponseServiceCall.self, for: .serviceCall)
    }

    public internal(set) var sensors = with(SensorContainer()) {
        $0.register(provider: ActivitySensor.self)
        $0.register(provider: PedometerSensor.self)
        $0.register(provider: BatterySensor.self)
        $0.register(provider: StorageSensor.self)
        $0.register(provider: ConnectivitySensor.self)
        $0.register(provider: GeocoderSensor.self)
        $0.register(provider: LastUpdateSensor.self)
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

    public func Connect(reason: ConnectReason) -> Promise<ConfigResponse> {
        return firstly {
            self.UpdateRegistration()
        }.recover { error -> Promise<MobileAppRegistrationResponse> in
            guard (error as NSError).domain != NSURLErrorDomain else {
                Current.Log.info("not re-registering because of network error")
                throw error
            }

            let message = "Failed to update integration; trying to register instead."
            Current.clientEventStore.addEvent(ClientEvent(text: message, type: .networkRequest))
            return self.Register()
        }.then { _ -> Promise<(ConfigResponse, [Zone], Void, [WatchComplication])> in
            return when(fulfilled:
                self.GetConfig(),
                self.GetZones(),
                self.UpdateSensors(trigger: reason.updateSensorTrigger).asVoid(),
                self.updateComplications()
            )
        }.map { config, zones, _, _ in
            if let oldHA = self.ensureVersion(config.Version) {
                throw oldHA
            }

            NotificationCenter.default.post(name: Self.didConnectNotification,
                                            object: nil, userInfo: nil)

            self.storeZones(zones: zones)

            return config
        }
    }

    public func CreateEvent(eventType: String, eventData: [String: Any]) -> Promise<Void> {
        return webhookManager.send(
            identifier: .unhandled,
            request: .init(type: "fire_event", data: [
                "event_type": eventType,
                "event_data": eventData
            ])
        )
    }

    private func getDownloadDataPath(_ downloadingURL: URL) -> URL? {
        let fileManager = FileManager.default

        let groupDirURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Constants.AppGroupID)?
            .appendingPathComponent("downloadedData", isDirectory: true)

        guard let directoryURL = groupDirURL else {
            assertionFailure("Unable to get groupDirURL.")
            return nil
        }

        return directoryURL.appendingPathComponent(downloadingURL.lastPathComponent, isDirectory: false)
    }

    public func DownloadDataAt(url: URL, needsAuth: Bool) -> Promise<URL> {
        return Promise { seal in

            var finalURL = url

            let dataManager: Alamofire.SessionManager = needsAuth ? self.manager : Alamofire.SessionManager.default

            if needsAuth {
                if !url.absoluteString.hasPrefix(self.connectionInfo.activeURL.absoluteString) {
                    Current.Log.verbose("URL does not contain base URL, prepending base URL to \(url.absoluteString)")
                    finalURL = self.connectionInfo.activeURL.appendingPathComponent(url.absoluteString)
                }

                Current.Log.verbose("Data download needs auth!")
            }

            guard let downloadPath = self.getDownloadDataPath(finalURL) else {
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
        var promise: Promise<ConfigResponse> = self.request(path: "config", callingFunctionName: "\(#function)")

        if useWebhook {
            promise = webhookManager.sendEphemeral(request: .init(type: "get_config", data: [:]))
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

            return Promise.value(config)
        }
    }

    public func GetEvents() -> Promise<[EventsResponse]> {
        return self.request(path: "events", callingFunctionName: "\(#function)")
    }

    public func GetStates() -> Promise<[Entity]> {
        return self.request(path: "states", callingFunctionName: "\(#function)")
    }

    public func GetServices() -> Promise<[ServicesResponse]> {
        return self.request(path: "services", callingFunctionName: "\(#function)")
    }

    public func CallService(domain: String, service: String, serviceData: [String: Any],
                            shouldLog: Bool = true) -> Promise<Void> {
        return webhookManager.send(
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
        let req: Promise<Any> = webhookManager.sendEphemeral(request: .init(type: "render_template", data: hookPayload))
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

    public func GetCameraImage(cameraEntityID: String) -> Promise<Image> {
        return Promise { seal in
            let queryUrl = self.connectionInfo.activeAPIURL.appendingPathComponent("camera_proxy/\(cameraEntityID)")
            _ = manager.request(queryUrl)
                .validate()
                .responseImage { response in
                    switch response.result {
                    case .success:
                        if let imgResponse = response.result.value {
                            seal.fulfill(imgResponse)
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
        webhookManager.sendEphemeral(request: .init(
            type: "update_registration",
            data: buildMobileAppUpdateRegistration()
        ))
    }

    public func GetZones() -> Promise<[Zone]> {
        webhookManager.sendEphemeral(request: .init(type: "get_zones", data: [:]))
    }

    public func GetPushSettings() -> Promise<PushConfiguration> {
        return self.request(path: "ios/push", callingFunctionName: "\(#function)")
    }

    public func StreamCamera(entityId: String) -> Promise<StreamCameraResponse> {
        webhookManager.sendEphemeral(request: .init(
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
        ident.AppVersion = prefs.string(forKey: "lastInstalledVersion")
        ident.DeviceID = Current.settingsStore.integrationDeviceID
        ident.DeviceName = Current.settingsStore.overrideDeviceName ?? deviceKitDevice.name
        ident.Manufacturer = "Apple"
        ident.Model = deviceKitDevice.description
        ident.OSName = deviceKitDevice.systemName
        ident.OSVersion = deviceKitDevice.systemVersion
        ident.SupportsEncryption = true

        var json = Mapper().toJSON(ident)

        if Current.serverVersion() < Version(major: 0, minor: 104) {
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
        ident.AppVersion = prefs.string(forKey: "lastInstalledVersion")
        ident.DeviceName = Current.settingsStore.overrideDeviceName ?? deviceKitDevice.name
        ident.Manufacturer = "Apple"
        ident.Model = deviceKitDevice.description
        ident.OSVersion = deviceKitDevice.systemVersion

        return Mapper().toJSON(ident)
    }

    public func storeZones(zones: [Zone]) {
        let realm = Current.realm()

        let existingZoneIDs: [String] = realm.objects(RLMZone.self).map { $0.ID }

        var seenZoneIDs: [String] = []

        for zone in zones {
            seenZoneIDs.append(zone.ID)
            if let existingZone = realm.object(ofType: RLMZone.self, forPrimaryKey: zone.ID) {
                // swiftlint:disable:next force_try
                try! realm.write {
                    HomeAssistantAPI.updateZone(existingZone, withZoneEntity: zone)
                }
            } else {
                // swiftlint:disable:next force_try
                try! realm.write {
                    realm.add(RLMZone(zone: zone), update: .all)
                }
            }
        }

        // Now remove zones that aren't in HA anymore
        let zoneIDsToDelete = existingZoneIDs.filter { zoneID -> Bool in
            return seenZoneIDs.contains(zoneID) == false
        }

        // swiftlint:disable:next force_try
        try! realm.write {
            realm.delete(realm.objects(RLMZone.self).filter("ID IN %@", zoneIDsToDelete))
        }
    }

    private static func updateZone(_ storeableZone: RLMZone, withZoneEntity zone: Zone) {
        storeableZone.Latitude = zone.Latitude
        storeableZone.Longitude = zone.Longitude
        storeableZone.Radius = zone.Radius
        storeableZone.TrackingEnabled = zone.TrackingEnabled
        storeableZone.BeaconUUID = zone.UUID
        storeableZone.BeaconMajor.value = zone.Major
        storeableZone.BeaconMinor.value = zone.Minor
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
        }.then { [webhookManager] payload in
            return when(resolved:
                self.UpdateSensors(trigger: updateType, location: location).asVoid(),
                webhookManager.send(
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

    public enum ActionSource: CaseIterable {
        case Watch
        case Widget
        case AppShortcut // UIApplicationShortcutItem
        case Preview

        var description: String {
            switch self {
            case .Watch:
                return "watch"
            case .Widget:
                return "widget"
            case .AppShortcut:
                return "appShortcut"
            case .Preview:
                return "preview"
            }
        }
    }

    public class func notificationActionEvent(
        identifier: String,
        category: String?,
        actionData: Any?,
        textInput: String?
    ) -> (eventType: String, eventData: [String: Any]) {
        let device = Device.current
        var eventData: [String: Any] = [
            "actionName": identifier,
            "sourceDevicePermanentID": Constants.PermanentID,
            "sourceDeviceName": device.name ?? "Unknown",
            "sourceDeviceID": Current.settingsStore.deviceID
        ]

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
        let device = Device.current
        return (eventType: "ios.action_fired", eventData: [
            "actionName": actionName,
            "actionID": actionID,
            "triggerSource": source.description,
            "sourceDevicePermanentID": Constants.PermanentID,
            "sourceDeviceName": device.name ?? "Unknown",
            "sourceDeviceID": Current.settingsStore.deviceID
        ])
    }

    public func HandleAction(actionID: String, actionName: String, source: ActionSource) -> Promise<Void> {
        return Promise { seal in
            guard let api = HomeAssistantAPI.authenticatedAPI() else {
                throw APIError.notConfigured
            }

            let action = Self.actionEvent(actionID: actionID, actionName: actionName, source: source)
            Current.Log.verbose("Sending action: \(action.eventType) payload: \(action.eventData)")

            api.CreateEvent(eventType: action.eventType, eventData: action.eventData).done { _ -> Void in
                seal.fulfill(())
            }.catch {error in
                seal.reject(error)
            }
        }
    }

    public func RegisterSensors() -> Promise<Void> {
        return firstly {
            sensors.sensors(request: .init(reason: .registration))
        }.get { sensors in
            Current.Log.verbose("Registering sensors \(sensors.map { $0.UniqueID  })")
        }.thenMap { [webhookManager] sensor in
            webhookManager.send(request: .init(type: "register_sensor", data: sensor.toJSON()))
        }.asVoid()
    }

    public func UpdateSensors(trigger: LocationUpdateTrigger,
                              location: CLLocation? = nil) -> Promise<Void> {
        return firstly {
            sensors.sensors(request: .init(
                reason: .trigger(trigger.rawValue),
                location: location
            ))
        }.map { sensors in
            Current.Log.info("updating sensors \(sensors.map { $0.UniqueID ?? "unknown" })")

            let mapper = Mapper<WebhookSensor>(context: WebhookSensorContext(update: true),
                                               shouldIncludeNilValues: false)
            return mapper.toJSONArray(sensors)
        }.then { [webhookManager] (payload) -> Promise<Void> in
            webhookManager.send(
                identifier: .updateSensors,
                request: .init(type: "update_sensor_states", data: payload)
            )
        }
    }

    public func ensureVersion(_ currentVersionStr: String) -> APIError? {
//        let currentVersion = Version(stringLiteral: String(currentVersionStr.prefix(6)))
//        if HomeAssistantAPI.minimumRequiredVersion > currentVersion {
//            return APIError.mustUpgradeHomeAssistant(currentVersion)
//        }
        return nil
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
        case .unknown:
            return L10n.HaApi.ApiError.unknown
        }
    }
}
