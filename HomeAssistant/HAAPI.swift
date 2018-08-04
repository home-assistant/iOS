//
//  HAAPI.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import Alamofire
import PromiseKit
import CoreLocation
import AlamofireObjectMapper
import ObjectMapper
import DeviceKit
//import Crashlytics
import UserNotifications
import RealmSwift
import CoreMotion
import Shared
import SystemConfiguration.CaptiveNetwork
import KeychainAccess
import Intents

let APIClientSharedInstance = HomeAssistantAPI()

// swiftlint:disable file_length

// swiftlint:disable:next type_body_length
public class HomeAssistantAPI {

    class var sharedInstance: HomeAssistantAPI {
        return APIClientSharedInstance
    }

    enum APIError: Error {
        case managerNotAvailable
        case invalidResponse
        case cantBuildURL
    }

    var deviceID: String = removeSpecialCharsFromString(text: UIDevice.current.name)
                            .replacingOccurrences(of: " ", with: "_")
                            .lowercased()
    var pushID: String?

    var loadedComponents = [String]()

    var baseURL: URL?
    var baseAPIURL: URL?
    var apiPassword: String?

    private var manager: Alamofire.SessionManager?

    var regionManager = RegionManager()
    var locationManager: LocationManager?

    var cachedEntities: [Entity]?

    var Configured: Bool {
        return self.baseURL != nil
    }

