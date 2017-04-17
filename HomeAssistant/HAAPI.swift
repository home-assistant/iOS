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
import IKEventSource
import SwiftLocation
import CoreLocation
import Whisper
import AlamofireObjectMapper
import ObjectMapper
import DeviceKit
import PermissionScope
import Crashlytics
import RealmSwift
import UserNotifications

let prefs = UserDefaults(suiteName: "group.io.robbie.homeassistant")!

let APIClientSharedInstance = HomeAssistantAPI()

// swiftlint:disable file_length

// swiftlint:disable:next type_body_length
public class HomeAssistantAPI {

    class var sharedInstance: HomeAssistantAPI {
        return APIClientSharedInstance
    }

    // swiftlint:disable:next line_length
    var deviceID: String = removeSpecialCharsFromString(text: UIDevice.current.name).replacingOccurrences(of: " ", with: "_").lowercased()
    var pushID: String = ""
    var deviceToken: String = ""

    var loadedComponents = [String]()

    var Configured: Bool {
        return self.URLSet && self.PasswordSet
    }

    var URLSet: Bool = false
    var PasswordSet: Bool = false

    var baseURL: String = ""
    var baseAPIURL: String = ""
    var apiPassword: String = ""

    private var eventSource: EventSource?

    private var headers = [String: String]()

    private var manager: Alamofire.SessionManager?

    var cachedEntities: [Entity]?

    func Setup(baseURL: String, password: String, deviceID: String?) -> Promise<StatusResponse> {
        self.baseURL = baseURL
        self.baseAPIURL = baseURL+"/api/"
        if let dID = deviceID {
            self.deviceID = dID
        }
        self.URLSet = true
        if password != "" {
            self.PasswordSet = true
            headers["X-HA-Access"] = password
        }

        var defaultHeaders = Alamofire.SessionManager.defaultHTTPHeaders
        for (header, value) in headers {
            defaultHeaders[header] = value
        }

        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = defaultHeaders
        configuration.timeoutIntervalForRequest = 3 // seconds

        self.manager = Alamofire.SessionManager(configuration: configuration)

        if let pushId = prefs.string(forKey: "pushID") {
            pushID = pushId
        }

        if let deviceTok = prefs.string(forKey: "deviceToken") {
            deviceToken = deviceTok
        }

        return GetStatus()

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
                        self.trackLocation()
                    }

                    if self.loadedComponents.contains("ios") {
                        CLSLogv("iOS component loaded, attempting identify", getVaList([]))
                        _ = self.identifyDevice()
                    }

