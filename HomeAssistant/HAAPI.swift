//
//  HAAPI.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Alamofire
import AlamofireObjectMapper
import PromiseKit
import Crashlytics
import CoreLocation
import CoreMotion
import DeviceKit
import Foundation
import KeychainAccess
import ObjectMapper
import RealmSwift
import Shared
import UserNotifications

// swiftlint:disable file_length

// swiftlint:disable:next type_body_length
public class HomeAssistantAPI {
    enum APIError: Error {
        case managerNotAvailable
        case invalidResponse
        case cantBuildURL
        case notConfigured
    }

    public enum AuthenticationMethod {
        case legacy(apiPassword: String?)
        case modern(tokenInfo: TokenInfo)
    }

    var pushID: String?

    var loadedComponents = [String]()

    var baseURL: URL {
        return self.connectionInfo.baseURL
    }

    var baseAPIURL: URL {
        return self.baseURL.appendingPathComponent("api")
    }

    var apiPassword: String?

    private(set) var manager: Alamofire.SessionManager!

    var regionManager = RegionManager()
    var locationManager: LocationManager?

    var cachedEntities: [Entity]?

    var notificationsEnabled: Bool {
        return prefs.bool(forKey: "notificationsEnabled")
    }

    var iosComponentLoaded: Bool {
        return self.loadedComponents.contains("ios")
    }

    var deviceTrackerComponentLoaded: Bool {
        return self.loadedComponents.contains("device_tracker")
    }

    var iosNotifyPlatformLoaded: Bool {
        return self.loadedComponents.contains("notify.ios")
    }

    var enabledPermissions: [String] {
        var permissionsContainer: [String] = []
        if self.notificationsEnabled {
            permissionsContainer.append("notifications")
        }
        if Current.settingsStore.locationEnabled {
            permissionsContainer.append("location")
        }
        return permissionsContainer
    }

    private var tokenManager: TokenManager?
    private let authenticationController = AuthenticationController()
    var connectionInfo: ConnectionInfo