    var locationEnabled: Bool {
        return prefs.bool(forKey: "locationEnabled")
    }

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
        if self.locationEnabled {
            permissionsContainer.append("location")
        }
        return permissionsContainer
    }

    func Setup(baseURLString: String?, password: String?, deviceID: String?) {
        let keychain = Keychain(service: "io.robbie.homeassistant")

        if let ssid = keychain["internalBaseURLSSID"], let internalURL = keychain["internalBaseURL"],
            ssid == getSSID() {
            self.baseURL = URL(string: internalURL)
            self.baseAPIURL = self.baseURL?.appendingPathComponent("api")
        } else if let baseURLString = baseURLString {
            if let baseURL = URL(string: baseURLString) {
                if self.Configured && self.baseURL == baseURL && self.apiPassword == password &&
                    self.deviceID == deviceID {
                    print("HAAPI already configured, returning from Setup")
                    return
                }

                self.baseURL = baseURL
                self.baseAPIURL = self.baseURL?.appendingPathComponent("api")
            }
        }

        var headers = [String: String]()
        if let password = password {
            headers["X-HA-Access"] = password
        }
        if let deviceID = deviceID {
            self.deviceID = deviceID
        }

        pushID = prefs.string(forKey: "pushID")

        var defaultHeaders = Alamofire.SessionManager.defaultHTTPHeaders
        for (header, value) in headers {
            defaultHeaders[header] = value
        }

        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = defaultHeaders
        configuration.timeoutIntervalForRequest = 10 // seconds

        self.manager = Alamofire.SessionManager(configuration: configuration)

        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { (settings) in
            prefs.setValue((settings.authorizationStatus == UNAuthorizationStatus.authorized),
                           forKey: "notificationsEnabled")
        })

        if let basicUsername = keychain["basicAuthUsername"], let basicPassword = keychain["basicAuthPassword"] {
            self.manager?.delegate.sessionDidReceiveChallenge = { session, challenge in
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

        return

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

                // TO-DO Crashlytics.sharedInstance().setObjectValue(config.Version, forKey: "hass_version")
                // TO-DO Crashlytics.sharedInstance().setObjectValue(self.loadedComponents.joined(separator: ","),
//                                                            forKey: "loadedComponents")
                // TO-DO Crashlytics.sharedInstance().setObjectValue(self.enabledPermissions.joined(separator: ","),
//                                                            forKey: "allowedPermissions")

                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "connected"),
                                                object: nil,
                                                userInfo: nil)

                _ = self.GetManifestJSON().done { manifest in
                    if let themeColor = manifest.ThemeColor {
                        prefs.setValue(themeColor, forKey: "themeColor")
                    }
                }

                _ = self.GetStates().done { _ in
                    if self.loadedComponents.contains("ios") {
//                        CLSLogv("iOS component loaded, attempting identify", getVaList([]))
                        _ = self.IdentifyDevice()
                    }

                    //                self.GetHistory()
                    seal.fulfill(config)
                }
            }.catch {error in
                print("Error at launch!", error)
                // TO-DO Crashlytics.sharedInstance().recordError(error)
                seal.reject(error)
            }

        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
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
        payload.DeviceID = deviceID
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
            // TO-DO Crashlytics.sharedInstance().recordError(err as NSError)
        }

        let notificationTitle = "Location change"
        var notificationBody = ""
        var notificationIdentifer = ""
        var shouldNotify = false

        var zoneName = "Unknown zone"
        var zoneRelated = false
        if let zone = zone {
            zoneName = zone.Name
            zoneRelated = true
        }

        switch updateType {
        case .BeaconRegionEnter:
            notificationBody = L10n.LocationChangeNotification.BeaconRegionEnter.body(zoneName)
            notificationIdentifer = "\(zoneName)_beacon_entered"
            shouldNotify = prefs.bool(forKey: "beaconEnterNotifications")
        case .BeaconRegionExit:
            notificationBody = L10n.LocationChangeNotification.BeaconRegionExit.body(zoneName)
            notificationIdentifer = "\(zoneName)_beacon_exited"
            shouldNotify = prefs.bool(forKey: "beaconExitNotifications")
        case .RegionEnter:
            notificationBody = L10n.LocationChangeNotification.RegionEnter.body(zoneName)
            notificationIdentifer = "\(zoneName)_entered"
            shouldNotify = prefs.bool(forKey: "enterNotifications")
        case .RegionExit:
            notificationBody = L10n.LocationChangeNotification.RegionExit.body(zoneName)
            notificationIdentifer = "\(zoneName)_exited"
            shouldNotify = prefs.bool(forKey: "exitNotifications")
        case .SignificantLocationUpdate:
            notificationBody = L10n.LocationChangeNotification.SignificantLocationUpdate.body
            notificationIdentifer = "sig_change"
            shouldNotify = prefs.bool(forKey: "significantLocationChangeNotifications")
        case .BackgroundFetch:
            notificationBody = L10n.LocationChangeNotification.BackgroundFetch.body
            notificationIdentifer = "background_fetch"
            shouldNotify = prefs.bool(forKey: "backgroundFetchLocationChangeNotifications")
        case .PushNotification:
            notificationBody = L10n.LocationChangeNotification.PushNotification.body
            notificationIdentifer = "push_notification"
            shouldNotify = prefs.bool(forKey: "pushLocationRequestNotifications")
        case .URLScheme:
            notificationBody = L10n.LocationChangeNotification.UrlScheme.body
            notificationIdentifer = "url_scheme"
            shouldNotify = prefs.bool(forKey: "urlSchemeLocationRequestNotifications")
        case .Visit:
            notificationBody = L10n.LocationChangeNotification.Visit.body
            notificationIdentifer = "visit"
            shouldNotify = prefs.bool(forKey: "visitLocationRequestNotifications")
        case .Manual:
            notificationBody = L10n.LocationChangeNotification.Manual.body
            shouldNotify = false
        case .Unknown:
            notificationBody = L10n.LocationChangeNotification.Unknown.body
            shouldNotify = false
        }

        Current.clientEventStore.addEvent(ClientEvent(text: notificationBody, type: .locationUpdate,
                                                      payload: payloadDict))
        if shouldNotify {
            let content = UNMutableNotificationContent()
            content.title = notificationTitle
            content.body = notificationBody
            content.sound = UNNotificationSound.default

            if zoneRelated {
                content.threadIdentifier = zoneName
            } else {
                // Group all location notifications together as "location" if they aren't generated from a zone.
                content.threadIdentifier = "location"
            }

            UNUserNotificationCenter.current().add(UNNotificationRequest.init(identifier: notificationIdentifer,
                                                                              content: content, trigger: nil))
        }

        if #available(iOS 12.0, *) {
            let intent = SendLocationIntent()

            let interaction = INInteraction(intent: intent, response: nil)

            interaction.donate { (error) in
                if error != nil {
                    if let error = error as NSError? {
                        print("Interaction donation failed: \(error)")
                    } else {
                        print("Successfully donated interaction")
                    }
                } else {
                    print("Donated send location interaction")
                }
            }
        }

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
            if let manager = self.manager, let queryUrl = baseURL?.appendingPathComponent("manifest.json") {
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
//                            CLSLogv("Error on GetManifestJSON() request: %@", getVaList([error.localizedDescription]))
                            // TO-DO Crashlytics.sharedInstance().recordError(error)
                            seal.reject(error)
                        }
                }
            } else {
                seal.reject(APIError.managerNotAvailable)
            }
        }
    }

    func GetStatus() -> Promise<StatusResponse> {
        return Promise { seal in
            if let manager = self.manager, let queryUrl = baseAPIURL {
                _ = manager.request(queryUrl, method: .get)
                           .validate()
                           .responseObject { (response: DataResponse<StatusResponse>) in
                                switch response.result {
                                case .success:
                                    if let resVal = response.result.value {
                                        seal.fulfill(resVal)
                                    } else {
                                        seal.reject(APIError.invalidResponse)
                                    }
                                case .failure(let error):
//                                    CLSLogv("Error on GetStatus() request: %@",
//                                            getVaList([error.localizedDescription]))
                                    // TO-DO Crashlytics.sharedInstance().recordError(error)
                                    seal.reject(error)
                                }
                            }
            } else {
                seal.reject(APIError.managerNotAvailable)
            }
        }
    }

    func GetConfig() -> Promise<ConfigResponse> {
        return Promise { seal in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("config") {
                _ = manager.request(queryUrl, method: .get)
                           .validate()
                           .responseObject { (response: DataResponse<ConfigResponse>) in
                            switch response.result {
                            case .success:
                                if let resVal = response.result.value {
                                    seal.fulfill(resVal)
                                } else {
                                    seal.reject(APIError.invalidResponse)
                                }
                            case .failure(let error):
//                                CLSLogv("Error on GetConfig() request: %@", getVaList([error.localizedDescription]))
                                // TO-DO Crashlytics.sharedInstance().recordError(error)
                                seal.reject(error)
                            }
                }
            } else {
                seal.reject(APIError.managerNotAvailable)
            }
        }
    }

    func GetServices() -> Promise<[ServicesResponse]> {
        return Promise { seal in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("services") {
                _ = manager.request(queryUrl, method: .get)
                    .validate()
                    .responseArray { (response: DataResponse<[ServicesResponse]>) in
                        switch response.result {
                        case .success:
                            if let resVal = response.result.value {
                                seal.fulfill(resVal)
                            } else {
                                seal.reject(APIError.invalidResponse)
                            }
                        case .failure(let error):
//                            CLSLogv("Error on GetServices() request: %@", getVaList([error.localizedDescription]))
                            // TO-DO Crashlytics.sharedInstance().recordError(error)
                            seal.reject(error)
                        }
                }
            } else {
                seal.reject(APIError.managerNotAvailable)
            }
        }
    }

    func GetStates() -> Promise<[Entity]> {
        return Promise { seal in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("states") {
                _ = manager.request(queryUrl, method: .get)
                    .validate()
                    .responseArray { (response: DataResponse<[Entity]>) in
                        switch response.result {
                        case .success:
                            if let resVal = response.result.value {
                                self.cachedEntities = resVal
                                self.storeEntities(entities: resVal)
                                seal.fulfill(resVal)
                            } else {
                                seal.reject(APIError.invalidResponse)
                            }
                        case .failure(let error):
//                            CLSLogv("Error on GetStates() request: %@", getVaList([error.localizedDescription]))
                            // TO-DO Crashlytics.sharedInstance().recordError(error)
                            seal.reject(error)
                        }
                }
            } else {
                seal.reject(APIError.managerNotAvailable)
            }
        }
    }

    func GetEntityState(entityId: String) -> Promise<Entity> {
        return Promise { seal in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("states/\(entityId)") {
                _ = manager.request(queryUrl, method: .get)
                    .validate()
                    .responseObject { (response: DataResponse<Entity>) in
                        switch response.result {
                        case .success:
                            if let resVal = response.result.value {
                                seal.fulfill(resVal)
                            } else {
                                seal.reject(APIError.invalidResponse)
                            }
                        case .failure(let error):
//                            CLSLogv("Error on GetEntityState() request: %@", getVaList([error.localizedDescription]))
                            // TO-DO Crashlytics.sharedInstance().recordError(error)
                            seal.reject(error)
                        }
                }
            } else {
                seal.reject(APIError.managerNotAvailable)
            }
        }
    }

    func SetState(entityId: String, state: String) -> Promise<Entity> {
        return Promise { seal in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("states/\(entityId)") {
                _ = manager.request(queryUrl, method: .post,
                                          parameters: ["state": state], encoding: JSONEncoding.default)
                                 .validate()
                                 .responseObject { (response: DataResponse<Entity>) in
                                    switch response.result {
                                    case .success:
                                        if let resVal = response.result.value {
                                            seal.fulfill(resVal)
                                        } else {
                                            seal.reject(APIError.invalidResponse)
                                        }
                                    case .failure(let error):
//                                        CLSLogv("Error when attemping to SetState(): %@",
//                                                getVaList([error.localizedDescription]))
                                        // TO-DO Crashlytics.sharedInstance().recordError(error)
                                        seal.reject(error)
                                    }
                                  }
            } else {
                seal.reject(APIError.managerNotAvailable)
            }
        }
    }

    func CreateEvent(eventType: String, eventData: [String: Any]) -> Promise<String> {
        return Promise { seal in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("events/\(eventType)") {
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
                            if let afError = error as? AFError {
//                                CLSLogv("Error when attemping to CreateEvent(): %@",
//                                        getVaList([afError.localizedDescription]))
                                // TO-DO Crashlytics.sharedInstance().recordError(afError)
                                seal.reject(afError)
                            }
//                            CLSLogv("Error when attemping to CreateEvent(): %@",
//                                    getVaList([error.localizedDescription]))
                            // TO-DO Crashlytics.sharedInstance().recordError(error)
                            seal.reject(error)
                        }
                }
            } else {
                seal.reject(APIError.managerNotAvailable)
            }
        }
    }

    func CallService(domain: String, service: String, serviceData: [String: Any], shouldLog: Bool = true)
        -> Promise<[Entity]> {
        return Promise { seal in

            guard let manager = self.manager,
                let queryUrl = baseAPIURL?.appendingPathComponent("services/\(domain)/\(service)") else {
                    seal.reject(APIError.managerNotAvailable)
                    return
            }
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
//                            CLSLogv("Error on CallService() request: %@", getVaList([afError.localizedDescription]))
                            // TO-DO Crashlytics.sharedInstance().recordError(afError)
                            let customError = NSError(domain: "io.robbie.HomeAssistant",
                                                      code: afError.responseCode!,
                                                      userInfo: errorUserInfo)
                            seal.reject(customError)
                        } else {
//                            CLSLogv("Error on CallService() request: %@", getVaList([error.localizedDescription]))
                            // TO-DO Crashlytics.sharedInstance().recordError(error)
                            seal.reject(error)
                        }
                    }
            }
        }
    }

    func GetDiscoveryInfo(baseUrl: URL) -> Promise<DiscoveryInfoResponse> {
        return Promise { seal in
            _ = Alamofire.request(baseUrl.appendingPathComponent("/api/discovery_info"))
                         .validate()
                         .responseObject { (response: DataResponse<DiscoveryInfoResponse>) -> Void in
                            switch response.result {
                            case .success:
                                if let resVal = response.result.value {
                                    seal.fulfill(resVal)
                                } else {
                                    seal.reject(APIError.invalidResponse)
                                }
                            case .failure(let error):
//                                CLSLogv("Error on getDiscoveryInfo() request: %@",
//                                        getVaList([error.localizedDescription]))
                                // TO-DO Crashlytics.sharedInstance().recordError(error)
                                seal.reject(error)
                            }
                        }
        }
    }

    func IdentifyDevice() -> Promise<String> {
        return Promise { seal in
            if let manager = self.manager,
                let queryUrl = baseAPIURL?.appendingPathComponent("ios/identify") {
                _ = manager.request(queryUrl, method: .post,
                                    parameters: buildIdentifyDict(), encoding: JSONEncoding.default)
                           .validate()
                           .responseString { response in
                            switch response.result {
                            case .success:
                                if let resVal = response.result.value {
                                    seal.fulfill(resVal)
                                } else {
                                    seal.reject(APIError.invalidResponse)
                                }
                            case .failure(let error):
//                                CLSLogv("Error when attemping to IdentifyDevice(): %@",
//                                        getVaList([error.localizedDescription]))
                                // TO-DO Crashlytics.sharedInstance().recordError(error)
                                seal.reject(error)
                            }
                }
            } else {
                seal.reject(APIError.managerNotAvailable)
            }
        }
    }

    func RemoveDevice() -> Promise<String> {
        return Promise { seal in
            if let manager = self.manager,
                let queryUrl = baseAPIURL?.appendingPathComponent("ios/identify") {
                _ = manager.request(queryUrl, method: .delete,
                                    parameters: buildRemovalDict(), encoding: JSONEncoding.default)
                    .validate()
                    .responseString { response in
                        switch response.result {
                        case .success:
                            if let resVal = response.result.value {
                                seal.fulfill(resVal)
                            } else {
                                seal.reject(APIError.invalidResponse)
                            }
                        case .failure(let error):
//                            CLSLogv("Error when attemping to RemoveDevice(): %@",
//                                    getVaList([error.localizedDescription]))
                            // TO-DO Crashlytics.sharedInstance().recordError(error)
                            seal.reject(error)
                        }
                }
            } else {
                seal.reject(APIError.managerNotAvailable)
            }
        }
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
//                            CLSLogv("Error when attemping to registerDeviceForPush(), json was nil!: %@",
//                                    getVaList([retErr.localizedDescription]))
                            // TO-DO Crashlytics.sharedInstance().recordError(retErr)
                            seal.reject(retErr)
                        }
                    case .failure(let error):