                    //                self.GetHistory()
                    //                self.startStream()
                    fulfill(config)
                })
                }.catch {error in
                    print("Error at launch!", error)
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
            }

        }
    }

    func startStream() {
        eventSource = EventSource(url: baseAPIURL+"stream", headers: headers)

        eventSource?.onOpen {
            print("SSE: Connection Opened")
            self.showMurmur(title: "Connected to Home Assistant")
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "sse.opened"),
                                            object: nil, userInfo: nil)
        }

        eventSource?.onError { error in
            if let err = error {
                Crashlytics.sharedInstance().recordError(err)
                print("SSE: ", err)
                self.showMurmur(title: "SSE Error! \(err.localizedDescription)")
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "sse.error"),
                                                object: nil, userInfo: [
                                                    "code": err.code,
                                                    "description": err.description
                    ])
            }
        }

        eventSource?.onMessage { (_, eventName, data) in
            if let eventData = data {
                if eventData == "ping" { return }
                if let event = Mapper<SSEEvent>().map(JSONString: eventData) {
                    if event is StateChangedEvent {
//                        if let newState = mapped.NewState {
//                            HomeAssistantAPI.sharedInstance.storeEntities(entities: [newState])
//                        }
                    }
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "sse.\(event.EventType)"),
                                                    object: nil, userInfo: event.toJSON())
                } else {
                    print("Unable to ObjectMap this SSE message", eventName!, eventData)
                }
            } else {
                print("Unable to ObjectMap this SSE message", eventName!, data as Any)
            }
        }
    }

    // swiftlint:disable:next function_body_length
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

        let locationUpdate: [String:Any] = [
            "battery": Int(UIDevice.current.batteryLevel*100),
            "battery_status": batteryState,
            "gps": [coordinates.latitude, coordinates.longitude],
            "gps_accuracy": accuracy,
            "hostname": UIDevice().name,
            "dev_id": deviceID
        ]

        _ = self.identifyDevice()

        self.CallService(domain: "device_tracker",
                         service: "see",
                         serviceData: locationUpdate as [String : Any]).then {_ in
                            print("Device seen!")
            }.catch {err in
                Crashlytics.sharedInstance().recordError(err as NSError)
        }

        UIDevice.current.isBatteryMonitoringEnabled = false

        let notificationTitle = "Location change"
        var notificationBody = ""
        var notificationIdentifer = ""
        var shouldNotify = false

        switch updateType {
        case .RegionEnter:
            notificationBody = "\(zone!.Name) entered"
            notificationIdentifer = "\(zone!.Name)_entered"
            shouldNotify = prefs.bool(forKey: "enterNotifications")
        case .RegionExit:
            notificationBody = "\(zone!.Name) exited"
            notificationIdentifer = "\(zone!.Name)_exited"
            shouldNotify = prefs.bool(forKey: "exitNotifications")
        case .SignificantLocationUpdate:
            notificationBody = "Significant location change detected, notifying Home Assistant"
            notificationIdentifer = "sig_change"
            shouldNotify = prefs.bool(forKey: "significantLocationChangeNotifications")
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

    func trackLocation() {
        _ = Location.getLocation(accuracy: .neighborhood,
                                 frequency: .significant,
                                 timeout: 50,
                                 success: { (_, location) -> (Void) in
                                    self.submitLocation(updateType: .Manual,
                                                        coordinates: location.coordinate,
                                                        accuracy: location.horizontalAccuracy,
                                                        zone: nil)
        }) { (_, _, error) -> (Void) in
            // something went wrong. request will be cancelled automatically
            print("Something went wrong when trying to get significant location updates! Error was:", error)
            Crashlytics.sharedInstance().recordError(error)
        }

        if let cachedEntities = HomeAssistantAPI.sharedInstance.cachedEntities {
            if let zoneEntities: [Zone] = cachedEntities.filter({ (entity) -> Bool in
                return entity.Domain == "zone"
                // swiftlint:disable:next force_cast
            }) as? [Zone] {
                for zone in zoneEntities {
                    if zone.TrackingEnabled == false {
                        print("Skipping zone set to not track!")
                        continue
                    }
                    do {
                        try Location.monitor(regionAt: zone.locationCoordinates(), radius: zone.Radius, enter: { _ in
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
                        CLSLogv("Error when setting up zones for tracking: %@", getVaList([error.localizedDescription]))
                        Crashlytics.sharedInstance().recordError(error)
                    }
                }
            }

        }
        //        let location = Location()
        //
        //        self.getBeacons().then { beacons -> Void in
        //            for beacon in beacons {
        //                print("Got beacon from HA", beacon.UUID, beacon.Major, beacon.Minor)
        //                try Beacons.monitorForBeacon(proximityUUID: beacon.UUID!,
        //                                             major: UInt16(beacon.Major!),
        //                                             minor: UInt16(beacon.Minor!),
        //                                             onFound: { beaconsFound in
        //                    // beaconsFound is an array of found beacons ([CLBeacon]) but
        //                    // in this case it contains only one beacon
        //                    print("beaconsFound", beaconsFound)
        //                }) { error in
        //                    // something bad happened
        //                    print("Error happened on beacons", error)
        //                }
        //            }
        //        }.catch {error in
        //            print("Error when getting beacons!", error)
        //            Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
        //        }

    }

    func sendOneshotLocation() -> Promise<Bool> {
        return Promise { fulfill, reject in
            Location.getLocation(accuracy: .neighborhood, frequency: .oneShot, success: { (_, location) in
                print("A new update of location is available: \(location)")
                self.submitLocation(updateType: .Manual,
                                    coordinates: location.coordinate,
                                    accuracy: location.horizontalAccuracy,
                                    zone: nil)
                fulfill(true)
            }) { (request, _, error) in
                request.cancel() // stop continous location monitoring on error
                print("Error when trying to get a oneshot location!", error)
                Crashlytics.sharedInstance().recordError(error)
                reject(error)
            }
        }
    }

    func GetStatus() -> Promise<StatusResponse> {
        let queryUrl = baseAPIURL
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl,
                                      // swiftlint:disable:next line_length
                                      method: .get).validate().responseObject { (response: DataResponse<StatusResponse>) in
                                        switch response.result {
                                        case .success:
                                            fulfill(response.result.value!)
                                        case .failure(let error):
                                            CLSLogv("Error on GetStatus() request: %@",
                                                    getVaList([error.localizedDescription]))
                                            Crashlytics.sharedInstance().recordError(error)
                                            reject(error)
                                        }
            }
        }
    }

    func GetConfig() -> Promise<ConfigResponse> {
        let queryUrl = baseAPIURL+"config"
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl,
                                      // swiftlint:disable:next line_length
                method: .get).validate().responseObject { (response: DataResponse<ConfigResponse>) in
                    switch response.result {
                    case .success:
                        fulfill(response.result.value!)
                    case .failure(let error):
                        CLSLogv("Error on GetConfig() request: %@", getVaList([error.localizedDescription]))
                        Crashlytics.sharedInstance().recordError(error)
                        reject(error)
                    }
            }
        }
    }

    func GetServices() -> Promise<[ServicesResponse]> {
        let queryUrl = baseAPIURL+"services"
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl,
                                      // swiftlint:disable:next line_length
                method: .get).validate().responseArray { (response: DataResponse<[ServicesResponse]>) in
                    switch response.result {
                    case .success:
                        fulfill(response.result.value!)
                    case .failure(let error):
                        CLSLogv("Error on GetServices() request: %@", getVaList([error.localizedDescription]))
                        Crashlytics.sharedInstance().recordError(error)
                        reject(error)
                    }
            }
        }
    }

    //    func GetHistory() -> Promise<HistoryResponse> {
    //        let queryUrl = baseAPIURL+"history/period?filter_entity_id=sensor.uberpool_time"
    //        return Promise { fulfill, reject in
    //            _ = self.manager!.request(queryUrl, method: .get).validate().responseJSON { response in
    //                switch response.result {
    //                case .success:
    //                    print("GOT HISTORY", queryUrl)
    //                    let mapped = Mapper<HistoryResponse>().map(response.result.value!)
    //                    print("MAPPED", mapped)
    //                    fulfill(mapped!)
    //                case .failure(let error):
    //                    CLSLogv("Error on GetHistory() request: %@", getVaList([error.localizedDescription]))
    //                    Crashlytics.sharedInstance().recordError(error)
    //                    reject(error)
    //                }
    //            }
    //        }
    //    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func storeEntities(entities: [Entity]) {
        for entity in entities {
            // swiftlint:disable:next force_try
            try! realm.write {
                switch entity {
                case is Automation:
                    realm.create(Automation.self, value: entity, update: true)
                case is BinarySensor:
                    realm.create(BinarySensor.self, value: entity, update: true)
                case is Climate:
                    realm.create(Climate.self, value: entity, update: true)
                case is DeviceTracker:
                    realm.create(DeviceTracker.self, value: entity, update: true)
                case is GarageDoor:
                    realm.create(GarageDoor.self, value: entity, update: true)
                case is Group:
                    if let currentObject = realm.object(ofType: Group.self, forPrimaryKey: entity.ID as AnyObject) {
                        if let group = entity as? Group {
                            group.Order = currentObject.Order
                            realm.create(Group.self, value: entity, update: true)
                        }
                    } else {
                        realm.create(Group.self, value: entity, update: true)
                    }
                case is Fan:
                    realm.create(Fan.self, value: entity, update: true)
                case is InputBoolean:
                    realm.create(InputBoolean.self, value: entity, update: true)
                case is InputSelect:
                    realm.create(InputSelect.self, value: entity, update: true)
                case is Light:
                    realm.create(Light.self, value: entity, update: true)
                case is Lock:
                    realm.create(Lock.self, value: entity, update: true)
                case is MediaPlayer:
                    realm.create(MediaPlayer.self, value: entity, update: true)
                case is Scene:
                    realm.create(Scene.self, value: entity, update: true)
                case is Script:
                    realm.create(Script.self, value: entity, update: true)
                case is Sensor:
                    realm.create(Sensor.self, value: entity, update: true)
                case is Sun:
                    realm.create(Sun.self, value: entity, update: true)
                case is Switch:
                    realm.create(Switch.self, value: entity, update: true)
                case is Thermostat:
                    realm.create(Thermostat.self, value: entity, update: true)
                case is Weblink:
                    realm.create(Weblink.self, value: entity, update: true)
                case is Zone:
                    realm.create(Zone.self, value: entity, update: true)
                default:
                    print("Unable to save \(entity.Domain)!")
                }
                realm.create(Entity.self, value: entity, update: true)
            }
        }
    }

    func GetStates() -> Promise<[Entity]> {
        let queryUrl = baseAPIURL+"states"
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl,
                                      // swiftlint:disable:next line_length
                method: .get).validate().responseArray { (response: DataResponse<[Entity]>) -> Void in
                    switch response.result {
                    case .success:
//                        self.storeEntities(entities: response.result.value!)
                        self.cachedEntities = response.result.value!
                        fulfill(response.result.value!)
                    case .failure(let error):
                        CLSLogv("Error on GetStates() request: %@", getVaList([error.localizedDescription]))
                        Crashlytics.sharedInstance().recordError(error)
                        reject(error)
                    }
            }
        }
    }

    func GetStateForEntityIdMapped(entityId: String) -> Promise<Entity> {
        let queryUrl = baseAPIURL+"states/"+entityId
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl,
                                      // swiftlint:disable:next line_length
                method: .get).validate().responseObject { (response: DataResponse<Entity>) -> Void in
                    switch response.result {
                    case .success:
//                        self.storeEntities(entities: [response.result.value!])
                        fulfill(response.result.value!)
                    case .failure(let error):
                        CLSLogv("Error on GetStateForEntityIdMapped() request: %@",
                                getVaList([error.localizedDescription]))
                        Crashlytics.sharedInstance().recordError(error)
                        reject(error)
                    }
            }
        }
    }

    func GetErrorLog() -> Promise<String> {
        let queryUrl = baseAPIURL+"error_log"
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl, method: .get).validate().responseString { response in
                switch response.result {
                case .success:
                    fulfill(response.result.value!)
                case .failure(let error):
                    CLSLogv("Error on GetErrorLog() request: %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }

    func SetState(entityId: String, state: String) -> Promise<Entity> {
        let queryUrl = baseAPIURL+"states/"+entityId
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl,
                                      method: .post,
                                      parameters: ["state": state],
                                      encoding: JSONEncoding.default
                ).validate().responseObject { (response: DataResponse<Entity>) in
                    switch response.result {
                    case .success:
                        let murmurTitle = response.result.value!.Domain+" state set to "+response.result.value!.State
                        self.showMurmur(title: murmurTitle)
//                        self.storeEntities(entities: [response.result.value!])
                        fulfill(response.result.value!)
                    case .failure(let error):
                        CLSLogv("Error when attemping to SetState(): %@", getVaList([error.localizedDescription]))
                        Crashlytics.sharedInstance().recordError(error)
                        reject(error)
                    }
            }
        }
    }

    func CreateEvent(eventType: String, eventData: [String:Any]) -> Promise<String> {
        let queryUrl = baseAPIURL+"events/"+eventType
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl,
                                      method: .post,
                                      parameters: eventData,
                                      encoding: JSONEncoding.default).validate().responseJSON { response in
                                        switch response.result {
                                        case .success:
                                            if let jsonDict = response.result.value as? [String : String] {
                                                self.showMurmur(title: eventType+" created")
                                                fulfill(jsonDict["message"]!)
                                            }
                                        case .failure(let error):
                                            CLSLogv("Error when attemping to CreateEvent(): %@",
                                                    getVaList([error.localizedDescription]))
                                            Crashlytics.sharedInstance().recordError(error)
                                            reject(error)
                                        }
            }
        }
    }

    func CallService(domain: String, service: String, serviceData: [String:Any]) -> Promise<[ServicesResponse]> {
        //        self.showMurmur(title: domain+"/"+service+" called")
        let queryUrl = baseAPIURL+"services/"+domain+"/"+service
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl,
                                      method: .post,
                                      parameters: serviceData,
                                      encoding: JSONEncoding.default
                ).validate().responseArray { (response: DataResponse<[ServicesResponse]>) in
                    switch response.result {
                    case .success:
                        if let resVal = response.result.value {
                            fulfill(resVal)
                        } else {
                            CLSLogv("CallService response.result.value could not unwrap! %@",
                                    // swiftlint:disable:next force_cast
                                    getVaList([response.result as! CVarArg]))
                            fulfill([ServicesResponse]())
                        }
                    case .failure(let error):
                        CLSLogv("Error on CallService() request: %@", getVaList([error.localizedDescription]))
                        Crashlytics.sharedInstance().recordError(error)
                        reject(error)
                    }
            }
        }
    }

    func turnOn(entityId: String) -> Promise<[ServicesResponse]> {
        self.showMurmur(title: entityId+" turned on")
        return CallService(domain: "homeassistant", service: "turn_on", serviceData: ["entity_id": entityId])
    }

    func turnOnEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        self.showMurmur(title: "\(entity.Name) turned on")
        return CallService(domain: "homeassistant", service: "turn_on", serviceData: ["entity_id": entity.ID])
    }

    func turnOff(entityId: String) -> Promise<[ServicesResponse]> {
        self.showMurmur(title: entityId+" turned off")
        return CallService(domain: "homeassistant", service: "turn_off", serviceData: ["entity_id": entityId])
    }

    func turnOffEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        self.showMurmur(title: "\(entity.Name) turned off")
        return CallService(domain: "homeassistant", service: "turn_off", serviceData: ["entity_id": entity.ID])
    }

    func toggle(entityId: String) -> Promise<[ServicesResponse]> {
        let entity = realm.object(ofType: Entity.self, forPrimaryKey: entityId)
        self.showMurmur(title: "\(entity!.Name) toggled")
        return CallService(domain: "homeassistant", service: "toggle", serviceData: ["entity_id": entityId])
    }

    func toggleEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        self.showMurmur(title: "\(entity.Name) toggled")
        return CallService(domain: "homeassistant", service: "toggle", serviceData: ["entity_id": entity.ID])
    }

    func buildIdentifyDict() -> [String:Any] {
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

    func buildPushRegistrationDict(deviceToken: String) -> [String:Any] {
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

    func buildRemovalDict() -> [String:Any] {
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

    func identifyDevice() -> Promise<String> {
        let queryUrl = baseAPIURL+"ios/identify"
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl,
                                      method: .post,
                                      parameters: buildIdentifyDict(),
                                      encoding: JSONEncoding.default).validate().responseString { response in
                                        switch response.result {
                                        case .success:
                                            fulfill(response.result.value!)
                                        case .failure(let error):
                                            CLSLogv("Error when attemping to identifyDevice(): %@",
                                                    getVaList([error.localizedDescription]))
                                            Crashlytics.sharedInstance().recordError(error)
                                            reject(error)
                                        }
            }
        }
    }

    func removeDevice() -> Promise<String> {
        let queryUrl = baseAPIURL+"ios/identify"
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl,
                                      method: .delete,
                                      parameters: buildRemovalDict(),
                                      encoding: JSONEncoding.default).validate().responseString { response in
                                        switch response.result {
                                        case .success:
                                            fulfill(response.result.value!)
                                        case .failure(let error):
                                            CLSLogv("Error when attemping to identifyDevice(): %@",
                                                    getVaList([error.localizedDescription]))
                                            Crashlytics.sharedInstance().recordError(error)
                                            reject(error)
                                        }
            }
        }
    }

    func registerDeviceForPush(deviceToken: String) -> Promise<String> {
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
                            if let pushID = json.PushId {
                                fulfill(pushID)
                                return
                            } else {
                                let retErr = NSError(domain: "io.robbie.HomeAssistant",
                                                     code: 404,
                                                     userInfo: ["message": "pushID was nil!"])
                                CLSLogv("Error when attemping to registerDeviceForPush(), pushID was nil!: %@",
                                        getVaList([retErr.localizedDescription]))
                                Crashlytics.sharedInstance().recordError(retErr)
                                reject(retErr)
                            }
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

    // swiftlint:disable:next function_body_length
    func setupPushActions() -> Promise<Set<UIUserNotificationCategory>> {
        let queryUrl = baseAPIURL+"ios/push"
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl,
                                      // swiftlint:disable:next line_length
                method: .get).validate().responseObject { (response: DataResponse<PushConfiguration>) in
                    switch response.result {
                    case .success:
                        let config = response.result.value!
                        var allCategories = Set<UIMutableUserNotificationCategory>()
                        if let categories = config.Categories {
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
                    case .failure(let error):
                        CLSLogv("Error on setupPushActions() request: %@", getVaList([error.localizedDescription]))
                        Crashlytics.sharedInstance().recordError(error)
                        reject(error)
                    }
            }
        }
    }

    @available(iOS 10, *)
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func setupUserNotificationPushActions() -> Promise<Set<UNNotificationCategory>> {
        let queryUrl = baseAPIURL+"ios/push"
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl,
                                      method: .get
                ).validate().responseObject { (response: DataResponse<PushConfiguration>) in
                    switch response.result {
                    case .success:
                        if let config = response.result.value {
                            var allCategories = Set<UNNotificationCategory>()
                            if let categories = config.Categories {
                                for category in categories {
                                    var categoryActions = [UNNotificationAction]()
                                    if let actions = category.Actions {
                                        for action in actions {
                                            var actionOptions = UNNotificationActionOptions([])
                                            if action.AuthenticationRequired {
                                                actionOptions.insert(.authenticationRequired)
                                            }
                                            if action.Destructive {
                                                actionOptions.insert(.destructive)
                                            }
                                            if action.ActivationMode == "foreground" {
                                                actionOptions.insert(.foreground)
                                            }
                                            if action.Behavior == "default" {
                                                let newAction = UNNotificationAction(identifier: action.Identifier!,
                                                                                     title: action.Title!,
                                                                                     options: actionOptions)
                                                categoryActions.append(newAction)
                                            } else if action.Behavior == "TextInput" {
                                                if let identifier = action.Identifier,
                                                    let btnTitle = action.TextInputButtonTitle,
                                                    let place = action.TextInputPlaceholder, let title = action.Title {
                                                    // swiftlint:disable line_length
                                                    let newAction = UNTextInputNotificationAction(identifier: identifier,
                                                                                                  title: title,
                                                                                                  options: actionOptions,
                                                                                                  textInputButtonTitle:btnTitle,
                                                                                                  textInputPlaceholder:place)
                                                    // swiftlint:enable line_length
                                                    categoryActions.append(newAction)
                                                }
                                            }
                                        }
                                    } else {
                                        print("Category has no actions defined, continuing loop")
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
                        } else {
                            CLSLogv("setupUserNotificationPushActions response.result.value could not unwrap! %@",
                                    // swiftlint:disable:next force_cast
                                getVaList([response.result as! CVarArg]))
                            fulfill(Set<UNNotificationCategory>())
                        }
                    case .failure(let error):
                        CLSLogv("Error on setupUserNotificationPushActions() request: %@",
                                getVaList([error.localizedDescription]))
                        Crashlytics.sharedInstance().recordError(error)
                        reject(error)
                    }
            }
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

    func handlePushAction(identifier: String, userInfo: [AnyHashable : Any], userInput: String?) -> Promise<Bool> {
        return Promise { fulfill, reject in
            let device = Device()
            var eventData: [String:Any] = ["actionName": identifier,
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

    func getBeacons() -> Promise<[Beacon]> {
        let queryUrl = baseAPIURL+"ios/beacons"
        return Promise { fulfill, reject in
            _ = self.manager!.request(queryUrl,
                                      method: .get).validate().responseArray { (response: DataResponse<[Beacon]>) in
                                        switch response.result {
                                        case .success:
                                            fulfill(response.result.value!)
                                        case .failure(let error):
                                            CLSLogv("Error when attemping to getBeacons(): %@",
                                                    getVaList([error.localizedDescription]))
                                            Crashlytics.sharedInstance().recordError(error)
                                            reject(error)
                                        }
            }
        }
    }

    func getImage(imageUrl: String) -> Promise<UIImage> {
        var url = imageUrl.replacingOccurrences(of: "/api/", with: "")
        url = url.replacingOccurrences(of: "/local/", with: "")
        url = url.replacingOccurrences(of: "/static/", with: "")
        url = baseAPIURL+url
        return Promise { fulfill, reject in
            _ = self.manager!.request(url, method: .get).validate().responseImage { response in
                switch response.result {
                case .success:
                    if let value = response.result.value {
                        fulfill(value)
                    } else {
                        print("Response was not an image!", response)
                    }
                case .failure(let error):
                    CLSLogv("Error on getImage() request to %@: %@", getVaList([url, error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }

    var locationEnabled: Bool {
        return PermissionScope().statusLocationAlways() == .authorized
    }

    var notificationsEnabled: Bool {
        //        return PermissionScope().statusNotifications() == .authorized && prefs.string(forKey: "pushID") != nil
        return prefs.string(forKey: "pushID") != nil
        //        print("PermissionScope().statusNotifications()", PermissionScope().statusNotifications())
        //        return PermissionScope().statusNotifications() == .authorized
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

    var sseConnected: Bool {
        if let sse = self.eventSource {
            return sse.readyState == .open
        } else {
            return false
        }
    }

    var enabledPermissions: [String] {
        var permissionsContainer: [String] = []
        for status in PermissionScope().permissionStatuses([NotificationsPermission().type,
            LocationAlwaysPermission().type]) where status.1 == .authorized {
                let desc = status.0.prettyDescription.lowercased()
                permissionsContainer.append(desc)
        }
        return permissionsContainer
    }

    func showMurmur(title: String) {
        show(whistle: Murmur(title: title), action: .show(2.0))
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

    func GetDiscoveryInfo(baseUrl: URL) -> Promise<DiscoveryInfoResponse> {
        let queryUrl = baseUrl.appendingPathComponent("/api/discovery_info")
        return Promise { fulfill, reject in
            // swiftlint:disable:next line_length
            _ = Alamofire.request(queryUrl).validate().responseObject { (response: DataResponse<DiscoveryInfoResponse>) -> Void in
                switch response.result {
                case .success:
                    fulfill(response.result.value!)
                case .failure(let error):
                    CLSLogv("Error on getDiscoveryInfo() request: %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
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
        let discoveryInfo: [NSObject:Any] = ["name" as NSObject: netService.name]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "homeassistant.undiscovered"),
                                        object: nil,
                                        userInfo: discoveryInfo)
        resolvingDict.removeValue(forKey: netService.name)
    }

    private func DiscoveryInfoFromDict(locationName: String,
                                       netServiceDictionary: [String : Data]) -> DiscoveryInfoResponse {
        var outputDict: [String:Any] = [:]
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
        var publishDict: [String:Data] = [:]
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

enum LocationUpdateTypes {
    case RegionEnter
    case RegionExit
    case BeaconRegionEnter
    case BeaconRegionExit
    case Manual
    case SignificantLocationUpdate
}