    /// Initialzie an API object with an authenticated tokenManager.
    public init(connectionInfo: ConnectionInfo, authenticationMethod: AuthenticationMethod) {
        self.connectionInfo = connectionInfo

        switch authenticationMethod {
        case .legacy(let apiPassword):
            self.manager = self.configureSessionManager(withPassword: apiPassword)
        case .modern(let tokenInfo):
            self.tokenManager = TokenManager(baseURL: connectionInfo.baseURL, tokenInfo: tokenInfo)
            tokenManager?.authenticationRequiredCallback = {
                return self.authenticationController.authenticateWithBrowser(at: connectionInfo.baseURL)
            }
            let manager = self.configureSessionManager()
            manager.retrier = self.tokenManager
            manager.adapter = self.tokenManager
            self.manager = manager
        }

        let basicAuthKeychain = Keychain(server: self.baseURL.absoluteString, protocolType: .https,
                                         authenticationType: .httpBasic)
        self.configureBasicAuthWithKeychain(basicAuthKeychain)

        self.pushID = prefs.string(forKey: "pushID")

        if #available(iOS 10, *) {
            UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { (settings) in
                prefs.setValue((settings.authorizationStatus == UNAuthorizationStatus.authorized),
                               forKey: "notificationsEnabled")
            })
        }
    }

    private func configureSessionManager(withPassword password: String? = nil) -> SessionManager {
        var headers = Alamofire.SessionManager.defaultHTTPHeaders
        if let password = password {
            headers["X-HA-Access"] = password
        }

        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = headers
        configuration.timeoutIntervalForRequest = 10 // seconds
        return Alamofire.SessionManager(configuration: configuration)
    }

    fileprivate func configureBasicAuthWithKeychain(_ basicAuthKeychain: Keychain) {
        if let basicUsername = basicAuthKeychain["basicAuthUsername"],
            let basicPassword = basicAuthKeychain["basicAuthPassword"] {
            self.manager.delegate.sessionDidReceiveChallenge = { session, challenge in
                print("Received basic auth challenge")

                let authMethod = challenge.protectionSpace.authenticationMethod

                guard authMethod == NSURLAuthenticationMethodDefault ||
                    authMethod == NSURLAuthenticationMethodHTTPBasic ||
                    authMethod == NSURLAuthenticationMethodHTTPDigest else {
                        print("Not handling auth method", authMethod)
                        return (.performDefaultHandling, nil)
                }

                return (.useCredential, URLCredential(user: basicUsername, password: basicPassword,
                                                      persistence: .synchronizable))
            }
        }
    }

    func Connect() -> Promise<ConfigResponse> {
        return Promise { seal in
            GetConfig().done { config in
                if let components = config.Components {
                    self.loadedComponents = components
                }
                prefs.setValue(config.ConfigDirectory, forKey: "config_dir")
                prefs.setValue(config.LocationName, forKey: "location_name")
                prefs.setValue(config.Latitude, forKey: "latitude")
                prefs.setValue(config.Longitude, forKey: "longitude")
                prefs.setValue(config.TemperatureUnit, forKey: "temperature_unit")
                prefs.setValue(config.LengthUnit, forKey: "length_unit")
                prefs.setValue(config.MassUnit, forKey: "mass_unit")
                prefs.setValue(config.VolumeUnit, forKey: "volume_unit")
                prefs.setValue(config.Timezone, forKey: "time_zone")
                prefs.setValue(config.Version, forKey: "version")

                Crashlytics.sharedInstance().setObjectValue(config.Version, forKey: "hass_version")
                Crashlytics.sharedInstance().setObjectValue(self.loadedComponents.joined(separator: ","),
                                                            forKey: "loadedComponents")
                Crashlytics.sharedInstance().setObjectValue(self.enabledPermissions.joined(separator: ","),
                                                            forKey: "allowedPermissions")

                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "connected"),
                                                object: nil,
                                                userInfo: nil)

                _ = self.GetManifestJSON().done { manifest in
                    if let themeColor = manifest.ThemeColor {
                        prefs.setValue(themeColor, forKey: "themeColor")
                    }
                }

                _ = self.GetStates().done { entities in
                    self.cachedEntities = entities
                    self.storeEntities(entities: entities)
                    if self.loadedComponents.contains("ios") {
                        CLSLogv("iOS component loaded, attempting identify", getVaList([]))
                        _ = self.IdentifyDevice()
                    }

                    //                self.GetHistory()
                    seal.fulfill(config)
                }
            }.catch {error in
                print("Error at launch!", error)
                Crashlytics.sharedInstance().recordError(error)
                seal.reject(error)
            }

        }
    }

    public enum HomeAssistantAPIError: Error {
        case notAuthenticated
    }

    private static var sharedAPI: HomeAssistantAPI?
    public static func authenticatedAPI() -> HomeAssistantAPI? {
        if let api = sharedAPI {
            return api
        }

        guard let connectionInfo = Current.settingsStore.connectionInfo else {
            return nil
        }

        if let tokenInfo = Current.settingsStore.tokenInfo {
            let api = HomeAssistantAPI(connectionInfo: connectionInfo,
                                       authenticationMethod: .modern(tokenInfo: tokenInfo))
            self.sharedAPI = api
            return api
        } else {
            let api = HomeAssistantAPI(connectionInfo: connectionInfo,
                                       authenticationMethod: .legacy(apiPassword: keychain["apiPassword"]))
            self.sharedAPI = api
            return api
        }
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

    func submitLocation(updateType: LocationUpdateTrigger,
                        location: CLLocation?,
                        visit: CLVisit?,
                        zone: RLMZone?) {

        var loc: CLLocation = CLLocation()
        if let location = location {
            loc = location
        } else if let zone = zone {
            loc = zone.location()
        } else if let visit = visit {
            loc = visit.location()
        }

        UIDevice.current.isBatteryMonitoringEnabled = true

        let payload = DeviceTrackerSee(location: loc)
        payload.Trigger = updateType

        let isBeaconUpdate = (updateType == .BeaconRegionEnter || updateType == .BeaconRegionExit)

        payload.Battery = UIDevice.current.batteryLevel
        payload.DeviceID = Current.settingsStore.deviceID
        payload.Hostname = UIDevice.current.name
        payload.SourceType = (isBeaconUpdate ? .BluetoothLowEnergy : .GlobalPositioningSystem)

        if let activity = self.regionManager.lastActivity {
            payload.ActivityType = activity.activityType
            payload.ActivityConfidence = activity.confidence.description
        }

        if let zone = zone, zone.ID == "zone.home" {
            if updateType == .BeaconRegionEnter || updateType == .RegionEnter {
                payload.LocationName = "home"
            } else if updateType == .BeaconRegionExit || updateType == .RegionExit {
                payload.LocationName = "not_home"
            }
        }

        var jsonPayload = "{\"missing\": \"payload\"}"
        if let p = payload.toJSONString(prettyPrint: false) {
            jsonPayload = p
        }

        let payloadDict: [String: Any] = Mapper<DeviceTrackerSee>().toJSON(payload)

        UIDevice.current.isBatteryMonitoringEnabled = false

        let realm = Current.realm()
        // swiftlint:disable:next force_try
        try! realm.write {
            realm.add(LocationHistoryEntry(updateType: updateType, location: loc,
                                           zone: zone, payload: jsonPayload))
        }

        if self.regionManager.checkIfInsideAnyRegions(location: loc.coordinate).count > 0 {
            print("Not submitting location change since we are already inside of a zone")
            for activeZone in self.regionManager.zones {
                print("Zone check", activeZone.ID, activeZone.inRegion)
            }
            return
        }

        firstly {
            self.IdentifyDevice()
        }.then {_ in
            self.CallService(domain: "device_tracker", service: "see", serviceData: payloadDict,
                             shouldLog: false)
        }.done { _ in
            print("Device seen!")
        }.catch { err in
            print("Error when updating location!", err)
            Crashlytics.sharedInstance().recordError(err as NSError)
        }

        self.sendLocalNotification(withZone: zone, updateType: updateType, payloadDict: payloadDict)
    }

    func getAndSendLocation(trigger: LocationUpdateTrigger?) -> Promise<Bool> {
        var updateTrigger: LocationUpdateTrigger = .Manual
        if let trigger = trigger {
            updateTrigger = trigger
        }
        print("getAndSendLocation called via", String(describing: updateTrigger))

        return Promise { seal in
            regionManager.oneShotLocationActive = true
            locationManager = LocationManager { location, error in
                self.regionManager.oneShotLocationActive = false
                if let location = location {
                    self.submitLocation(updateType: updateTrigger, location: location, visit: nil, zone: nil)
                    seal.fulfill(true)
                    return
                }
                if let error = error {
                    seal.reject(error)
                }
            }
        }
    }

    func GetManifestJSON() -> Promise<ManifestJSON> {
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
                            CLSLogv("Error on GetManifestJSON() request: %@", getVaList([error.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(error)
                            seal.reject(error)
                        }
                }
            } else {
                seal.reject(APIError.managerNotAvailable)
            }
        }
    }

    func GetStatus() -> Promise<StatusResponse> {
        return self.request(path: "", callingFunctionName: "\(#function)", method: .get)
    }

    func GetConfig() -> Promise<ConfigResponse> {
        return self.request(path: "config", callingFunctionName: "\(#function)")
    }

    func GetServices() -> Promise<[ServicesResponse]> {
        return self.request(path: "services", callingFunctionName: "\(#function)")
    }

    func GetStates() -> Promise<[Entity]> {
        return self.request(path: "states", callingFunctionName: "\(#function)")
    }

    func GetEntityState(entityId: String) -> Promise<Entity> {
        return self.request(path: "states/\(entityId)", callingFunctionName: "\(#function)")
    }

    func SetState(entityId: String, state: String) -> Promise<Entity> {
        return self.request(path: "states/\(entityId)", callingFunctionName: "\(#function)", method: .post,
                            parameters: ["state": state], encoding: JSONEncoding.default)
    }

    func CreateEvent(eventType: String, eventData: [String: Any]) -> Promise<String> {
        return Promise { seal in
            let queryUrl = self.baseAPIURL.appendingPathComponent("events/\(eventType)")
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
                        CLSLogv("Error when attemping to CreateEvent(): %@",
                                getVaList([error.localizedDescription]))
                        Crashlytics.sharedInstance().recordError(error)
                        seal.reject(error)
                    }
            }
        }
    }

    func CallService(domain: String, service: String, serviceData: [String: Any], shouldLog: Bool = true)
        -> Promise<[Entity]> {
        return Promise { seal in
            let queryUrl = self.baseAPIURL.appendingPathComponent("services/\(domain)/\(service)")
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
                                if let errorJSON = convertToDictionary(text: utf8Text),
                                    let errMessage = errorJSON["message"] as? String {
                                    errorUserInfo["errorMessage"] = errMessage
                                }
                            }
                            CLSLogv("Error on CallService() request: %@", getVaList([afError.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(afError)
                            let customError = NSError(domain: "io.robbie.HomeAssistant",
                                                      code: afError.responseCode!,
                                                      userInfo: errorUserInfo)
                            seal.reject(customError)
                        } else {
                            CLSLogv("Error on CallService() request: %@", getVaList([error.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(error)
                            seal.reject(error)
                        }
                    }
            }
        }
    }

    func GetDiscoveryInfo(baseUrl: URL) -> Promise<DiscoveryInfoResponse> {
        return self.request(path: "discover_info", callingFunctionName: "\(#function)")
    }

    func IdentifyDevice() -> Promise<String> {
        return self.request(path: "ios/identify", callingFunctionName: "\(#function)", method: .post,
                     parameters: buildIdentifyDict(), encoding: JSONEncoding.default)
    }

    func RemoveDevice() -> Promise<String> {
        return self.request(path: "ios/identify", callingFunctionName: "\(#function)", method: .delete,
                            parameters: buildRemovalDict(), encoding: JSONEncoding.default)
    }

    func RegisterDeviceForPush(deviceToken: String) -> Promise<PushRegistrationResponse> {
        let queryUrl = "https://ios-push.home-assistant.io/registrations"
        return Promise { seal in
            Alamofire.request(queryUrl,
                              method: .post,
                              parameters: buildPushRegistrationDict(deviceToken: deviceToken),
                              encoding: JSONEncoding.default
                ).validate().responseObject {(response: DataResponse<PushRegistrationResponse>) in
                    switch response.result {
                    case .success:
                        if let json = response.result.value {
                            seal.fulfill(json)
                        } else {
                            let retErr = NSError(domain: "io.robbie.HomeAssistant",
                                                 code: 404,
                                                 userInfo: ["message": "json was nil!"])
                            CLSLogv("Error when attemping to registerDeviceForPush(), json was nil!: %@",
                                    getVaList([retErr.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(retErr)
                            seal.reject(retErr)
                        }
                    case .failure(let error):
                        CLSLogv("Error when attemping to registerDeviceForPush(): %@",
                                getVaList([error.localizedDescription]))
                        Crashlytics.sharedInstance().recordError(error)
                        seal.reject(error)
                    }
            }
        }
    }

    func GetPushSettings() -> Promise<PushConfiguration> {
        return self.request(path: "ios/push", callingFunctionName: "\(#function)")
    }

    func turnOn(entityId: String) -> Promise<[Entity]> {
        return CallService(domain: "homeassistant", service: "turn_on", serviceData: ["entity_id": entityId])
    }

    func turnOnEntity(entity: Entity) -> Promise<[Entity]> {
        return CallService(domain: "homeassistant", service: "turn_on", serviceData: ["entity_id": entity.ID])
    }

    func turnOff(entityId: String) -> Promise<[Entity]> {
        return CallService(domain: "homeassistant", service: "turn_off", serviceData: ["entity_id": entityId])
    }

    func turnOffEntity(entity: Entity) -> Promise<[Entity]> {
        return CallService(domain: "homeassistant", service: "turn_off", serviceData: ["entity_id": entity.ID])
    }

    func toggle(entityId: String) -> Promise<[Entity]> {
        return CallService(domain: "homeassistant", service: "toggle", serviceData: ["entity_id": entityId])
    }

    func toggleEntity(entity: Entity) -> Promise<[Entity]> {
        return CallService(domain: "homeassistant", service: "toggle", serviceData: ["entity_id": entity.ID])
    }

    func buildIdentifyDict() -> [String: Any] {
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
        ident.DevicePermanentID = DeviceUID.uid()
        ident.DeviceSystemName = deviceKitDevice.systemName
        ident.DeviceSystemVersion = deviceKitDevice.systemVersion
        ident.DeviceType = deviceKitDevice.description
        ident.Permissions = self.enabledPermissions
        ident.PushID = pushID
        ident.PushSounds = listAllInstalledPushNotificationSounds()

        UIDevice.current.isBatteryMonitoringEnabled = true

        switch UIDevice.current.batteryState {
        case .unknown:
            ident.BatteryState = "Unknown"
        case .charging:
            ident.BatteryState = "Charging"
        case .unplugged:
            ident.BatteryState = "Unplugged"
        case .full:
            ident.BatteryState = "Full"
        }

        ident.BatteryLevel = Int(UIDevice.current.batteryLevel*100)
        if ident.BatteryLevel == -100 { // simulator fix
            ident.BatteryLevel = 100
        }

        UIDevice.current.isBatteryMonitoringEnabled = false

        return Mapper().toJSON(ident)
    }

    func buildPushRegistrationDict(deviceToken: String) -> [String: Any] {
        let deviceKitDevice = Device()

        let ident = PushRegistrationRequest()
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
        if let isSandboxed = Bundle.main.object(forInfoDictionaryKey: "IS_SANDBOXED") {
            if let stringedisSandboxed = isSandboxed as? String {
                ident.APNSSandbox = (stringedisSandboxed == "true")
            }
        }
        ident.AppBundleIdentifer = Bundle.main.bundleIdentifier
        ident.DeviceID = Current.settingsStore.deviceID
        ident.DeviceName = deviceKitDevice.name
        ident.DevicePermanentID = DeviceUID.uid()
        ident.DeviceSystemName = deviceKitDevice.systemName
        ident.DeviceSystemVersion = deviceKitDevice.systemVersion
        ident.DeviceType = deviceKitDevice.description
        ident.DeviceTimezone = (NSTimeZone.local as NSTimeZone).name
        ident.PushSounds = listAllInstalledPushNotificationSounds()
        ident.PushToken = deviceToken
        if let email = prefs.string(forKey: "userEmail") {
            ident.UserEmail = email
        }
        if let version = prefs.string(forKey: "version") {
            ident.HomeAssistantVersion = version
        }
        if let timeZone = prefs.string(forKey: "time_zone") {
            ident.HomeAssistantTimezone = timeZone
        }

        return Mapper().toJSON(ident)
    }

    func buildRemovalDict() -> [String: Any] {
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
        ident.DevicePermanentID = DeviceUID.uid()
        ident.DeviceSystemName = deviceKitDevice.systemName
        ident.DeviceSystemVersion = deviceKitDevice.systemVersion
        ident.DeviceType = deviceKitDevice.description
        ident.Permissions = self.enabledPermissions
        ident.PushID = pushID
        ident.PushSounds = listAllInstalledPushNotificationSounds()

        return Mapper().toJSON(ident)
    }

    func setupPushActions() -> Promise<Set<UIUserNotificationCategory>> {
        return Promise { seal in
            self.GetPushSettings().done { pushSettings in
                var allCategories = Set<UIMutableUserNotificationCategory>()
                if let categories = pushSettings.Categories {
                    for category in categories {
                        let finalCategory = UIMutableUserNotificationCategory()
                        finalCategory.identifier = category.Identifier
                        var categoryActions = [UIMutableUserNotificationAction]()
                        if let actions = category.Actions {
                            for action in actions {
                                let newAction = UIMutableUserNotificationAction()
                                newAction.title = action.Title
                                newAction.identifier = action.Identifier
                                newAction.isAuthenticationRequired = action.AuthenticationRequired
                                newAction.isDestructive = action.Destructive
                                var behavior: UIUserNotificationActionBehavior = .default
                                if action.Behavior.lowercased() == "textinput" {
                                    behavior = .textInput
                                }
                                newAction.behavior = behavior
                                let foreground = UIUserNotificationActivationMode.foreground
                                let background = UIUserNotificationActivationMode.background
                                let mode = (action.ActivationMode == "foreground") ? foreground : background
                                newAction.activationMode = mode
                                if let textInputButtonTitle = action.TextInputButtonTitle {
                                    let titleKey = UIUserNotificationTextInputActionButtonTitleKey
                                    newAction.parameters[titleKey] = textInputButtonTitle
                                }
                                categoryActions.append(newAction)
                            }
                            finalCategory.setActions(categoryActions,
                                                     for: UIUserNotificationActionContext.default)
                            allCategories.insert(finalCategory)
                        } else {
                            print("Category has no actions defined, continuing loop")
                            continue
                        }
                    }
                }
                seal.fulfill(allCategories)
            }.catch { error in
                CLSLogv("Error on setupPushActions() request: %@", getVaList([error.localizedDescription]))
                Crashlytics.sharedInstance().recordError(error)
                seal.reject(error)
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
            if #available(iOS 10, *) {
                let content = UNMutableNotificationContent()
                content.title = notificationOptions.title
                content.body = notificationOptions.body
                content.sound = UNNotificationSound.default()

                let notificationRequest =
                    UNNotificationRequest.init(identifier: notificationOptions.identifier ?? "",
                        content: content, trigger: nil)
                UNUserNotificationCenter.current().add(notificationRequest)
            } else {
                let notification = UILocalNotification()
                notification.alertTitle = notificationOptions.title
                notification.alertBody = notificationOptions.body
                notification.alertAction = "open"
                notification.fireDate = NSDate() as Date
                notification.soundName = UILocalNotificationDefaultSoundName
                UIApplication.shared.scheduleLocalNotification(notification)
            }
        }
    }

    @available(iOS 10, *)
    func setupUserNotificationPushActions() -> Promise<Set<UNNotificationCategory>> {
        return Promise { seal in
            self.GetPushSettings().done { pushSettings in
                var allCategories = Set<UNNotificationCategory>()
                if let categories = pushSettings.Categories {
                    for category in categories {
                        var categoryActions = [UNNotificationAction]()
                        if let actions = category.Actions {
                            for action in actions {
                                var actionOptions = UNNotificationActionOptions([])
                                if action.AuthenticationRequired { actionOptions.insert(.authenticationRequired) }
                                if action.Destructive { actionOptions.insert(.destructive) }
                                if action.ActivationMode == "foreground" { actionOptions.insert(.foreground) }
                                var newAction = UNNotificationAction(identifier: action.Identifier,
                                                                     title: action.Title, options: actionOptions)
                                if action.Behavior.lowercased() == "textinput",
                                    let btnTitle = action.TextInputButtonTitle,
                                    let place = action.TextInputPlaceholder {
                                        newAction = UNTextInputNotificationAction(identifier: action.Identifier,
                                                                                  title: action.Title,
                                                                                  options: actionOptions,
                                                                                  textInputButtonTitle: btnTitle,
                                                                                  textInputPlaceholder: place)
                                }
                                categoryActions.append(newAction)
                            }
                        } else {
                            continue
                        }
                        let finalCategory = UNNotificationCategory.init(identifier: category.Identifier,
                                                                        actions: categoryActions,
                                                                        intentIdentifiers: [],
                                                                        options: [.customDismissAction])
                        allCategories.insert(finalCategory)
                    }
                }
                seal.fulfill(allCategories)
            }.catch { error in
                CLSLogv("Error on setupUserNotificationPushActions() request: %@",
                        getVaList([error.localizedDescription]))
                Crashlytics.sharedInstance().recordError(error)
                seal.reject(error)
            }
        }
    }

    func setupPush() {
        DispatchQueue.main.async(execute: {
            UIApplication.shared.registerForRemoteNotifications()
        })
        if #available(iOS 10, *) {
            self.setupUserNotificationPushActions().done { categories in
                UNUserNotificationCenter.current().setNotificationCategories(categories)
                }.catch {error -> Void in
                    print("Error when attempting to setup push actions", error)
                    Crashlytics.sharedInstance().recordError(error)
            }
        } else {
            self.setupPushActions().done { categories in
                let types: UIUserNotificationType = ([.alert, .badge, .sound])
                let settings = UIUserNotificationSettings(types: types, categories: categories)
                UIApplication.shared.registerUserNotificationSettings(settings)
                }.catch {error -> Void in
                    print("Error when attempting to setup push actions", error)
                    Crashlytics.sharedInstance().recordError(error)
            }
        }
    }

    func handlePushAction(identifier: String, userInfo: [AnyHashable: Any], userInput: String?) -> Promise<Bool> {
        return Promise { seal in
            guard let api = HomeAssistantAPI.authenticatedAPI() else {
                throw APIError.notConfigured
            }

            let device = Device()
            var eventData: [String: Any] = ["actionName": identifier,
                                           "sourceDevicePermanentID": DeviceUID.uid(),
                                           "sourceDeviceName": device.name,
                                           "sourceDeviceID": Current.settingsStore.deviceID]
            if let dataDict = userInfo["homeassistant"] {
                eventData["action_data"] = dataDict
            }
            if let textInput = userInput {
                eventData["response_info"] = textInput
                eventData["textInput"] = textInput
            }

            let eventType = "ios.notification_action_fired"
            api.CreateEvent(eventType: eventType, eventData: eventData).done { _ -> Void in
                seal.fulfill(true)
                }.catch {error in
                    Crashlytics.sharedInstance().recordError(error)
                    seal.reject(error)
            }
        }
    }

    func storeEntities(entities: [Entity]) {
        let storeableComponents = ["zone"]
        let storeableEntities = entities.filter { (entity) -> Bool in
            return storeableComponents.contains(entity.Domain)
        }

        for entity in storeableEntities {
            // print("Storing \(entity.ID)")

            if entity.Domain == "zone", let zone = entity as? Zone {
                let storeableZone = RLMZone()
                storeableZone.ID = zone.ID
                storeableZone.Latitude = zone.Latitude
                storeableZone.Longitude = zone.Longitude
                storeableZone.Radius = zone.Radius
                storeableZone.TrackingEnabled = zone.TrackingEnabled
                storeableZone.BeaconUUID = zone.UUID
                storeableZone.BeaconMajor.value = zone.Major
                storeableZone.BeaconMinor.value = zone.Minor

                let realm = Current.realm()
                // swiftlint:disable:next force_try
                try! realm.write {
                    realm.add(RLMZone(zone: zone), update: true)
                }
            }
        }
    }
}

enum LocationUpdateTrigger: String {
    struct NotificationOptions {
        let shouldNotify: Bool
        let identifier: String?
        let title: String
        let body: String
    }

    case Visit = "Visit"
    case RegionEnter = "Geographic Region Entered"
    case RegionExit = "Geographic Region Exited"
    case BeaconRegionEnter = "iBeacon Region Entered"
    case BeaconRegionExit = "iBeacon Region Exited"
    case Manual = "Manual"
    case SignificantLocationUpdate = "Significant Location Update"
    case BackgroundFetch = "Background Fetch"
    case PushNotification = "Push Notification"
    case URLScheme = "URL Scheme"
    case Unknown = "Unknown"

    func notificationOptionsFor(zoneName: String) -> NotificationOptions {
        let shouldNotify: Bool
        var identifier: String = ""
        let body: String
        let title = "Location change"

        switch self {
        case .BeaconRegionEnter:
            body = L10n.LocationChangeNotification.BeaconRegionEnter.body(zoneName)
            identifier = "\(zoneName)_beacon_entered"
            shouldNotify = prefs.bool(forKey: "beaconEnterNotifications")
        case .BeaconRegionExit:
            body = L10n.LocationChangeNotification.BeaconRegionExit.body(zoneName)
            identifier = "\(zoneName)_beacon_exited"
            shouldNotify = prefs.bool(forKey: "beaconExitNotifications")
        case .RegionEnter:
            body = L10n.LocationChangeNotification.RegionEnter.body(zoneName)
            identifier = "\(zoneName)_entered"
            shouldNotify = prefs.bool(forKey: "enterNotifications")
        case .RegionExit:
            body = L10n.LocationChangeNotification.RegionExit.body(zoneName)
            identifier = "\(zoneName)_exited"
            shouldNotify = prefs.bool(forKey: "exitNotifications")
        case .SignificantLocationUpdate:
            body = L10n.LocationChangeNotification.SignificantLocationUpdate.body
            identifier = "sig_change"
            shouldNotify = prefs.bool(forKey: "significantLocationChangeNotifications")
        case .BackgroundFetch:
            body = L10n.LocationChangeNotification.BackgroundFetch.body
            identifier = "background_fetch"
            shouldNotify = prefs.bool(forKey: "backgroundFetchLocationChangeNotifications")
        case .PushNotification:
            body = L10n.LocationChangeNotification.PushNotification.body
            identifier = "push_notification"
            shouldNotify = prefs.bool(forKey: "pushLocationRequestNotifications")
        case .URLScheme:
            body = L10n.LocationChangeNotification.UrlScheme.body
            identifier = "url_scheme"
            shouldNotify = prefs.bool(forKey: "urlSchemeLocationRequestNotifications")
        case .Visit:
            body = L10n.LocationChangeNotification.Visit.body
            identifier = "visit"
            shouldNotify = prefs.bool(forKey: "visitLocationRequestNotifications")
        case .Manual:
            body = L10n.LocationChangeNotification.Manual.body
            shouldNotify = false
        case .Unknown:
            body = L10n.LocationChangeNotification.Unknown.body
            shouldNotify = false
        }

        return NotificationOptions(shouldNotify: shouldNotify, identifier: identifier, title: title, body: body)
    }
}

extension CMMotionActivity {
    var activityType: String {
        if self.walking {
            return "Walking"
        } else if self.running {
            return "Running"
        } else if self.automotive {
            return "Automotive"
        } else if self.cycling {
            return "Cycling"
        } else if self.stationary {
            return "Stationary"
        } else {
            return "Unknown"
        }
    }
}

extension CMMotionActivityConfidence {
    var description: String {
        if self == CMMotionActivityConfidence.low {
            return "Low"
        } else if self == CMMotionActivityConfidence.medium {
            return "Medium"
        } else if self == CMMotionActivityConfidence.high {
            return "High"
        }
        return "Unknown"
    }
}