//                        CLSLogv("Error when attemping to registerDeviceForPush(): %@",
//                                getVaList([error.localizedDescription]))
                        // TO-DO Crashlytics.sharedInstance().recordError(error)
                        seal.reject(error)
                    }
            }
        }
    }

    func GetPushSettings() -> Promise<PushConfiguration> {
        return Promise { seal in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("ios/push") {
                _ = manager.request(queryUrl, method: .get)
                    .validate()
                    .responseObject { (response: DataResponse<PushConfiguration>) in
                        switch response.result {
                        case .success:
                            if let resVal = response.result.value {
                                seal.fulfill(resVal)
                            } else {
                                seal.reject(APIError.invalidResponse)
                            }
                        case .failure(let error):
//                            CLSLogv("Error on GetPushSettings() request: %@",
//                                    getVaList([error.localizedDescription]))
                            // TO-DO Crashlytics.sharedInstance().recordError(error)
                            seal.reject(error)
                        }
                }
            } else {
                seal.reject(APIError.managerNotAvailable)
            }
        }
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
        ident.DeviceID = deviceID
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
        ident.DeviceID = deviceID
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
        ident.DeviceID = deviceID
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
//                CLSLogv("Error on setupUserNotificationPushActions() request: %@",
//                        getVaList([error.localizedDescription]))
                // TO-DO Crashlytics.sharedInstance().recordError(error)
                seal.reject(error)
            }
        }
    }

    func setupPush() {
        DispatchQueue.main.async(execute: {
            UIApplication.shared.registerForRemoteNotifications()
        })
        self.setupUserNotificationPushActions().done { categories in
            UNUserNotificationCenter.current().setNotificationCategories(categories)
            }.catch {error -> Void in
                print("Error when attempting to setup push actions", error)
                // TO-DO Crashlytics.sharedInstance().recordError(error)
        }
    }

    func handlePushAction(identifier: String, userInfo: [AnyHashable: Any], userInput: String?) -> Promise<Bool> {
        return Promise { seal in
            let device = Device()
            var eventData: [String: Any] = ["actionName": identifier,
                                           "sourceDevicePermanentID": DeviceUID.uid(),
                                           "sourceDeviceName": device.name,
                                           "sourceDeviceID": deviceID]
            if let dataDict = userInfo["homeassistant"] {
                eventData["action_data"] = dataDict
            }
            if let textInput = userInput {
                eventData["response_info"] = textInput
                eventData["textInput"] = textInput
            }
            HomeAssistantAPI.sharedInstance.CreateEvent(eventType: "ios.notification_action_fired",
                                                        eventData: eventData).done { _ -> Void in
                                                            seal.fulfill(true)
                }.catch {error in
                    // TO-DO Crashlytics.sharedInstance().recordError(error)
                    seal.reject(error)
            }
        }
    }

    func CleanBaseURL(baseUrl: URL) -> (hasValidScheme: Bool, cleanedURL: URL) {
        if (baseUrl.absoluteString.hasPrefix("http://") || baseUrl.absoluteString.hasPrefix("https://")) == false {
            return (false, baseUrl)
        }
        var urlComponents = URLComponents()
        urlComponents.scheme = baseUrl.scheme
        urlComponents.host = baseUrl.host
        urlComponents.port = baseUrl.port
        //        if urlComponents.port == nil {
        //            urlComponents.port = (baseUrl.scheme == "http") ? 80 : 443
        //        }
        return (true, urlComponents.url!)
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

    func getSSID() -> String? {
        var ssid: String?
        if let interfaces = CNCopySupportedInterfaces() as NSArray? {
            for interface in interfaces {
                // swiftlint:disable:next force_cast
                if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                    ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
                    break
                }
            }
        }
        return ssid
    }


}

