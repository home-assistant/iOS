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
import Starscream
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

    static let minimumRequiredVersion = Version(major: 0, minor: 91, patch: 3)

    let prefs = UserDefaults(suiteName: Constants.AppGroupID)!

    public var pushID: String?

    public static var LoadedComponents = [String]()

    public private(set) var manager: Alamofire.SessionManager!

    public private(set) var webhookManager: Alamofire.SessionManager!

    public private(set) var webhookHandler: WebhookHandler!

    public var oneShotLocationManager: OneShotLocationManager?

    public var MobileAppComponentLoaded: Bool {
        return HomeAssistantAPI.LoadedComponents.contains("mobile_app")
    }

    var tokenManager: TokenManager?
    public var connectionInfo: ConnectionInfo

    public var socket: WebSocket?
    weak var socketDelegate: WebsocketDelegate?
    public static var socketMessageCounter: Int = 1
    public static var socketMessageTypeMap: [Int: String] = [:]
    static var socketMessages: [Int: WebSocketMessage] = [:]
    public static var socketDispatchGroups: [Int: DispatchGroup] = [:]
    public var socketAuthenticated: Bool = false

    /// Initialize an API object with an authenticated tokenManager.
    public init(connectionInfo: ConnectionInfo, tokenInfo: TokenInfo, urlConfig: URLSessionConfiguration = .default) {
        self.connectionInfo = connectionInfo

        self.tokenManager = TokenManager(connectionInfo: connectionInfo, tokenInfo: tokenInfo)
        let manager = HomeAssistantAPI.configureSessionManager(urlConfig: urlConfig)
        manager.retrier = self.tokenManager
        manager.adapter = self.tokenManager
        self.manager = manager

        self.webhookManager = HomeAssistantAPI.configureSessionManager(urlConfig: urlConfig)

        if let webhookID = Current.settingsStore.webhookID {
            let handler = WebhookHandler(webhookID: webhookID, connectionInfo: connectionInfo,
                                         remoteUIURL: Current.settingsStore.remoteUIURL,
                                         cloudhookURL: Current.settingsStore.cloudhookURL)
            self.webhookManager.adapter = handler
            self.webhookManager.retrier = handler
            self.webhookHandler = handler
        }

        self.pushID = self.prefs.string(forKey: "pushID")

        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { (settings) in
            let notificationsAllowed = settings.authorizationStatus == UNAuthorizationStatus.authorized
            Current.settingsStore.notificationsEnabled = notificationsAllowed
        })
    }

    private static func configureSessionManager(urlConfig: URLSessionConfiguration = .default) -> SessionManager {
        let configuration = urlConfig
        configuration.timeoutIntervalForRequest = 10 // seconds
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

    public static func authenticatedAPI(urlConfig: URLSessionConfiguration = .default) -> HomeAssistantAPI? {
        if let api = sharedAPI {
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
            } else {
                seal.reject(APIError.notConfigured)
            }
        }
    }

    public func VideoStreamer() -> MJPEGStreamer? {
        guard let newManager = self.authenticatedSessionManager() else {
            return nil
        }

        return MJPEGStreamer(manager: newManager)
    }

    public func Connect() -> Promise<ConfigResponse> {

        return firstly {
            self.UpdateRegistration()
        }.then { _ -> Promise<(ConfigResponse, [Zone], Void)> in
            return when(fulfilled: self.GetConfig(), self.GetZones(), self.UpdateSensors(.Unknown).asVoid())
        }.map { config, zones, _ in
            if let oldHA = self.ensureVersion(config.Version) {
                throw oldHA
            }

            HomeAssistantAPI.LoadedComponents = config.Components

            guard self.MobileAppComponentLoaded else {
                Current.Log.error("mobile_app component is not loaded!")
                throw APIError.mobileAppComponentNotLoaded
            }

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

            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "connected"),
                                            object: nil, userInfo: nil)

            self.storeZones(zones: zones)

            return config
        }
    }

    public func CreateEvent(eventType: String, eventData: [String: Any]) -> Promise<String> {
        return self.webhook("fire_event",
                            payload: ["event_type": eventType, "event_data": eventData],
                            callingFunctionName: "\(#function)")
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
                seal.reject(NSError(domain: "io.robbie.HomeAssistant", code: 500, userInfo: nil))
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
        if useWebhook {
            return self.webhook("get_config", payload: [:], callingFunctionName: "\(#function)")
        }

        return self.request(path: "config", callingFunctionName: "\(#function)")
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
                            shouldLog: Bool = true) -> Promise<[Entity]> {

        let hookPayload: [String: Any] = ["domain": domain, "service": service, "service_data": serviceData]
        let promise: Promise<[Entity]> = self.webhook("call_service", payload: hookPayload,
                                                      callingFunctionName: "\(#function)")
        if shouldLog {
            _ = promise.then { resp -> Promise<[Entity]> in
                let event = ClientEvent(text: "Calling service: \(domain) - \(service)", type: .serviceCall,
                                        payload: serviceData)
                Current.clientEventStore.addEvent(event)

                return Promise.value(resp)
            }
        }
        return promise
    }

    public func RenderTemplate(templateStr: String, variables: [String: Any] = [:]) -> Promise<String> {
        let hookPayload: [String: [String: Any]] = ["tpl": ["template": templateStr, "variables": variables]]
        let req: Promise<Any> = self.webhook("render_template", payload: hookPayload,
                                             callingFunctionName: "RenderTemplate")
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
                Current.settingsStore.cloudhookURL = resp.CloudhookURL
                Current.settingsStore.remoteUIURL = resp.RemoteUIURL
                Current.settingsStore.webhookID = resp.WebhookID
                Current.settingsStore.webhookSecret = resp.WebhookSecret

                let handler = WebhookHandler(webhookID: resp.WebhookID, connectionInfo: self.connectionInfo,
                                             remoteUIURL: resp.RemoteUIURL, cloudhookURL: resp.CloudhookURL)
                self.webhookManager.adapter = handler
                self.webhookManager.retrier = handler
                self.webhookHandler = handler

                return Promise.value(resp)
        }
    }

    public func UpdateRegistration() -> Promise<MobileAppRegistrationResponse> {
        return self.webhook("update_registration", payload: buildMobileAppUpdateRegistration(),
                            callingFunctionName: "updateRegistration")
    }

    public func GetZones() -> Promise<[Zone]> {
        return self.webhook("get_zones", payload: [:], callingFunctionName: "getZones")
    }

    public func GetPushSettings() -> Promise<PushConfiguration> {
        return self.request(path: "ios/push", callingFunctionName: "\(#function)")
    }

    private func buildMobileAppRegistration() -> [String: Any] {
        let deviceKitDevice = Device.current

        let ident = MobileAppRegistrationRequest()
        if let pushID = self.pushID {
            ident.AppData = [
                "push_url": "https://mobile-apps.home-assistant.io/api/sendPushNotification",
                "push_token": pushID
            ]
        }
        ident.AppIdentifier = Constants.BundleID
        ident.AppName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
        ident.AppVersion = prefs.string(forKey: "lastInstalledVersion")
        // ident.DeviceID = Current.settingsStore.deviceID
        ident.DeviceName = deviceKitDevice.name
        ident.Manufacturer = "Apple"
        ident.Model = deviceKitDevice.description
        ident.OSName = deviceKitDevice.systemName
        ident.OSVersion = deviceKitDevice.systemVersion
        ident.SupportsEncryption = true

        return Mapper().toJSON(ident)
    }

    private func buildMobileAppUpdateRegistration() -> [String: Any] {
        let deviceKitDevice = Device.current

        let ident = MobileAppUpdateRegistrationRequest()
        if let pushID = self.pushID {
            ident.AppData = [
                "push_url": "https://mobile-apps.home-assistant.io/api/sendPushNotification",
                "push_token": pushID
            ]
        }
        ident.AppVersion = prefs.string(forKey: "lastInstalledVersion")
        // ident.DeviceID = Current.settingsStore.deviceID
        ident.DeviceName = deviceKitDevice.name
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
                    realm.add(RLMZone(zone: zone), update: true)
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

        Current.syncMonitoredRegions?()
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

    private func buildWebhookLocationPayload(updateType: LocationUpdateTrigger,
                                             location: CLLocation?, zone: RLMZone?) -> Promise<WebhookUpdateLocation> {

        let device = Device.current

        let payload = WebhookUpdateLocation(trigger: updateType, location: location, zone: zone)
        payload.Trigger = updateType

        let isBeaconUpdate = (updateType == .BeaconRegionEnter || updateType == .BeaconRegionExit)

        payload.Battery = device.batteryLevel ?? 0
        payload.SourceType = (isBeaconUpdate ? .BluetoothLowEnergy : .GlobalPositioningSystem)

        return Promise.value(payload)

    }

    public func SubmitLocation(updateType: LocationUpdateTrigger,
                               location: CLLocation?, zone: RLMZone?) -> Promise<Bool> {

        return self.buildWebhookLocationPayload(updateType: updateType,
                                                location: location, zone: zone).map { payload -> [String: Any] in

            var jsonPayload = "{\"missing\": \"payload\"}"
            if let p = payload.toJSONString(prettyPrint: false) {
                jsonPayload = p
            }

            let payloadDict: [String: Any] = Mapper<WebhookUpdateLocation>().toJSON(payload)

            Current.Log.info("Location update payload: \(payloadDict)")
            let realm = Current.realm()
            // swiftlint:disable:next force_try
            try! realm.write {
                realm.add(LocationHistoryEntry(updateType: updateType, location: payload.cllocation,
                                               zone: zone, payload: jsonPayload))
            }

            return payloadDict
        }.then { (payload: [String: Any]) -> Promise<([String: WebhookSensorResponse], Any, [String: Any])> in
            let locUpdate: Promise<Any> = self.webhook("update_location",
                                                       payload: payload, callingFunctionName: "\(#function)")
            return when(fulfilled: self.UpdateSensors(updateType, location), locUpdate, Promise.value(payload))
        }.then { (resp) -> Promise<Bool> in
            Current.Log.verbose("Device seen via webhook!")
            self.sendLocalNotification(withZone: zone, updateType: updateType, payloadDict: resp.2)
            return Promise.value(true)
        }

    }

    public func GetAndSendLocation(trigger: LocationUpdateTrigger?) -> Promise<Bool> {
        var updateTrigger: LocationUpdateTrigger = .Manual
        if let trigger = trigger {
            updateTrigger = trigger
        }
        Current.Log.verbose("getAndSendLocation called via \(String(describing: updateTrigger))")

        return Promise { seal in
            Current.isPerformingSingleShotLocationQuery = true
            self.oneShotLocationManager = OneShotLocationManager { location, error in
                guard let location = location else {
                    seal.reject(error ?? APIError.unknown)
                    return
                }

                Current.isPerformingSingleShotLocationQuery = true
                firstly {
                    self.SubmitLocation(updateType: updateTrigger, location: location,
                                        zone: nil)
                    }.done { worked in
                        seal.fulfill(worked)
                    }.catch { error in
                        seal.reject(error)
                }
            }
        }
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

    public func HandleAction(actionID: String, actionName: String, source: ActionSource) -> Promise<Bool> {
        return Promise { seal in
            guard let api = HomeAssistantAPI.authenticatedAPI() else {
                throw APIError.notConfigured
            }

            let device = Device.current
            let eventData: [String: Any] = ["actionName": actionName,
                                            "actionID": actionID,
                                            "triggerSource": source.description,
                                            "sourceDevicePermanentID": Constants.PermanentID,
                                            "sourceDeviceName": device.name ?? "Unknown",
                                            "sourceDeviceID": Current.settingsStore.deviceID]

            Current.Log.verbose("Sending action payload: \(eventData)")

            let eventType = "ios.action_fired"
            api.CreateEvent(eventType: eventType, eventData: eventData).done { _ -> Void in
                seal.fulfill(true)
                }.catch {error in
                    seal.reject(error)
            }
        }
    }

    private let sensorsConfig = WebhookSensors()

    public func RegisterSensors() -> Promise<[WebhookSensorResponse]> {
        return firstly {
            self.sensorsConfig.AllSensors
        }.then { (sensors: [WebhookSensor]) -> Promise<[WebhookSensorResponse]> in

            var allSensors = sensors
            allSensors.append(WebhookSensor(name: "Last Update Trigger", uniqueID: "last_update_trigger"))
            allSensors.append(self.sensorsConfig.GeocodedLocationSensorConfig)

            var promises: [Promise<WebhookSensorResponse>] = []

            for sensor in allSensors {
                promises.append(self.webhook("register_sensor",
                                             payload: sensor.toJSON(), callingFunctionName: "\(#function)"))
            }

            return when(fulfilled: promises)
        }
    }

    public func UpdateSensors(_ trigger: LocationUpdateTrigger = .Unknown,
                              _ location: CLLocation? = nil) -> Promise<[String: WebhookSensorResponse]> {
        return firstly {
            return self.sensorsConfig.AllSensors
        }.then { sensors -> Promise<[WebhookSensor]> in
            guard let location = location else {
                return Promise.value(sensors)
            }
            return self.sensorsConfig.GeocodedLocationSensor(location).map { geoSensor in
                var allSensors = sensors
                allSensors.append(geoSensor)
                return allSensors
            }
        }.map { sensors in
            let lastUpdateTriggerSensor = WebhookSensor(name: "Last Update Trigger", uniqueID: "last_update_trigger")
            if trigger != .Unknown {
                lastUpdateTriggerSensor.State = trigger.rawValue
            }

            var allSensors = sensors
            allSensors.append(lastUpdateTriggerSensor)

            let mapper = Mapper<WebhookSensor>(context: WebhookSensorContext(update: true),
                                               shouldIncludeNilValues: false)
            let payload = mapper.toJSONArray(allSensors)

            Current.Log.verbose("Update sensors payload: \(mapper.toJSONString(allSensors, prettyPrint: true)!)")

            return payload
        }.then { (payload) -> Promise<Any> in
            return self.webhook("update_sensor_states", payload: payload, callingFunctionName: "updateSensors")
        }.map { resp -> [String: WebhookSensorResponse] in

            guard let castedResp = resp as? [String: [String: Any]] else {
                throw APIError.invalidResponse
            }

            var out: [String: WebhookSensorResponse] = [:]

            for (key, val) in castedResp {
                guard let casted = WebhookSensorResponse(JSON: val) else {
                    Current.Log.warning("Unexpected response during update of sensor \(key)")
                    continue
                }
                out[key] = casted
            }

            return out
        }.then { resps -> Promise<[String: WebhookSensorResponse]> in
            // mobile_app could respond with error "not_registered". If we get _any_ responses that fail, let's
            // re-register _all_ of the sensors.
            let containsFailures = resps.contains { !$0.value.Success }

            if !containsFailures {
                return Promise.value(resps)
            }

            Current.Log.warning("Errors detected during sensor update, re-registering all sensors now")

            return self.RegisterSensors().then { _ -> Promise<[String: WebhookSensorResponse]> in
                return self.UpdateSensors(trigger)
            }
        }

    }

    public func ensureVersion(_ currentVersionStr: String) -> APIError? {
        let currentVersion = Version(stringLiteral: currentVersionStr.replacingOccurrences(of: ".dev0", with: ""))
        if HomeAssistantAPI.minimumRequiredVersion >= currentVersion {
            return APIError.mustUpgradeHomeAssistant(currentVersion)
        }
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
