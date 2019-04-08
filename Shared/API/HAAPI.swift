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
import CoreMotion
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
    }

    public enum AuthenticationMethod {
        case legacy(apiPassword: String?)
        case modern(tokenInfo: TokenInfo)
    }

    public var authenticationMethodString = "unknown"

    let prefs = UserDefaults(suiteName: Constants.AppGroupID)!

    public var pushID: String?

    public var loadedComponents = [String]()

    var apiPassword: String?

    public private(set) var manager: Alamofire.SessionManager!

    public var oneShotLocationManager: OneShotLocationManager?

    public var cachedEntities: [Entity]?

    public var mobileAppComponentLoaded: Bool {
        return self.loadedComponents.contains("mobile_app")
    }

    var enabledPermissions: [String] {
        var permissionsContainer: [String] = []
        if Current.settingsStore.notificationsEnabled {
            permissionsContainer.append("notifications")
        }
        if Current.settingsStore.locationEnabled {
            permissionsContainer.append("location")
        }
        return permissionsContainer
    }

    var tokenManager: TokenManager?
    public var connectionInfo: ConnectionInfo

    public let pedometer = CMPedometer()
    public let motionActivityManager = CMMotionActivityManager()

    /// Initialize an API object with an authenticated tokenManager.
    public init(connectionInfo: ConnectionInfo, authenticationMethod: AuthenticationMethod,
                urlConfig: URLSessionConfiguration = .default) {
        self.connectionInfo = connectionInfo

        switch authenticationMethod {
        case .legacy(let apiPassword):
            self.manager = HomeAssistantAPI.configureSessionManager(withPassword: apiPassword, urlConfig: urlConfig)
        case .modern(let tokenInfo):
            self.tokenManager = TokenManager(connectionInfo: connectionInfo, tokenInfo: tokenInfo)
            let manager = HomeAssistantAPI.configureSessionManager(urlConfig: urlConfig)
            manager.retrier = self.tokenManager
            manager.adapter = self.tokenManager
            self.manager = manager
            self.authenticationMethodString = "modern"
        }

        self.manager.delegate.taskDidReceiveChallenge = { session, task, challenge in
            Current.Log.verbose("HAAPI Manager received challenge")
            let authMethod = challenge.protectionSpace.authenticationMethod

            guard authMethod == NSURLAuthenticationMethodDefault ||
                authMethod == NSURLAuthenticationMethodHTTPBasic ||
                authMethod == NSURLAuthenticationMethodHTTPDigest else {
                    Current.Log.verbose("Not handling auth method \(authMethod)")
                    return (.performDefaultHandling, nil)
            }

            Current.Log.verbose("Received basic auth challenge")

            guard let basicAuthCreds = Current.settingsStore.connectionInfo?.basicAuthCredentials else {
                Current.Log.error("Unable to get basicAuthCreds, skipping auth challenge!")
                return (.performDefaultHandling, nil)
            }

            return (.useCredential, URLCredential(user: basicAuthCreds.username, password: basicAuthCreds.password,
                                                  persistence: .synchronizable))
        }

        self.pushID = self.prefs.string(forKey: "pushID")

        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { (settings) in
            let notificationsAllowed = settings.authorizationStatus == UNAuthorizationStatus.authorized
            Current.settingsStore.notificationsEnabled = notificationsAllowed
        })
    }

    func authenticatedSessionManager() -> Alamofire.SessionManager? {
        guard Current.settingsStore.connectionInfo != nil else {
            return nil
        }

        if Current.settingsStore.tokenInfo != nil {
            let manager = HomeAssistantAPI.configureSessionManager()
            manager.retrier = self.tokenManager
            manager.adapter = self.tokenManager
            return manager
        } else {
            return HomeAssistantAPI.configureSessionManager(withPassword: keychain["apiPassword"])
        }
    }

    public func videoStreamer() -> MJPEGStreamer? {
        guard let newManager = self.authenticatedSessionManager() else {
            return nil
        }

        return MJPEGStreamer(manager: newManager)
    }

    /// Configure global state of the app to use our newly validated credentials.
    func confirmAPI() {
        Current.tokenManager = self.tokenManager
    }

    public func Connect() -> Promise<ConfigResponse> {

        var registrationPromise: Promise<Void>?
        var sensorsPromise: Promise<Void>?

        if let webhookID = Current.settingsStore.webhookID {
            Current.Log.warning("Device already registered with mobile_app, updating \(webhookID)")
            registrationPromise = self.updateRegistration().asVoid()
            sensorsPromise = self.updateSensors(trigger: .Unknown).asVoid()
        } else {
            registrationPromise = self.registerDevice().asVoid()
            sensorsPromise = self.registerSensors().asVoid()
        }

        return firstly {
            registrationPromise!
        }.then {
            when(fulfilled: self.GetConfig(), self.GetZones(), sensorsPromise!)
        }.map { config, zones, _ in
            if let components = config.Components {
                self.loadedComponents = components
            }

            guard self.mobileAppComponentLoaded else {
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

    public enum HomeAssistantAPIError: Error {
        case notAuthenticated
        case unknown
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
                                       authenticationMethod: .modern(tokenInfo: tokenInfo), urlConfig: urlConfig)
            self.sharedAPI = api
        } else {
            let api = HomeAssistantAPI(connectionInfo: connectionInfo,
                                       authenticationMethod: .legacy(apiPassword: keychain["apiPassword"]),
                                       urlConfig: urlConfig)
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

    public func getManifestJSON() -> Promise<ManifestJSON> {
        return Promise { seal in
            if let manager = self.manager {
                let queryUrl = self.connectionInfo.activeURL.appendingPathComponent("manifest.json")
                _ = manager.request(queryUrl, method: .get)
                    .validate()
                    .responseObject { (response: DataResponse<ManifestJSON>) in
                        switch response.result {
                        case .success:
                            if let resVal = response.result.value {
                                seal.fulfill(resVal)
                            } else {
                                seal.reject(APIError.invalidResponse)
                            }
                        case .failure(let error):
                            Current.Log.error("Error on GetManifestJSON() request: \(error)")
                            seal.reject(error)
                        }
                }
            } else {
                seal.reject(APIError.managerNotAvailable)
            }
        }
    }

    public func GetStatus() -> Promise<StatusResponse> {
        return self.request(path: "", callingFunctionName: "\(#function)", method: .get)
    }

    public func GetConfigRESTAPI() -> Promise<ConfigResponse> {
        return self.request(path: "config", callingFunctionName: "\(#function)")
    }

    public func GetConfig() -> Promise<ConfigResponse> {
        return self.webhook("get_config", payload: [:], callingFunctionName: "getConfig")
    }

    public func GetServices() -> Promise<[ServicesResponse]> {
        return self.request(path: "services", callingFunctionName: "\(#function)")
    }

    public func GetEvents() -> Promise<[EventsResponse]> {
        return self.request(path: "events", callingFunctionName: "\(#function)")
    }

    public func GetStates() -> Promise<[Entity]> {
        return self.request(path: "states", callingFunctionName: "\(#function)")
    }

    public func GetEntityState(entityId: String) -> Promise<Entity> {
        return self.request(path: "states/\(entityId)", callingFunctionName: "\(#function)")
    }

    public func SetState(entityId: String, state: String) -> Promise<Entity> {
        return self.request(path: "states/\(entityId)", callingFunctionName: "\(#function)", method: .post,
                            parameters: ["state": state], encoding: JSONEncoding.default)
    }

    public func createEvent(eventType: String, eventData: [String: Any]) -> Promise<String> {

        if Current.settingsStore.webhookID != nil {
            let hookPayload: [String: Any] = ["event_type": eventType, "event_data": eventData]
            return self.webhook("fire_event", payload: hookPayload, callingFunctionName: "createEvent")
        }

        return Promise { seal in
            let queryUrl = self.connectionInfo.activeAPIURL.appendingPathComponent("events/\(eventType)")
            _ = manager.request(queryUrl, method: .post,
                                parameters: eventData, encoding: JSONEncoding.default)
                .validate()
                .responseJSON { response in
                    switch response.result {
                    case .success:
                        if let jsonDict = response.result.value as? [String: String],
                            let msg = jsonDict["message"] {
                            seal.fulfill(msg)
                        }
                    case .failure(let error):
                        Current.Log.error("Error when attemping to CreateEvent(): \(error)")
                        seal.reject(error)
                    }
            }
        }
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

    public func downloadDataAt(url: URL, needsAuth: Bool) -> Promise<URL> {
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

    // swiftlint:disable:next function_body_length
    public func callService(domain: String, service: String, serviceData: [String: Any],
                            shouldLog: Bool = true) -> Promise<[Entity]> {

        if Current.settingsStore.webhookID != nil {
            let hookPayload: [String: Any] = ["domain": domain, "service": service, "service_data": serviceData]
            let promise: Promise<[Entity]> = self.webhook("call_service", payload: hookPayload,
                                                          callingFunctionName: "callService")
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

        return Promise { seal in
            let queryUrl =
                self.connectionInfo.activeAPIURL.appendingPathComponent("services/\(domain)/\(service)")
            _ = manager.request(queryUrl, method: .post,
                                parameters: serviceData, encoding: JSONEncoding.default)
                .validate()
                .responseArray { (response: DataResponse<[Entity]>) in
                    switch response.result {
                    case .success:
                        if let resVal = response.result.value {
                            if shouldLog {
                                let event = ClientEvent(text: "Calling service: \(domain) - \(service)",
                                    type: .serviceCall, payload: serviceData)
                                Current.clientEventStore.addEvent(event)
                            }

                            seal.fulfill(resVal)
                        } else {
                            seal.reject(APIError.invalidResponse)
                        }
                    case .failure(let error):
                        if let afError = error as? AFError {
                            var errorUserInfo: [String: Any] = [:]
                            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                                if let errorJSON = utf8Text.dictionary(),
                                    let errMessage = errorJSON["message"] as? String {
                                    errorUserInfo["errorMessage"] = errMessage
                                }
                            }
                            Current.Log.error("Error on CallService() request: \(afError)")
                            let customError = NSError(domain: Bundle.main.bundleIdentifier!,
                                                      code: afError.responseCode!,
                                                      userInfo: errorUserInfo)
                            seal.reject(customError)
                        } else {
                            Current.Log.error("Error on CallService() request: \(error)")
                            seal.reject(error)
                        }
                    }
            }
        }
    }

    public func RenderTemplate(templateStr: String, variables: [String: Any] = [:]) -> Promise<String> {
        if Current.settingsStore.webhookID != nil {
            let hookPayload: [String: [String: Any]] = ["tpl": ["template": templateStr, "variables": variables]]
            return self.webhook("render_template", payload: hookPayload,
                                callingFunctionName: "RenderTemplate").then { (resp: Any) -> Promise<String> in
                guard let jsonDict = resp as? [String: String] else {
                    return Promise.value("Error")
                }

                guard let rendered = jsonDict["tpl"] else {
                    return Promise.value("Error")
                }

                return Promise.value(rendered)
            }
        }

        return Promise { seal in
            let queryUrl = self.connectionInfo.activeAPIURL.appendingPathComponent("template")
            _ = manager.request(queryUrl, method: .post, parameters: ["template": templateStr, "variables": variables],
                                encoding: JSONEncoding.default)
                .validate()
                .responseString { response in
                    switch response.result {
                    case .success:
                        if let strResponse = response.result.value {
                            seal.fulfill(strResponse)
                        }
                    case .failure(let error):
                        Current.Log.error("Error when attemping to RenderTemplate(): \(error)")
                        seal.reject(error)
                    }
            }
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

    public func GetCameraStream(cameraEntityID: String, completionHandler: @escaping (Image?, Error?) -> Void) {
        let apiURL = self.connectionInfo.activeAPIURL
        let queryUrl = apiURL.appendingPathComponent("camera_proxy_stream/\(cameraEntityID)", isDirectory: false)
//        DispatchQueue.global(qos: .background).async {
            let res = self.manager.request(queryUrl, method: .get)
                .validate()
                .response(completionHandler: { (response) in
                    if let error = response.error {
                        completionHandler(nil, error)
                        return
                    }
                })
//
                res.streamImage(imageScale: 1.0, inflateResponseImage: false, completionHandler: { (image) in
                    // Autorelease
                    autoreleasepool {
                        DispatchQueue.main.async {
                            completionHandler(image, nil)
                            return
                        }
                    }
                })
//            }
//        }
    }

    public func getDiscoveryInfo(baseUrl: URL) -> Promise<DiscoveryInfoResponse> {
        return self.request(path: "discover_info", callingFunctionName: "\(#function)")
    }

    public func identifyDevice() -> Promise<IdentifyResponse> {
        return self.request(path: "ios/identify", callingFunctionName: "\(#function)",
                            method: .post, parameters: buildIdentifyDict(), encoding: JSONEncoding.default)
    }

    public func removeDevice() -> Promise<String> {
        return self.request(path: "ios/identify", callingFunctionName: "\(#function)", method: .delete,
                            parameters: buildRemovalDict(), encoding: JSONEncoding.default)
    }

    public func registerDevice() -> Promise<MobileAppRegistrationResponse> {
        return self.request(path: "mobile_app/registrations", callingFunctionName: "\(#function)", method: .post,
                            parameters: buildMobileAppRegistration(), encoding: JSONEncoding.default)
            .then { (resp: MobileAppRegistrationResponse) -> Promise<MobileAppRegistrationResponse> in
                Current.settingsStore.cloudhookURL = resp.CloudhookURL
                Current.settingsStore.remoteUIURL = resp.RemoteUIURL
                Current.settingsStore.webhookID = resp.WebhookID
                Current.settingsStore.webhookSecret = resp.WebhookSecret
                return Promise.value(resp)
        }
    }

    public func updateRegistration() -> Promise<MobileAppRegistrationResponse> {
        return self.webhook("update_registration", payload: buildMobileAppUpdateRegistration(),
                            callingFunctionName: "updateRegistration")
    }

    public func GetZones() -> Promise<[Zone]> {
        return self.webhook("get_zones", payload: [:], callingFunctionName: "getZones")
    }

    public func turnOn(entityId: String) -> Promise<[Entity]> {
        return callService(domain: "homeassistant", service: "turn_on", serviceData: ["entity_id": entityId])
    }

    public func turnOnEntity(entity: Entity) -> Promise<[Entity]> {
        return callService(domain: "homeassistant", service: "turn_on", serviceData: ["entity_id": entity.ID])
    }

    public func turnOff(entityId: String) -> Promise<[Entity]> {
        return callService(domain: "homeassistant", service: "turn_off", serviceData: ["entity_id": entityId])
    }

    public func turnOffEntity(entity: Entity) -> Promise<[Entity]> {
        return callService(domain: "homeassistant", service: "turn_off",
                           serviceData: ["entity_id": entity.ID])
    }

    public func toggle(entityId: String) -> Promise<[Entity]> {
        return callService(domain: "homeassistant", service: "toggle", serviceData: ["entity_id": entityId])
    }

    public func toggleEntity(entity: Entity) -> Promise<[Entity]> {
        return callService(domain: "homeassistant", service: "toggle", serviceData: ["entity_id": entity.ID])
    }

    public func getPushSettings() -> Promise<PushConfiguration> {
        return self.request(path: "ios/push", callingFunctionName: "\(#function)")
    }

    private func buildIdentifyDict() -> [String: Any] {
        let deviceKitDevice = Device()

        let ident = IdentifyRequest()
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") {
            if let stringedBundleVersion = bundleVersion as? String {
                ident.AppBuildNumber = Int(stringedBundleVersion)
            }
        }
        if let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") {
            if let stringedVersionNumber = versionNumber as? String {
                ident.AppVersionNumber = stringedVersionNumber
            }
        }
        ident.AppBundleIdentifer = Bundle.main.bundleIdentifier
        ident.DeviceID = Current.settingsStore.deviceID
        ident.DeviceLocalizedModel = deviceKitDevice.localizedModel
        ident.DeviceModel = deviceKitDevice.model
        ident.DeviceName = deviceKitDevice.name
        ident.DevicePermanentID = Constants.PermanentID
        ident.DeviceSystemName = deviceKitDevice.systemName
        ident.DeviceSystemVersion = deviceKitDevice.systemVersion
        ident.DeviceType = deviceKitDevice.description
        ident.Permissions = self.enabledPermissions
        ident.PushID = pushID
        ident.PushSounds = Notifications.installedPushNotificationSounds()

        switch deviceKitDevice.batteryState {
        case .charging:
            ident.BatteryState = "Charging"
        case .unplugged:
            ident.BatteryState = "Unplugged"
        case .full:
            ident.BatteryState = "Full"
        }

        ident.BatteryLevel = Int(deviceKitDevice.batteryLevel)
        if ident.BatteryLevel == -100 { // simulator fix
            ident.BatteryLevel = 100
        }

        return Mapper().toJSON(ident)
    }

    private func buildMobileAppRegistration() -> [String: Any] {
        let deviceKitDevice = Device()

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
        ident.DeviceName = deviceKitDevice.name
        ident.Manufacturer = "Apple"
        ident.Model = deviceKitDevice.description
        ident.OSName = deviceKitDevice.systemName
        ident.OSVersion = deviceKitDevice.systemVersion
        ident.SupportsEncryption = true

        return Mapper().toJSON(ident)
    }

    private func buildMobileAppUpdateRegistration() -> [String: Any] {
        let deviceKitDevice = Device()

        let ident = MobileAppUpdateRegistrationRequest()
        if let pushID = self.pushID {
            ident.AppData = [
                "push_url": "https://mobile-apps.home-assistant.io/api/sendPushNotification",
                "push_token": pushID
            ]
        }
        ident.AppVersion = prefs.string(forKey: "lastInstalledVersion")
        ident.DeviceName = deviceKitDevice.name
        ident.Manufacturer = "Apple"
        ident.Model = deviceKitDevice.description
        ident.OSVersion = deviceKitDevice.systemVersion

        return Mapper().toJSON(ident)
    }

    private func buildRemovalDict() -> [String: Any] {
        let deviceKitDevice = Device()

        let ident = IdentifyRequest()
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") {
            if let stringedBundleVersion = bundleVersion as? String {
                ident.AppBuildNumber = Int(stringedBundleVersion)
            }
        }
        if let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") {
            if let stringedVersionNumber = versionNumber as? String {
                ident.AppVersionNumber = stringedVersionNumber
            }
        }
        ident.AppBundleIdentifer = Bundle.main.bundleIdentifier
        ident.DeviceID = Current.settingsStore.deviceID
        ident.DeviceLocalizedModel = deviceKitDevice.localizedModel
        ident.DeviceModel = deviceKitDevice.model
        ident.DeviceName = deviceKitDevice.name
        ident.DevicePermanentID = Constants.PermanentID
        ident.DeviceSystemName = deviceKitDevice.systemName
        ident.DeviceSystemVersion = deviceKitDevice.systemVersion
        ident.DeviceType = deviceKitDevice.description
        ident.Permissions = self.enabledPermissions
        ident.PushID = pushID
        ident.PushSounds = Notifications.installedPushNotificationSounds()

        return Mapper().toJSON(ident)
    }

    func storeEntities(entities: [Entity]) {
        let storeableComponents = ["zone", "device_tracker"]
        let storeableEntities = entities.filter { (entity) -> Bool in
            return storeableComponents.contains(entity.Domain)
        }

        let realm = Current.realm()

        let existingZoneIDs: [String] = realm.objects(RLMZone.self).map { $0.ID }

        var seenZoneIDs: [String] = []

        for entity in storeableEntities {
            if entity.Domain == "zone", let zone = entity as? Zone {
                let realm = Current.realm()
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

            if entity.Domain == "device_tracker", let device = entity as? DeviceTracker {
                // swiftlint:disable:next force_try
                try! realm.write {
                    realm.add(RLMDeviceTracker(device), update: true)
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

    func storeZones(zones: [Zone]) {
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

    private static func configureSessionManager(withPassword password: String? = nil,
                                                urlConfig: URLSessionConfiguration = .default) -> SessionManager {
        var headers = Alamofire.SessionManager.defaultHTTPHeaders
        if let password = password {
            headers["X-HA-Access"] = password
        }

        let configuration = urlConfig
        configuration.httpAdditionalHeaders = headers
        configuration.timeoutIntervalForRequest = 10 // seconds
        return Alamofire.SessionManager(configuration: configuration)
    }

    private func getLatestMotionActivity() -> Promise<CMMotionActivity?> {
        return Promise { seal in
            guard CMMotionActivityManager.isActivityAvailable() else {
                return seal.fulfill(nil)
            }

            guard Current.settingsStore.motionEnabled else {
                return seal.fulfill(nil)
            }

            let end = Date()
            let start = Calendar.current.date(byAdding: .minute, value: -10, to: end)!
            let queue = OperationQueue.main
            self.motionActivityManager.queryActivityStarting(from: start, to: end, to: queue) { (activities, _) in
                seal.fulfill(activities?.last)
            }
        }
    }

    private func getLatestPedometerData() -> Promise<CMPedometerData?> {
        return Promise { seal in
            guard CMPedometer.isStepCountingAvailable() else {
                Current.Log.warning("Step counting is not available")
                return seal.fulfill(nil)
            }

            guard Current.settingsStore.motionEnabled else {
                return seal.fulfill(nil)
            }

            var startDate = Calendar.current.startOfDay(for: Date())

            if let lastEntry = Current.realm().objects(LocationHistoryEntry.self).sorted(byKeyPath: "CreatedAt").last {
                startDate = lastEntry.CreatedAt
            }

            self.pedometer.queryPedometerData(from: startDate, to: Date()) { (pedometerData, _) in
                seal.fulfill(pedometerData)
            }
        }
    }

    private func geocodeLocation(_ loc: CLLocation?) -> Promise<CLPlacemark?> {
        guard let loc = loc else { return Promise.value(nil) }
        return Promise { seal in
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(loc) { (placemark, _) in
                seal.fulfill(placemark?.last)
            }
        }
    }

    private func buildLocationPayload(updateType: LocationUpdateTrigger, location: CLLocation?,
                                      zone: RLMZone?) -> Promise<DeviceTrackerSee> {

        let device = Device()

        let payload = DeviceTrackerSee(trigger: updateType, location: location, zone: zone)
        payload.Trigger = updateType

        let isBeaconUpdate = (updateType == .BeaconRegionEnter || updateType == .BeaconRegionExit)

        payload.Battery = device.batteryLevel
        payload.DeviceID = Current.settingsStore.deviceID
        payload.Hostname = device.name
        payload.SourceType = (isBeaconUpdate ? .BluetoothLowEnergy : .GlobalPositioningSystem)

        #if os(iOS)
        payload.SSID = ConnectionInfo.currentSSID()
        payload.BSSID = ConnectionInfo.currentBSSID()
        payload.ConnectionType = Reachability.getSimpleNetworkType().description
        #endif

        return firstly {
                    when(fulfilled: self.getLatestMotionActivity(), self.getLatestPedometerData(),
                         self.geocodeLocation(location))
                }.then { motion, pedometer, placemark -> Promise<DeviceTrackerSee> in
                    if let activity = motion {
                        payload.SetActivity(activity: activity)
                    }

                    if let pedometerData = pedometer {
                        payload.SetPedometerData(pedometerData: pedometerData)
                    }

                    if let placemark = placemark {
                        payload.SetPlacemark(placemark: placemark)
                    }

                    return Promise.value(payload)
                }

    }

    private func buildWebhookLocationPayload(updateType: LocationUpdateTrigger,
                                             location: CLLocation?, zone: RLMZone?) -> Promise<WebhookUpdateLocation> {

        let device = Device()

        let payload = WebhookUpdateLocation(trigger: updateType, location: location, zone: zone)
        payload.Trigger = updateType

        let isBeaconUpdate = (updateType == .BeaconRegionEnter || updateType == .BeaconRegionExit)

        payload.Battery = device.batteryLevel
        payload.SourceType = (isBeaconUpdate ? .BluetoothLowEnergy : .GlobalPositioningSystem)

        return Promise.value(payload)

    }

    public func submitLocationWebhook(updateType: LocationUpdateTrigger,
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
            return when(fulfilled: self.updateSensors(trigger: updateType), locUpdate, Promise.value(payload))
        }.then { (resp) -> Promise<Bool> in
            Current.Log.verbose("Device seen via webhook!")
            self.sendLocalNotification(withZone: zone, updateType: updateType, payloadDict: resp.2)
            return Promise.value(true)
        }

    }

    public func submitLocation(updateType: LocationUpdateTrigger, location: CLLocation?,
                               zone: RLMZone?) -> Promise<Bool> {

        if Current.settingsStore.webhookID != nil {
            return self.submitLocationWebhook(updateType: updateType, location: location, zone: zone)
        }

        return self.buildLocationPayload(updateType: updateType,
                                         location: location, zone: zone).then { payload -> Promise<Bool> in

            var jsonPayload = "{\"missing\": \"payload\"}"
            if let p = payload.toJSONString(prettyPrint: false) {
                jsonPayload = p
            }

            let payloadDict: [String: Any] = Mapper<DeviceTrackerSee>().toJSON(payload)

            let realm = Current.realm()
            // swiftlint:disable:next force_try
            try! realm.write {
                realm.add(LocationHistoryEntry(updateType: updateType, location: payload.cllocation,
                                               zone: zone, payload: jsonPayload))
            }

            let promise = self.identifyDevice().then { _ in
                self.callService(domain: "device_tracker", service: "see", serviceData: payloadDict, shouldLog: false)
            }.then { _ -> Promise<Bool> in
                Current.Log.verbose("Device seen!")
                self.sendLocalNotification(withZone: zone, updateType: updateType, payloadDict: payloadDict)
                return Promise.value(true)
            }

            promise.catch { err in
                Current.Log.error("Error when updating location! \(err)")
            }

            return promise
        }

    }

    public func getAndSendLocation(trigger: LocationUpdateTrigger?) -> Promise<Bool> {
        var updateTrigger: LocationUpdateTrigger = .Manual
        if let trigger = trigger {
            updateTrigger = trigger
        }
        Current.Log.verbose("getAndSendLocation called via \(String(describing: updateTrigger))")

        return Promise { seal in
            Current.isPerformingSingleShotLocationQuery = true
            self.oneShotLocationManager = OneShotLocationManager { location, error in
                guard let location = location else {
                    seal.reject(error ?? HomeAssistantAPIError.unknown)
                    return
                }

                Current.isPerformingSingleShotLocationQuery = true
                firstly {
                    self.submitLocation(updateType: updateTrigger, location: location,
                                        zone: nil)
                    }.done { worked in
                        seal.fulfill(worked)
                    }.catch { error in
                        seal.reject(error)
                }
            }
        }
    }

    func sendLocalNotification(withZone: RLMZone?, updateType: LocationUpdateTrigger,
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

    public func handleAction(actionID: String, actionName: String, source: ActionSource) -> Promise<Bool> {
        return Promise { seal in
            guard let api = HomeAssistantAPI.authenticatedAPI() else {
                throw APIError.notConfigured
            }

            let device = Device()
            let eventData: [String: Any] = ["actionName": actionName,
                                            "actionID": actionID,
                                            "triggerSource": source.description,
                                            "sourceDevicePermanentID": Constants.PermanentID,
                                            "sourceDeviceName": device.name,
                                            "sourceDeviceID": Current.settingsStore.deviceID]

            Current.Log.verbose("Sending action payload: \(eventData)")

            let eventType = "ios.action_fired"
            api.createEvent(eventType: eventType, eventData: eventData).done { _ -> Void in
                seal.fulfill(true)
                }.catch {error in
                    seal.reject(error)
            }
        }
    }

    public func registerSensors() -> Promise<[WebhookSensorResponse]> {
        return firstly {
            WebhookSensors().AllSensors
        }.then { (sensors: [WebhookSensor]) -> Promise<[WebhookSensorResponse]> in

            var allSensors = sensors
            allSensors.append(WebhookSensor(name: "Last Update Trigger", uniqueID: "last_update_trigger"))

            var promises: [Promise<WebhookSensorResponse>] = []

            for sensor in allSensors {
                promises.append(self.webhook("register_sensor",
                                             payload: sensor.toJSON(), callingFunctionName: "\(#function)"))
            }

            return when(fulfilled: promises)
        }
    }

    public func updateSensors(trigger: LocationUpdateTrigger = .Unknown) -> Promise<[String: WebhookSensorResponse]> {
        return firstly {
            return WebhookSensors().AllSensors
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

            return self.registerSensors().then { _ -> Promise<[String: WebhookSensorResponse]> in
                return self.updateSensors(trigger: trigger)
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
        case .mobileAppComponentNotLoaded:
            return L10n.HaApi.ApiError.mobileAppComponentNotLoaded
        case .webhookGone:
            return L10n.HaApi.ApiError.webhookGone
        }
    }
}