class BonjourDelegate: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {

    var resolving = [NetService]()
    var resolvingDict = [String: NetService]()

    // Browser methods

    func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser,
                           didFind netService: NetService,
                           moreComing moreServicesComing: Bool) {
        NSLog("BonjourDelegate.Browser.didFindService")
        netService.delegate = self
        resolvingDict[netService.name] = netService
        netService.resolve(withTimeout: 0.0)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        NSLog("BonjourDelegate.Browser.netServiceDidResolveAddress")
        if let txtRecord = sender.txtRecordData() {
            let serviceDict = NetService.dictionary(fromTXTRecord: txtRecord)
            let discoveryInfo = DiscoveryInfoFromDict(locationName: sender.name, netServiceDictionary: serviceDict)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "homeassistant.discovered"),
                                            object: nil,
                                            userInfo: discoveryInfo.toJSON())
        }
    }

    func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser,
                           didRemove netService: NetService,
                           moreComing moreServicesComing: Bool) {
        NSLog("BonjourDelegate.Browser.didRemoveService")
        let discoveryInfo: [NSObject: Any] = ["name" as NSObject: netService.name]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "homeassistant.undiscovered"),
                                        object: nil,
                                        userInfo: discoveryInfo)
        resolvingDict.removeValue(forKey: netService.name)
    }

    private func DiscoveryInfoFromDict(locationName: String,
                                       netServiceDictionary: [String: Data]) -> DiscoveryInfoResponse {
        var outputDict: [String: Any] = [:]
        for (key, value) in netServiceDictionary {
            outputDict[key] = String(data: value, encoding: .utf8)
            if outputDict[key] as? String == "true" || outputDict[key] as? String == "false" {
                if let stringedKey = outputDict[key] as? String {
                    outputDict[key] = Bool(stringedKey)
                }
            }
        }
        outputDict["location_name"] = locationName
        if let baseURL = outputDict["base_url"] as? String {
            if baseURL.hasSuffix("/") {
                outputDict["base_url"] = baseURL[..<baseURL.index(before: baseURL.endIndex)]
            }
        }
        return DiscoveryInfoResponse(JSON: outputDict)!
    }

}

