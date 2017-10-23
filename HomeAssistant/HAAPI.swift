//
//  HAAPI.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import Alamofire
import AlamofireImage
import PromiseKit
import SwiftLocation
import CoreLocation
import AlamofireObjectMapper
import ObjectMapper
import DeviceKit
import PermissionScope
import Crashlytics
import UserNotifications

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

    let beaconManager = BeaconManager()

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
        if let baseURLString = baseURLString {
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

        return

    }

    func Connect() -> Promise<ConfigResponse> {
        return Promise { fulfill, reject in
            GetConfig().then { config -> Void in
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

                _ = self.GetStates().then(execute: { _ -> Void in
                    if self.locationEnabled {
                        self.setupZones()
                    }

                    if self.loadedComponents.contains("ios") {
                        CLSLogv("iOS component loaded, attempting identify", getVaList([]))
                        _ = self.IdentifyDevice()
                    }

                    //                self.GetHistory()
                    fulfill(config)
                })
                }.catch {error in
                    print("Error at launch!", error)
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
            }

        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func submitLocation(updateType: LocationUpdateTypes,
                        coordinates: CLLocationCoordinate2D,
                        accuracy: CLLocationAccuracy,
                        zone: Zone?) {
        UIDevice.current.isBatteryMonitoringEnabled = true

        var batteryState = "Unplugged"
        switch UIDevice.current.batteryState {
        case .unknown:
            batteryState = "Unknown"
        case .charging:
            batteryState = "Charging"
        case .unplugged:
            batteryState = "Unplugged"
        case .full:
            batteryState = "Full"
        }

        let hostname = UIDevice().name

        let locationUpdate: [String: Any] = [
            "battery": Int(UIDevice.current.batteryLevel*100),
            "battery_status": batteryState,
            "gps": [coordinates.latitude, coordinates.longitude],
            "gps_accuracy": accuracy,
            "hostname": hostname,
            "dev_id": deviceID
        ]

        firstly {
            self.IdentifyDevice()
        }.then {_ in
            self.CallService(domain: "device_tracker", service: "see", serviceData: locationUpdate)
        }.then { _ in
            print("Device seen!")
        }.catch { err in
            print("Error when updating location!", err)
            Crashlytics.sharedInstance().recordError(err as NSError)
        }

        UIDevice.current.isBatteryMonitoringEnabled = false

        let notificationTitle = "Location change"
        var notificationBody = ""
        var notificationIdentifer = ""
        var shouldNotify = false

        switch updateType {
        case .BeaconRegionEnter:
            notificationBody = "\(zone!.Name) entered via iBeacon"
            notificationIdentifer = "\(zone!.Name)_beacon_entered"
            shouldNotify = prefs.bool(forKey: "beaconEnterNotifications")
        case .BeaconRegionExit:
            notificationBody = "\(zone!.Name) exited via iBeacon"
            notificationIdentifer = "\(zone!.Name)_beacon_exited"
            shouldNotify = prefs.bool(forKey: "beaconExitNotifications")
        case .RegionEnter:
            notificationBody = "\(zone!.Name) entered"
            notificationIdentifer = "\(zone!.Name)_entered"
            shouldNotify = prefs.bool(forKey: "enterNotifications")
        case .RegionExit:
            notificationBody = "\(zone!.Name) exited"
            notificationIdentifer = "\(zone!.Name)_exited"
            shouldNotify = prefs.bool(forKey: "exitNotifications")
        case .SignificantLocationUpdate:
            notificationBody = "Significant location change detected"
            notificationIdentifer = "sig_change"
            shouldNotify = prefs.bool(forKey: "significantLocationChangeNotifications")
        case .BackgroundFetch:
            notificationBody = "Current location delivery triggered via background fetch"
            notificationIdentifer = "background_fetch"
            shouldNotify = prefs.bool(forKey: "backgroundFetchLocationChangeNotifications")
        default:
            notificationBody = ""
        }

        if shouldNotify {
            if #available(iOS 10, *) {
                let content = UNMutableNotificationContent()
                content.title = notificationTitle
                content.body = notificationBody
                content.sound = UNNotificationSound.default()

                UNUserNotificationCenter.current().add(UNNotificationRequest.init(identifier: notificationIdentifer,
                                                                                  content: content, trigger: nil))
            } else {
                let notification = UILocalNotification()
                notification.alertTitle = notificationTitle
                notification.alertBody = notificationBody
                notification.alertAction = "open"
                notification.fireDate = NSDate() as Date
                notification.soundName = UILocalNotificationDefaultSoundName
                UIApplication.shared.scheduleLocalNotification(notification)
            }
        }

    }

    func setupZones() {
        if let cachedEntities = HomeAssistantAPI.sharedInstance.cachedEntities {
            if let zoneEntities: [Zone] = cachedEntities.filter({ (entity) -> Bool in
                return entity.Domain == "zone"
            }) as? [Zone] {
                Crashlytics.sharedInstance().setObjectValue(zoneEntities.count, forKey: "numberOfZones")
                for zone in zoneEntities {
                    if zone.TrackingEnabled == false {
                        print("Skipping zone set to not track!")
                        continue
                    }
                    if zone.UUID != nil && CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) {
                        beaconManager.startScanning(zone: zone)
                    }
                    do {
                        try Location.monitor(regionAt: zone.locationCoordinates(), radius: zone.Radius,
                                             enter: { _ in
                                                print("Entered in region!")
                                                self.submitLocation(updateType: LocationUpdateTypes.RegionEnter,
                                                                    coordinates: zone.locationCoordinates(),
                                                                    accuracy: 1,
                                                                    zone: zone)
                        }, exit: { _ in
                            print("Exited from the region")
                            self.submitLocation(updateType: LocationUpdateTypes.RegionExit,
                                                coordinates: zone.locationCoordinates(),
                                                accuracy: 1,
                                                zone: zone)
                        }, error: { req, error in
                            CLSLogv("Error in region monitoring: %@", getVaList([error.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(error)
                            req.cancel()
                        })
                    } catch let error {
                        CLSLogv("Error when setting up zones for tracking: %@",
                                getVaList([error.localizedDescription]))
                        Crashlytics.sharedInstance().recordError(error)
                    }
                }
            }

        }

    }

    func sendOneshotLocation() -> Promise<Bool> {
        return Promise { fulfill, reject in
            Location.getLocation(accuracy: .neighborhood, frequency: .oneShot, timeout: 25, success: { (_, location) in
                print("A new update of location is available: \(location)")
                self.submitLocation(updateType: .Manual,
                                    coordinates: location.coordinate,
                                    accuracy: location.horizontalAccuracy,
                                    zone: nil)
                fulfill(true)
            }) { (_, _, error) in
                print("Error when trying to get a oneshot location!", error)
                Crashlytics.sharedInstance().recordError(error)
                reject(error)
            }
        }
    }

    func getAndSendLocation(trigger: LocationUpdateTypes?) -> Promise<Bool> {
        var updateTrigger: LocationUpdateTypes = .Manual
        if let trigger = trigger {
            updateTrigger = trigger
        }
        return Promise { fulfill, reject in
            Location.getLocation(accuracy: .neighborhood, frequency: .oneShot, timeout: 25, success: { (_, location) in
                print("A new update of location is available: \(location) via \(updateTrigger) trigger")
                self.submitLocation(updateType: updateTrigger,
                                    coordinates: location.coordinate,
                                    accuracy: location.horizontalAccuracy,
                                    zone: nil)
                fulfill(true)
            }) { (_, _, error) in
                print("Error when trying to get a oneshot location!", error)
                Crashlytics.sharedInstance().recordError(error)
                reject(error)
            }
        }
    }

    func GetStatus() -> Promise<StatusResponse> {
        return Promise { fulfill, reject in
            if let manager = self.manager, let queryUrl = baseAPIURL {
                _ = manager.request(queryUrl, method: .get)
                           .validate()
                           .responseObject { (response: DataResponse<StatusResponse>) in
                                switch response.result {
                                case .success:
                                    if let resVal = response.result.value {
                                        fulfill(resVal)
                                    } else {
                                        reject(APIError.invalidResponse)
                                    }
                                case .failure(let error):
                                    CLSLogv("Error on GetStatus() request: %@",
                                            getVaList([error.localizedDescription]))
                                    Crashlytics.sharedInstance().recordError(error)
                                    reject(error)
                                }
                            }
            } else {
                reject(APIError.managerNotAvailable)
            }
        }
    }

    func GetConfig() -> Promise<ConfigResponse> {
        return Promise { fulfill, reject in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("config") {
                _ = manager.request(queryUrl, method: .get)
                           .validate()
                           .responseObject { (response: DataResponse<ConfigResponse>) in
                            switch response.result {
                            case .success:
                                if let resVal = response.result.value {
                                    fulfill(resVal)
                                } else {
                                    reject(APIError.invalidResponse)
                                }
                            case .failure(let error):
                                CLSLogv("Error on GetConfig() request: %@", getVaList([error.localizedDescription]))
                                Crashlytics.sharedInstance().recordError(error)
                                reject(error)
                            }
                }
            } else {
                reject(APIError.managerNotAvailable)
            }
        }
    }

    func GetServices() -> Promise<[ServicesResponse]> {
        return Promise { fulfill, reject in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("services") {
                _ = manager.request(queryUrl, method: .get)
                    .validate()
                    .responseArray { (response: DataResponse<[ServicesResponse]>) in
                        switch response.result {
                        case .success:
                            if let resVal = response.result.value {
                                fulfill(resVal)
                            } else {
                                reject(APIError.invalidResponse)
                            }
                        case .failure(let error):
                            CLSLogv("Error on GetServices() request: %@", getVaList([error.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(error)
                            reject(error)
                        }
                }
            } else {
                reject(APIError.managerNotAvailable)
            }
        }
    }

    func GetStates() -> Promise<[Entity]> {
        return Promise { fulfill, reject in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("states") {
                _ = manager.request(queryUrl, method: .get)
                    .validate()
                    .responseArray { (response: DataResponse<[Entity]>) in
                        switch response.result {
                        case .success:
                            self.cachedEntities = response.result.value!
                            if let resVal = response.result.value {
                                fulfill(resVal)
                            } else {
                                reject(APIError.invalidResponse)
                            }
                        case .failure(let error):
                            CLSLogv("Error on GetStates() request: %@", getVaList([error.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(error)
                            reject(error)
                        }
                }
            } else {
                reject(APIError.managerNotAvailable)
            }
        }
    }

    func GetEntityState(entityId: String) -> Promise<Entity> {
        return Promise { fulfill, reject in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("states/\(entityId)") {
                _ = manager.request(queryUrl, method: .get)
                    .validate()
                    .responseObject { (response: DataResponse<Entity>) in
                        switch response.result {
                        case .success:
                            if let resVal = response.result.value {
                                fulfill(resVal)
                            } else {
                                reject(APIError.invalidResponse)
                            }
                        case .failure(let error):
                            CLSLogv("Error on GetEntityState() request: %@", getVaList([error.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(error)
                            reject(error)
                        }
                }
            } else {
                reject(APIError.managerNotAvailable)
            }
        }
    }

    func GetErrorLog() -> Promise<String> {
        return Promise { fulfill, reject in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("error_log") {
                _ = manager.request(queryUrl, method: .get)
                    .validate()
                    .responseString { response in
                        switch response.result {
                        case .success:
                            if let resVal = response.result.value {
                                fulfill(resVal)
                            } else {
                                reject(APIError.invalidResponse)
                            }
                        case .failure(let error):
                            CLSLogv("Error on GetErrorLog() request: %@", getVaList([error.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(error)
                            reject(error)
                        }
                }
            } else {
                reject(APIError.managerNotAvailable)
            }
        }
    }

    func SetState(entityId: String, state: String) -> Promise<Entity> {
        return Promise { fulfill, reject in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("states/\(entityId)") {
                _ = manager.request(queryUrl, method: .post,
                                          parameters: ["state": state], encoding: JSONEncoding.default)
                                 .validate()
                                 .responseObject { (response: DataResponse<Entity>) in
                                    switch response.result {
                                    case .success:
                                        if let resVal = response.result.value {
                                            fulfill(resVal)
                                        } else {
                                            reject(APIError.invalidResponse)
                                        }
                                    case .failure(let error):
                                        CLSLogv("Error when attemping to SetState(): %@",
                                                getVaList([error.localizedDescription]))
                                        Crashlytics.sharedInstance().recordError(error)
                                        reject(error)
                                    }
                                  }
            } else {
                reject(APIError.managerNotAvailable)
            }
        }
    }

    func CreateEvent(eventType: String, eventData: [String: Any]) -> Promise<String> {
        return Promise { fulfill, reject in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("events/\(eventType)") {
                _ = manager.request(queryUrl, method: .post,
                                          parameters: eventData, encoding: JSONEncoding.default)
                    .validate()
                    .responseJSON { response in
                        switch response.result {
                        case .success:
                            if let jsonDict = response.result.value as? [String: String] {
                                fulfill(jsonDict["message"]!)
                            }
                        case .failure(let error):
                            CLSLogv("Error when attemping to CreateEvent(): %@",
                                    getVaList([error.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(error)
                            reject(error)
                        }
                }
            } else {
                reject(APIError.managerNotAvailable)
            }
        }
    }

    func CallService(domain: String, service: String, serviceData: [String: Any]) -> Promise<[ServicesResponse]> {
        return Promise { fulfill, reject in
            if let manager = self.manager,
                let queryUrl = baseAPIURL?.appendingPathComponent("services/\(domain)/\(service)") {
                _ = manager.request(queryUrl, method: .post,
                                          parameters: serviceData, encoding: JSONEncoding.default)
                    .validate()
                    .responseArray { (response: DataResponse<[ServicesResponse]>) in
                        switch response.result {
                        case .success:
                            if let resVal = response.result.value {
                                fulfill(resVal)
                            } else {
                                reject(APIError.invalidResponse)
                            }
                        case .failure(let error):
                            CLSLogv("Error on CallService() request: %@", getVaList([error.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(error)
                            reject(error)
                        }
                }
            } else {
                reject(APIError.managerNotAvailable)
            }
        }
    }

    func GetDiscoveryInfo(baseUrl: URL) -> Promise<DiscoveryInfoResponse> {
        return Promise { fulfill, reject in
            _ = Alamofire.request(baseUrl.appendingPathComponent("/api/discovery_info"))
                         .validate()
                         .responseObject { (response: DataResponse<DiscoveryInfoResponse>) -> Void in
                            switch response.result {
                            case .success:
                                if let resVal = response.result.value {
                                    fulfill(resVal)
                                } else {
                                    reject(APIError.invalidResponse)
                                }
                            case .failure(let error):
                                CLSLogv("Error on getDiscoveryInfo() request: %@",
                                        getVaList([error.localizedDescription]))
                                Crashlytics.sharedInstance().recordError(error)
                                reject(error)
                            }
                        }
        }
    }

    func IdentifyDevice() -> Promise<String> {
        return Promise { fulfill, reject in
            if let manager = self.manager,
                let queryUrl = baseAPIURL?.appendingPathComponent("ios/identify") {
                _ = manager.request(queryUrl, method: .post,
                                    parameters: buildIdentifyDict(), encoding: JSONEncoding.default)
                           .validate()
                           .responseString { response in
                            switch response.result {
                            case .success:
                                if let resVal = response.result.value {
                                    fulfill(resVal)
                                } else {
                                    reject(APIError.invalidResponse)
                                }
                            case .failure(let error):
                                CLSLogv("Error when attemping to IdentifyDevice(): %@",
                                        getVaList([error.localizedDescription]))
                                Crashlytics.sharedInstance().recordError(error)
                                reject(error)
                            }
                }
            } else {
                reject(APIError.managerNotAvailable)
            }
        }
    }

    func RemoveDevice() -> Promise<String> {
        return Promise { fulfill, reject in
            if let manager = self.manager,
                let queryUrl = baseAPIURL?.appendingPathComponent("ios/identify") {
                _ = manager.request(queryUrl, method: .delete,
                                    parameters: buildRemovalDict(), encoding: JSONEncoding.default)
                    .validate()
                    .responseString { response in
                        switch response.result {
                        case .success:
                            if let resVal = response.result.value {
                                fulfill(resVal)
                            } else {
                                reject(APIError.invalidResponse)
                            }
                        case .failure(let error):
                            CLSLogv("Error when attemping to RemoveDevice(): %@",
                                    getVaList([error.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(error)
                            reject(error)
                        }
                }
            } else {
                reject(APIError.managerNotAvailable)
            }
        }
    }

    func RegisterDeviceForPush(deviceToken: String) -> Promise<PushRegistrationResponse> {
        let queryUrl = "https://ios-push.home-assistant.io/registrations"
        return Promise { fulfill, reject in
            Alamofire.request(queryUrl,
                              method: .post,
                              parameters: buildPushRegistrationDict(deviceToken: deviceToken),
                              encoding: JSONEncoding.default
                ).validate().responseObject {(response: DataResponse<PushRegistrationResponse>) in
                    switch response.result {
                    case .success:
                        if let json = response.result.value {
                            fulfill(json)
                        } else {
                            let retErr = NSError(domain: "io.robbie.HomeAssistant",
                                                 code: 404,
                                                 userInfo: ["message": "json was nil!"])
                            CLSLogv("Error when attemping to registerDeviceForPush(), json was nil!: %@",
                                    getVaList([retErr.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(retErr)
                            reject(retErr)
                        }
                    case .failure(let error):
                        CLSLogv("Error when attemping to registerDeviceForPush(): %@",
                                getVaList([error.localizedDescription]))
                        Crashlytics.sharedInstance().recordError(error)
                        reject(error)
                    }
            }
        }
    }

    func GetPushSettings() -> Promise<PushConfiguration> {
        return Promise { fulfill, reject in
            if let manager = self.manager, let queryUrl = baseAPIURL?.appendingPathComponent("ios/push") {
                _ = manager.request(queryUrl, method: .get)
                    .validate()
                    .responseObject { (response: DataResponse<PushConfiguration>) in
                        switch response.result {
                        case .success:
                            if let resVal = response.result.value {
                                fulfill(resVal)
                            } else {
                                reject(APIError.invalidResponse)
                            }
                        case .failure(let error):
                            CLSLogv("Error on GetPushSettings() request: %@",
                                    getVaList([error.localizedDescription]))
                            Crashlytics.sharedInstance().recordError(error)
                            reject(error)
                        }
                }
            } else {
                reject(APIError.managerNotAvailable)
            }
        }
    }

    func getImage(imageUrl: String) -> Promise<UIImage> {
        return Promise { fulfill, reject in
            var finalUrl: URL?
            if imageUrl.hasPrefix("/api") || imageUrl.hasPrefix("/local") || imageUrl.hasPrefix("/static") {
                // A local URL, need to prepend the base URL only
                if let url = baseURL?.appendingPathComponent(imageUrl) {
                    finalUrl = url
                } else {
                    reject(APIError.cantBuildURL)
                }
            } else {
                // Non-local URL, just attempt to use as is
                if let url = URL(string: imageUrl) {
                    finalUrl = url
                } else {
                    reject(APIError.cantBuildURL)
                }
            }

            if let manager = self.manager, let url = finalUrl {
                _ = manager.request(url, method: .get)
                           .validate()
                           .responseImage { response in
                            switch response.result {
                            case .success:
                                if let value = response.result.value {
                                    fulfill(value)
                                } else {
                                    print("Response was not an image!", response)
                                    reject(APIError.invalidResponse)
                                }
                            case .failure(let error):
                                CLSLogv("Error on getImage() request to %@: %@",
                                        getVaList([url as CVarArg, error.localizedDescription]))
                                Crashlytics.sharedInstance().recordError(error)
                                reject(error)
                            }
                            }
            } else {
                reject(APIError.managerNotAvailable)
            }
        }
    }

    func turnOn(entityId: String) -> Promise<[ServicesResponse]> {
        return CallService(domain: "homeassistant", service: "turn_on", serviceData: ["entity_id": entityId])
    }

    func turnOnEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        return CallService(domain: "homeassistant", service: "turn_on", serviceData: ["entity_id": entity.ID])
    }

    func turnOff(entityId: String) -> Promise<[ServicesResponse]> {
        return CallService(domain: "homeassistant", service: "turn_off", serviceData: ["entity_id": entityId])
    }

    func turnOffEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        return CallService(domain: "homeassistant", service: "turn_off", serviceData: ["entity_id": entity.ID])
    }

    func toggle(entityId: String) -> Promise<[ServicesResponse]> {
        return CallService(domain: "homeassistant", service: "toggle", serviceData: ["entity_id": entityId])
    }

    func toggleEntity(entity: Entity) -> Promise<[ServicesResponse]> {
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

    func setupPushActions() -> Promise<Set<UIUserNotificationCategory>> {
        return Promise { fulfill, reject in
            self.GetPushSettings().then { pushSettings -> Void in
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
                                var behavior: UIUserNotificationActionBehavior
                                if action.Behavior == "default" {
                                    behavior = UIUserNotificationActionBehavior.default
                                } else {
                                    behavior = UIUserNotificationActionBehavior.textInput
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
                fulfill(allCategories)
            }.catch(execute: { (error) in
                CLSLogv("Error on setupPushActions() request: %@", getVaList([error.localizedDescription]))
                Crashlytics.sharedInstance().recordError(error)
                reject(error)
            })
        }
    }

    @available(iOS 10, *)
    func setupUserNotificationPushActions() -> Promise<Set<UNNotificationCategory>> {
        return Promise { fulfill, reject in
            self.GetPushSettings().then { pushSettings -> Void in
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
                                if action.Behavior == "default" {
                                    let newAction = UNNotificationAction(identifier: action.Identifier!,
                                                                         title: action.Title!, options: actionOptions)
                                    categoryActions.append(newAction)
                                } else if action.Behavior == "TextInput" {
                                    if let identifier = action.Identifier, let btnTitle = action.TextInputButtonTitle,
                                        let place = action.TextInputPlaceholder, let title = action.Title {
                                        let newAction = UNTextInputNotificationAction(identifier: identifier,
                                                                                      title: title,
                                                                                      options: actionOptions,
                                                                                      textInputButtonTitle: btnTitle,
                                                                                      textInputPlaceholder: place)
                                        categoryActions.append(newAction)
                                    }
                                }
                            }
                        } else {
                            continue
                        }
                        let finalCategory = UNNotificationCategory.init(identifier: category.Identifier!,
                                                                        actions: categoryActions,
                                                                        intentIdentifiers: [],
                                                                        options: [.customDismissAction])
                        allCategories.insert(finalCategory)
                    }
                }
                fulfill(allCategories)
            }.catch(execute: { (error) in
                CLSLogv("Error on setupUserNotificationPushActions() request: %@",
                        getVaList([error.localizedDescription]))
                Crashlytics.sharedInstance().recordError(error)
                reject(error)
            })
        }
    }

    func setupPush() {
        UIApplication.shared.registerForRemoteNotifications()
        if #available(iOS 10, *) {
            self.setupUserNotificationPushActions().then { categories -> Void in
                UNUserNotificationCenter.current().setNotificationCategories(categories)
                }.catch {error -> Void in
                    print("Error when attempting to setup push actions", error)
                    Crashlytics.sharedInstance().recordError(error)
            }
        } else {
            self.setupPushActions().then { categories -> Void in
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
        return Promise { fulfill, reject in
            let device = Device()
            var eventData: [String: Any] = ["actionName": identifier,
                                           "sourceDevicePermanentID": DeviceUID.uid(),
                                           "sourceDeviceName": device.name]
            if let dataDict = userInfo["homeassistant"] {
                eventData["action_data"] = dataDict
            }
            if let textInput = userInput {
                eventData["response_info"] = textInput
            }
            HomeAssistantAPI.sharedInstance.CreateEvent(eventType: "ios.notification_action_fired",
                                                        eventData: eventData).then { _ in
                                                            fulfill(true)
                }.catch {error in
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
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
                outputDict["base_url"] = baseURL.substring(to: baseURL.index(before: baseURL.endIndex))
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

class BeaconManager: NSObject, CLLocationManagerDelegate {

    var locationManager: CLLocationManager!

    var zones: [String: Zone] = [String: Zone]()

    override init() {
        super.init()

        locationManager = CLLocationManager()
        locationManager.delegate = self
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Entered region", region.identifier)
        if let zone = zones[region.identifier] {
            HomeAssistantAPI.sharedInstance.submitLocation(updateType: .BeaconRegionExit,
                                                           coordinates: zone.locationCoordinates(),
                                                           accuracy: 1,
                                                           zone: zone)
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Exited region", region.identifier)
        if let zone = zones[region.identifier] {
            HomeAssistantAPI.sharedInstance.submitLocation(updateType: .BeaconRegionExit,
                                                           coordinates: zone.locationCoordinates(),
                                                           accuracy: 1,
                                                           zone: zone)
        }
    }

    func startScanning(zone: Zone) {
        print("Begin scanning iBeacons for zone", zone.ID)
        var beaconRegion: CLBeaconRegion? = nil
        if let uuid = zone.UUID, let major = zone.Major, let minor = zone.Minor {
            beaconRegion = CLBeaconRegion(proximityUUID: UUID(uuidString: uuid)!,
                                          major: CLBeaconMajorValue(major),
                                          minor: CLBeaconMinorValue(minor), identifier: zone.ID)
        } else if let uuid = zone.UUID, let major = zone.Major {
            beaconRegion = CLBeaconRegion(proximityUUID: UUID(uuidString: uuid)!,
                                          major: CLBeaconMajorValue(major),
                                          identifier: zone.ID)
        } else if let uuid = zone.UUID {
            beaconRegion = CLBeaconRegion(proximityUUID: UUID(uuidString: uuid)!, identifier: zone.ID)
        }
        if let beaconRegion = beaconRegion {
            beaconRegion.notifyEntryStateOnDisplay = true
            zones[zone.ID] = zone
            locationManager.startMonitoring(for: beaconRegion)
        }
    }

    func resumeScanning() {
        print("Resuming scanning of \(locationManager.monitoredRegions.count) regions!")
        HomeAssistantAPI.sharedInstance.GetStates().then { (entities) -> Void in
            if let zoneEntities: [Zone] = entities.filter({ (entity) -> Bool in
                return entity.Domain == "zone"
            }) as? [Zone] {
                for zone in zoneEntities {
                    if zone.TrackingEnabled == false {
                        continue
                    }
                    self.zones[zone.ID] = zone
                }
            }
        }.catch { error in
            CLSLogv("Unable to resume scanning because GetStates call failed: %@!",
                    getVaList([error.localizedDescription]))
            Crashlytics.sharedInstance().recordError(error)
        }
    }

}

enum LocationUpdateTypes {
    case RegionEnter
    case RegionExit
    case BeaconRegionEnter
    case BeaconRegionExit
    case Manual
    case SignificantLocationUpdate
    case BackgroundFetch
}