class Bonjour {
    var nsb: NetServiceBrowser
    var nsp: NetService
    var nsdel: BonjourDelegate?

    init() {
        let device = Device()
        self.nsb = NetServiceBrowser()
        self.nsp = NetService(domain: "local", type: "_hass-ios._tcp.", name: device.name, port: 65535)
    }

    func buildPublishDict() -> [String: Data] {
        var publishDict: [String: Data] = [:]
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") {
            if let stringedBundleVersion = bundleVersion as? String {
                if let data = stringedBundleVersion.data(using: .utf8) {
                    publishDict["buildNumber"] = data
                }
            }
        }
        if let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") {
            if let stringedVersionNumber = versionNumber as? String {
                if let data = stringedVersionNumber.data(using: .utf8) {
                    publishDict["versionNumber"] = data
                }
            }
        }
        if let permanentID = DeviceUID.uid().data(using: .utf8) {
            publishDict["permanentID"] = permanentID
        }
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            if let data = bundleIdentifier.data(using: .utf8) {
                publishDict["bundleIdentifier"] = data
            }
        }
        return publishDict
    }

    func startDiscovery() {
        self.nsdel = BonjourDelegate()
        nsb.delegate = nsdel
        nsb.searchForServices(ofType: "_home-assistant._tcp.", inDomain: "local.")
    }

    func stopDiscovery() {
        nsb.stop()
    }

    func startPublish() {
        //        self.nsdel = BonjourDelegate()
        //        nsp.delegate = nsdel
        nsp.setTXTRecord(NetService.data(fromTXTRecord: buildPublishDict()))
        nsp.publish()
    }

    func stopPublish() {
        nsp.stop()
    }

}

public typealias OnLocationUpdated = ((CLLocation?, Error?) -> Void)

class RegionManager: NSObject {

    let locationManager = CLLocationManager()
    var backgroundTask: UIBackgroundTaskIdentifier?
    let activityManager = CMMotionActivityManager()
    var lastActivity: CMMotionActivity?
    var lastLocation: CLLocation?
    var oneShotLocationActive: Bool = false

    var zones: [RLMZone] {
        let realm = Current.realm()
        return realm.objects(RLMZone.self).map { $0 }
    }

    var activeZones: [RLMZone] {
        let realm = Current.realm()
        return realm.objects(RLMZone.self).filter(NSPredicate(format: "inRegion == %@",
                                                              NSNumber(value: true))).map { $0 }
    }

    internal lazy var coreMotionQueue: OperationQueue = {
        return OperationQueue()
    }()

    override init() {
        super.init()
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.delegate = self
        locationManager.distanceFilter = kCLLocationAccuracyHundredMeters
        startMonitoring()
        syncMonitoredRegions()
    }

    private func startMonitoring() {
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startMonitoringVisits()
    }

    func triggerRegionEvent(_ manager: CLLocationManager, trigger: LocationUpdateTrigger,
                            region: CLRegion) {
        var trig = trigger
        guard let zone = zones.filter({ region.identifier == $0.ID }).first else {
            print("Zone ID \(region.identifier) doesn't exist in Realm, syncing monitored regions now")
            return syncMonitoredRegions()
        }

        // Do nothing in case we don't want to trigger an enter event
        if zone.TrackingEnabled == false {
            print("Tracking enabled is false")
            return
        }

        if zone.IsBeaconRegion {
            if trigger == .RegionEnter {
                trig = .BeaconRegionEnter
            }
            if trigger == .RegionExit {
                trig = .BeaconRegionExit
            }
        }

        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }

        let realm = Current.realm()
        // swiftlint:disable:next force_try
        try! realm.write {
            zone.inRegion = (trig == .RegionEnter || trig == .BeaconRegionEnter)
        }

        print("Submit location for zone \(zone.ID) with trigger \(trig.rawValue)")

        HomeAssistantAPI.sharedInstance.submitLocation(updateType: trig, location: nil,
                                                       visit: nil, zone: zone)
    }

    func startMonitoring(zone: RLMZone) {
        if let region = zone.region() {
            locationManager.startMonitoring(for: region)
        }

        activityManager.startActivityUpdates(to: coreMotionQueue) { activity in
            self.lastActivity = activity
        }
    }

    @objc func syncMonitoredRegions() {
        // stop monitoring for all regions
        locationManager.monitoredRegions.forEach { region in
            print("Stopping monitoring of region \(region.identifier)")
            locationManager.stopMonitoring(for: region)
        }

        // start monitoring for all existing regions
        zones.forEach { zone in
            print("Starting monitoring of zone \(zone)")
            startMonitoring(zone: zone)
        }
    }

    func checkIfInsideAnyRegions(location: CLLocationCoordinate2D) -> Set<CLRegion> {
        return self.locationManager.monitoredRegions.filter { (region) -> Bool in
            if let circRegion = region as? CLCircularRegion {
                // print("Checking", circRegion.identifier)
                return circRegion.contains(location)
            }
            return false
        }
    }
}

// MARK: CLLocationManagerDelegate
extension RegionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            prefs.setValue(true, forKey: "locationEnabled")
            prefs.synchronize()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if self.oneShotLocationActive {
            print("NOT accepting region manager update as one shot location service is active")
            return
        }
        print("RegionManager: Got location, stopping updates!", locations.last.debugDescription, locations.count)
        HomeAssistantAPI.sharedInstance.submitLocation(updateType: .SignificantLocationUpdate,
                                                       location: locations.last,
                                                       visit: nil,
                                                       zone: nil)

        self.lastLocation = locations.last

        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Region entered", region.identifier)
        triggerRegionEvent(manager, trigger: .RegionEnter, region: region)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Region exited", region.identifier)
        triggerRegionEvent(manager, trigger: .RegionExit, region: region)
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        print("Visit logged")
        HomeAssistantAPI.sharedInstance.submitLocation(updateType: .Visit,
                                                       location: nil,
                                                       visit: visit,
                                                       zone: nil)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clErr = error as? CLError {
            let realm = Current.realm()
            // swiftlint:disable:next force_try
            try! realm.write {
                let locErr = LocationError(err: clErr)
                realm.add(locErr)
            }
            print(clErr.debugDescription)
            if clErr.code == CLError.locationUnknown {
                // locationUnknown just means that GPS may be taking an extra moment, so don't throw an error.
                return
            }
        } else {
            print("other error:", error.localizedDescription)
        }
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
//        let insideRegions = checkIfInsideAnyRegions(location: lastLocation.coordinate)
//        for inside in insideRegions {
//            print("System reports inside for zone", inside.identifier)
//        }
        print("Started monitoring region", region.identifier)
        locationManager.requestState(for: region)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        var strState = "Unknown"
        if state == .inside {
            strState = "Inside"
        } else if state == .outside {
            strState = "Outside"
        } else if state == .unknown {
            strState = "Unknown"
        }
        print("\(strState) region", region.identifier)
    }
}

// MARK: BackgroundTask
extension RegionManager {
    func endBackgroundTask() {
        if backgroundTask != UIBackgroundTaskIdentifier.invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask!)
            backgroundTask = UIBackgroundTaskIdentifier.invalid
        }
    }
}

class LocationManager: NSObject {
    let locationManager = CLLocationManager()
    var onLocationUpdated: OnLocationUpdated

    init(onLocation: @escaping OnLocationUpdated) {
        onLocationUpdated = onLocation
        super.init()
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.distanceFilter = kCLLocationAccuracyHundredMeters
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("LocationManager: Got location, stopping updates!", locations.last.debugDescription, locations.count)
        onLocationUpdated(locations.first, nil)
        manager.stopUpdatingLocation()
        manager.delegate = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clErr = error as? CLError {
            let realm = Current.realm()
            // swiftlint:disable:next force_try
            try! realm.write {
                let locErr = LocationError(err: clErr)
                realm.add(locErr)
            }
            print(clErr.debugDescription)
            if clErr.code == CLError.locationUnknown {
                // locationUnknown just means that GPS may be taking an extra moment, so don't throw an error.
                return
            }
            onLocationUpdated(nil, clErr)
        } else {
            print("other error:", error.localizedDescription)
            onLocationUpdated(nil, error)
        }
    }
}

enum LocationUpdateTrigger: String {
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
