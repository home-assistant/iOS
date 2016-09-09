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

let prefs = UserDefaults.standard

let APIClientSharedInstance = HomeAssistantAPI()

public class HomeAssistantAPI {
    
    class var sharedInstance:HomeAssistantAPI {
        get {
            return APIClientSharedInstance;
        }
    }
    
    private var manager : Alamofire.SessionManager?
    
    var baseAPIURL : String = ""
    var apiPassword : String = ""
    
    var deviceID : String = ""
    var endpointARN : String = ""
    var deviceToken : String = ""
    
    var mostRecentlySentMessage : String = String()
    
    var services = [NetService]()
    
    var headers = [String:String]()
    
    var loadedComponents = [String]()
    
    let Location = LocationManager()
    
    func Setup(baseAPIUrl: String, APIPassword: String) -> Promise<StatusResponse> {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = NotificationManager()
        }
        self.baseAPIURL = baseAPIUrl+"/api/"
        self.apiPassword = APIPassword
        if apiPassword != "" {
            headers["X-HA-Access"] = apiPassword
        }
        
        var defaultHeaders = Alamofire.SessionManager.defaultHTTPHeaders 
        for (header, value) in headers {
            defaultHeaders[header] = value
        }
        
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = defaultHeaders
        configuration.timeoutIntervalForResource = 3 // seconds
        
        self.manager = Alamofire.SessionManager(configuration: configuration)
        
        if let deviceId = prefs.string(forKey: "deviceId") {
            deviceID = deviceId
        }
        
        if let endpointArn = prefs.string(forKey: "endpointARN") {
            endpointARN = endpointArn
        }
        
        if let deviceTok = prefs.string(forKey: "deviceToken") {
            deviceToken = deviceTok
        }
        
        return GetStatus()
        
    }
    
    func Connect() -> Promise<Bool> {
        return Promise { fulfill, reject in
            //            when(HomeAssistantAPI.sharedInstance.identifyDevice(), HomeAssistantAPI.sharedInstance.GetConfig()).then { ident, config -> Void in
            //            print("Identified!", ident)
            GetConfig().then { config -> Void in
                self.loadedComponents = config.Components!
                prefs.setValue(config.LocationName, forKey: "location_name")
                prefs.setValue(config.Latitude, forKey: "latitude")
                prefs.setValue(config.Longitude, forKey: "longitude")
                prefs.setValue(config.TemperatureUnit, forKey: "temperature_unit")
                prefs.setValue(config.Timezone, forKey: "time_zone")
                prefs.setValue(config.Version, forKey: "version")
                
                Crashlytics.sharedInstance().setObjectValue(config.Version, forKey: "hass_version")
                
                if self.locationEnabled() {
                    self.trackLocation()
                }
                
                if self.loadedComponents.contains("ios") {
                    CLSLogv("iOS component loaded, attempting identify and setup of push categories %@", getVaList(["this is a silly string!"]))
                    PermissionScope().statusNotifications(completionHandler: { (status) in
                        if status == .authorized {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    })
                    if #available(iOS 10, *) {
                        self.identifyDevice().then {_ -> Promise<Set<UNNotificationCategory>> in
                            return self.setupUserNotificationPushActions()
                        }.then { categories -> Void in
                            UNUserNotificationCenter.current().setNotificationCategories(categories)
                        }.catch {error -> Void in
                            print("Error when attempting an identify or setup push actions", error)
                            Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
                        }
                    } else {
                        self.identifyDevice().then {_ -> Promise<Set<UIUserNotificationCategory>> in
                            return self.setupPushActions()
                        }.then { categories -> Void in
                            let types:UIUserNotificationType = ([.alert, .badge, .sound])
                            let settings = UIUserNotificationSettings(types: types, categories: categories)
                            UIApplication.shared.registerUserNotificationSettings(settings)
                        }.catch {error -> Void in
                            print("Error when attempting an identify or setup push actions", error)
                            Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
                        }
                    }
                }
//                self.GetHistory()
                self.startStream()
                fulfill(true)
            }.catch {error in
                print("Error at launch!", error)
                Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
                reject(error)
            }

        }
    }
    
    func startStream() {
        let eventSource: EventSource = EventSource(url: baseAPIURL+"stream", headers: headers)
        
        eventSource.onOpen {
            print("SSE: Connection Opened")
            let _ = Murmur(title: "Connected to Home Assistant")
        }
        
        eventSource.onError { error in
            if let err = error {
                Crashlytics.sharedInstance().recordError(err)
                print("SSE: ", err)
                let _ = Murmur(title: "SSE Error! \(err.localizedDescription)")
            }
        }
        
        eventSource.onMessage { (id, eventName, data) in
            if data == "ping" { return }
            if let event = Mapper<SSEEvent>().map(data) {
                if let mapped = event as? StateChangedEvent {
                    HomeAssistantAPI.sharedInstance.storeEntities(entities: [mapped.NewState!])
                }
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "sse.\(event.EventType)"), object: nil, userInfo: event.toJSON())
            } else {
                print("Unable to ObjectMap this SSE message", eventName, data)
            }
        }
    }
    
    func submitLocation(updateType: String, latitude: Double, longitude: Double, accuracy: Double, locationName: String) {
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
        
        var locationUpdate : [String:Any] = [
            "battery": Int(UIDevice.current.batteryLevel*100),
            "battery_status": batteryState,
            "gps": [latitude, longitude],
            "gps_accuracy": accuracy,
            "hostname": UIDevice().name,
            "dev_id": deviceID
        ]
        
        if locationName != "" {
           locationUpdate["location_name"] = locationName
        }
        
        self.CallService(domain: "device_tracker", service: "see", serviceData: locationUpdate as [String : Any]).then {_ in
            print("Device seen!")
        }.catch {err in
            Crashlytics.sharedInstance().recordError(err as NSError)
        }
        
        UIDevice.current.isBatteryMonitoringEnabled = false
        
        if updateType != "" {
            let notification = UILocalNotification()
            notification.alertBody = updateType
            notification.alertAction = "open"
            notification.fireDate = NSDate() as Date
            notification.soundName = UILocalNotificationDefaultSoundName
            UIApplication.shared.scheduleLocalNotification(notification)
        }
    }
    
    func trackLocation() {
        let _ = Location.getLocation(withAccuracy: .neighborhood, frequency: .significant, timeout: 50, onSuccess: { (location) in
            // You will receive at max one event if desidered accuracy can be achieved; this because you have set .OneShot as frequency.
            self.submitLocation(updateType: "", latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, accuracy: location.horizontalAccuracy, locationName: "")
        }) { (lastValidLocation, error) in
            // something went wrong. request will be cancelled automatically
            print("Something went wrong when trying to get significant location updates! Error was:", error)
            Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
        }
        
        self.GetStates().then { states -> Void in
            for zone in states.filter({ return $0.Domain == "zone" }) {
                let zone = zone as! Zone
                if zone.Latitude != nil && zone.Longitude != nil {
                    let regionCoordinates = CLLocationCoordinate2DMake(zone.Latitude!, zone.Longitude!)
                    let _ = try Beacons.monitor(geographicRegion: regionCoordinates, radius: zone.Radius!, onStateDidChange: { (region) -> Void in
                        print("Region entered!", region)
                        var title = "Region"
                        if let friendlyName = zone.FriendlyName {
                            title = friendlyName+" zone"
                        }
                        self.submitLocation(updateType: title+" entered", latitude: regionCoordinates.latitude, longitude: regionCoordinates.longitude, accuracy: 1, locationName: "")
                    }) { (region) -> Void in
                        print("Region exited!", region)
                        var title = "Region"
                        if let friendlyName = zone.FriendlyName {
                            title = friendlyName+" zone"
                        }
                        self.submitLocation(updateType: title+" exited", latitude: regionCoordinates.latitude, longitude: regionCoordinates.longitude, accuracy: 1, locationName: "")
                    }
                }
            }
        }.catch {error in
            print("Error when getting states!", error)
            Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
        }

//        let location = Location()
        
//        self.getBeacons().then { beacons -> Void in
//            for beacon in beacons {
//                print("Got beacon from HA", beacon.UUID, beacon.Major, beacon.Minor)
//                try Beacons.monitorForBeacon(proximityUUID: beacon.UUID!, major: UInt16(beacon.Major!), minor: UInt16(beacon.Minor!), onFound: { beaconsFound in
//                    // beaconsFound is an array of found beacons ([CLBeacon]) but in this case it contains only one beacon
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
    
    func sendOneshotLocation(notifyString: String) -> Promise<Bool> {
        return Promise { fulfill, reject in
            let _ = Location.getLocation(withAccuracy: .neighborhood, frequency: .significant, timeout: 50, onSuccess: { (location) in
                // You will receive at max one event if desidered accuracy can be achieved; this because you have set .OneShot as frequency.
                self.submitLocation(updateType: "", latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, accuracy: location.horizontalAccuracy, locationName: "")
                fulfill(true)
            }) { (lastValidLocation, error) in
                print("Error when trying to get a oneshot location!", error)
                Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
                reject(error)
            }
        }
    }
    
    func GetStatus() -> Promise<StatusResponse> {
        let queryUrl = baseAPIURL
        return Promise { fulfill, reject in
            let _ = self.manager!.request(queryUrl, method: .get).validate().responseObject { (response: DataResponse<StatusResponse>) in
                switch response.result {
                case .success:
                    fulfill(response.result.value!)
                case .failure(let error):
                    CLSLogv("Error on GetStatus() request: %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }
    
    func GetConfig() -> Promise<ConfigResponse> {
        let queryUrl = baseAPIURL+"config"
        return Promise { fulfill, reject in
            let _ = self.manager!.request(queryUrl, method: .get).validate().responseObject { (response: DataResponse<ConfigResponse>) in
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
            let _ = self.manager!.request(queryUrl, method: .get).validate().responseArray { (response: DataResponse<[ServicesResponse]>) in
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
//            let _ = self.manager!.request(queryUrl, method: .get).validate().responseJSON { response in
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
    
    func storeEntities(entities: [Entity]) {
        for entity in entities {
            try! realm.write {
                if let mapped = entity as? BinarySensor {
                    realm.createObject(ofType: BinarySensor.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? Climate {
                    realm.createObject(ofType: Climate.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? DeviceTracker {
                    realm.createObject(ofType: DeviceTracker.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? GarageDoor {
                    realm.createObject(ofType: GarageDoor.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? Group {
                    realm.createObject(ofType: Group.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? InputBoolean {
                    realm.createObject(ofType: InputBoolean.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? InputSelect {
                    realm.createObject(ofType: InputSelect.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? Light {
                    realm.createObject(ofType: Light.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? Lock {
                    realm.createObject(ofType: Lock.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? MediaPlayer {
                    realm.createObject(ofType: MediaPlayer.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? Scene {
                    realm.createObject(ofType: Scene.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? Script {
                    realm.createObject(ofType: Script.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? Sensor {
                    realm.createObject(ofType: Sensor.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? Sun {
                    realm.createObject(ofType: Sun.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? Switch {
                    realm.createObject(ofType: Switch.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? Thermostat {
                    realm.createObject(ofType: Thermostat.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? Weblink {
                    realm.createObject(ofType: Weblink.self, populatedWith: mapped, update: true)
                } else if let mapped = entity as? Zone {
                    realm.createObject(ofType: Zone.self, populatedWith: mapped, update: true)
                }
                realm.createObject(ofType: Entity.self, populatedWith: entity, update: true)
            }
        }
    }
    
    func GetStates() -> Promise<[Entity]> {
        let queryUrl = baseAPIURL+"states"
        return Promise { fulfill, reject in
            let _ = self.manager!.request(queryUrl, method: .get).validate().responseArray { (response: DataResponse<[Entity]>) -> Void in
                switch response.result {
                case .success:
                    self.storeEntities(entities: response.result.value!)
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
            let _ = self.manager!.request(queryUrl, method: .get).validate().responseObject { (response: DataResponse<Entity>) -> Void in
                switch response.result {
                case .success:
                    self.storeEntities(entities: [response.result.value!])
                    fulfill(response.result.value!)
                case .failure(let error):
                    CLSLogv("Error on GetStateForEntityIdMapped() request: %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }
    
    func GetErrorLog() -> Promise<String> {
        let queryUrl = baseAPIURL+"error_log"
        return Promise { fulfill, reject in
            let _ = self.manager!.request(queryUrl, method: .get).validate().responseString { response in
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
            let _ = self.manager!.request(queryUrl, method: .post, parameters: ["state": state], encoding: .json).validate().responseObject { (response: DataResponse<Entity>) in
                switch response.result {
                case .success:
                    let _ = Murmur(title: response.result.value!.Domain+" state set to "+response.result.value!.State)
                    self.storeEntities(entities: [response.result.value!])
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
            let _ = self.manager!.request(queryUrl, method: .post, parameters: eventData, encoding: .json).validate().responseJSON { response in
                switch response.result {
                case .success:
                    if let jsonDict = response.result.value as? [String : String] {
                        let _ = Murmur(title: eventType+" created")
                        fulfill(jsonDict["message"]!)
                    }
                case .failure(let error):
                    CLSLogv("Error when attemping to CreateEvent(): %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }
    
    func CallService(domain: String, service: String, serviceData: [String:Any]) -> Promise<[ServicesResponse]> {
//        let _ = Murmur(title: domain+"/"+service+" called")
        let queryUrl = baseAPIURL+"services/"+domain+"/"+service
        return Promise { fulfill, reject in
            let _ = self.manager!.request(queryUrl, method: .post, parameters: serviceData, encoding: .json).validate().responseArray { (response: DataResponse<[ServicesResponse]>) in
                switch response.result {
                case .success:
                    fulfill(response.result.value!)
                case .failure(let error):
                    CLSLogv("Error on CallService() request: %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }
    
    func turnOn(entityId: String) -> Promise<[ServicesResponse]> {
        let _ = Murmur(title: entityId+" turned on")
        return CallService(domain: "homeassistant", service: "turn_on", serviceData: ["entity_id": entityId])
    }
    
    func turnOnEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        let _ = Murmur(title: "\(entity.Name) turned on")
        return CallService(domain: "homeassistant", service: "turn_on", serviceData: ["entity_id": entity.ID])
    }
    
    func turnOff(entityId: String) -> Promise<[ServicesResponse]> {
        let _ = Murmur(title: entityId+" turned off")
        return CallService(domain: "homeassistant", service: "turn_off", serviceData: ["entity_id": entityId])
    }
    
    func turnOffEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        let _ = Murmur(title: "\(entity.Name) turned off")
        return CallService(domain: "homeassistant", service: "turn_off", serviceData: ["entity_id": entity.ID])
    }
    
    func toggle(entityId: String) -> Promise<[ServicesResponse]> {
        let entity = realm.object(ofType: Entity.self, forPrimaryKey: entityId)
        let _ = Murmur(title: "\(entity!.Name) toggled")
        return CallService(domain: "homeassistant", service: "toggle", serviceData: ["entity_id": entityId])
    }
    
    func toggleEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        let _ = Murmur(title: "\(entity.Name) toggled")
        return CallService(domain: "homeassistant", service: "toggle", serviceData: ["entity_id": entity.ID])
    }
    
    func buildIdentifyDict() -> [String:Any] {
        let device = UIDevice.current
        let deviceKitDevice = Device()
        
        var permissionsContainer : [String] = []
        for status in PermissionScope().permissionStatuses([NotificationsPermission().type, LocationAlwaysPermission().type]) {
            if status.1 == .authorized {
                permissionsContainer.append(status.0.prettyDescription.lowercased())
            }
        }
        
        let ident = IdentifyRequest()
        ident.AppBuildNumber = Int(string: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")! as! String)
        ident.AppBundleIdentifer = Bundle.main.bundleIdentifier
        ident.AppVersionNumber = Double(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)
        ident.DeviceID = deviceID
        ident.DeviceLocalizedModel = device.localizedModel
        ident.DeviceModel = device.model
        ident.DeviceName = device.name
        ident.DevicePermanentID = DeviceUID.uid()
        ident.DeviceSystemName = device.systemName
        ident.DeviceSystemVersion = device.systemVersion
        ident.DeviceType = deviceKitDevice.description
        ident.Permissions = permissionsContainer
        ident.PushID = endpointARN.components(separatedBy: "/").last!
        ident.PushSounds = listAllInstalledPushNotificationSounds()
        ident.PushToken = deviceToken
        
        return Mapper().toJSON(ident)
    }
    
    func identifyDevice() -> Promise<String> {
        let queryUrl = baseAPIURL+"ios/identify"
        return Promise { fulfill, reject in
            let _ = self.manager!.request(queryUrl, method: .post, parameters: buildIdentifyDict(), encoding: .json).validate().responseString { response in
                switch response.result {
                case .success:
                    fulfill(response.result.value!)
                case .failure(let error):
                    CLSLogv("Error when attemping to identifyDevice(): %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }
    
    func setupPushActions() -> Promise<Set<UIUserNotificationCategory>> {
        let queryUrl = baseAPIURL+"ios/push"
        return Promise { fulfill, reject in
            let _ = self.manager!.request(queryUrl, method: .get).validate().responseArray { (response: DataResponse<[PushCategory]>) in
                switch response.result {
                case .success:
                    var allCategories = Set<UIMutableUserNotificationCategory>()
                    for category in response.result.value! {
                        let finalCategory = UIMutableUserNotificationCategory()
                        finalCategory.identifier = category.Identifier
                        var defaultCategoryActions = [UIMutableUserNotificationAction]()
                        var minimalCategoryActions = [UIMutableUserNotificationAction]()
                        for action in category.Actions! {
                            let newAction = UIMutableUserNotificationAction()
                            newAction.title = action.Title
                            newAction.identifier = action.Identifier
                            newAction.isAuthenticationRequired = action.AuthenticationRequired!
                            newAction.isDestructive = action.Destructive!
                            newAction.behavior = (action.Behavior == "default") ? UIUserNotificationActionBehavior.default : UIUserNotificationActionBehavior.textInput
                            newAction.activationMode = (action.ActivationMode == "foreground") ? UIUserNotificationActivationMode.foreground : UIUserNotificationActivationMode.background
                            if let params = action.Parameters {
                                newAction.parameters = params
                            }
                            if (action.Context == "default") {
                                defaultCategoryActions.append(newAction)
                            } else {
                                minimalCategoryActions.append(newAction)
                            }
                        }
                        finalCategory.setActions(defaultCategoryActions, for: UIUserNotificationActionContext.default)
                        finalCategory.setActions(minimalCategoryActions, for: UIUserNotificationActionContext.minimal)
                        allCategories.insert(finalCategory)
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
    func setupUserNotificationPushActions() -> Promise<Set<UNNotificationCategory>> {
        let queryUrl = baseAPIURL+"ios/push"
        return Promise { fulfill, reject in
            let _ = self.manager!.request(queryUrl, method: .get).validate().responseArray { (response: DataResponse<[PushCategory]>) in
                switch response.result {
                case .success:
                    var allCategories = Set<UNNotificationCategory>()
                    for category in response.result.value! {
                        var categoryActions = [UNNotificationAction]()
                        for action in category.Actions! {
                            var actionOptions = UNNotificationActionOptions([])
                            if action.AuthenticationRequired! {
                                actionOptions.insert(.authenticationRequired)
                            }
                            if action.Destructive! {
                                actionOptions.insert(.destructive)
                            }
                            if (action.ActivationMode == "foreground") {
                                actionOptions.insert(.foreground)
                            }
                            if (action.Behavior == "default") {
                                let newAction = UNNotificationAction(identifier: action.Identifier!, title: action.Title!, options: actionOptions)
                                categoryActions.append(newAction)
                            } else if (action.Behavior == "TextInput") {
                                let newAction = UNTextInputNotificationAction(identifier: action.Identifier!, title: action.Title!, options: actionOptions, textInputButtonTitle: action.TextInputButtonTitle!, textInputPlaceholder: action.TextInputPlaceholder!)
                                categoryActions.append(newAction)
                            }
                        }
                        let finalCategory = UNNotificationCategory.init(identifier: category.Identifier!, actions: categoryActions, intentIdentifiers: [], options: [.customDismissAction])
                        allCategories.insert(finalCategory)
                    }
                    fulfill(allCategories)
                case .failure(let error):
                    CLSLogv("Error on setupUserNotificationPushActions() request: %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }
    
    func getBeacons() -> Promise<[Beacon]> {
        let queryUrl = baseAPIURL+"ios/beacons"
        return Promise { fulfill, reject in
            let _ = self.manager!.request(queryUrl, method: .get).validate().responseArray { (response: DataResponse<[Beacon]>) in
                switch response.result {
                case .success:
                    fulfill(response.result.value!)
                case .failure(let error):
                    CLSLogv("Error when attemping to getBeacons(): %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }
    
    func getImage(imageUrl: String) -> Promise<UIImage> {
        var url = imageUrl
        if url.hasPrefix("/local/") || url.hasPrefix("/api/") {
            url = baseAPIURL+url.replacingOccurrences(of: "/api/", with: "").replacingOccurrences(of: "/local", with: "")
        }
        return Promise { fulfill, reject in
            let _ = self.manager!.request(url, method: .get).validate().responseImage { response in
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
    
    func locationEnabled() -> Bool {
        return PermissionScope().statusLocationAlways() == .authorized && self.loadedComponents.contains("device_tracker")
    }

}

class BonjourDelegate : NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    
    var resolving = [NetService]()
    var resolvingDict = [String:NetService]()
    
    // Browser methods
    
    func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser, didFind netService: NetService, moreComing moreServicesComing: Bool) {
        NSLog("BonjourDelegate.Browser.didFindService")
        netService.delegate = self
        resolvingDict[netService.name] = netService
        netService.resolve(withTimeout: 0.0)
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        NSLog("BonjourDelegate.Browser.netServiceDidResolveAddress")
        let dataDict = NetService.dictionary(fromTXTRecord: sender.txtRecordData()!)
        let baseUrl = copyStringFromTXTDict(dict: dataDict, which: "base_url")
        let requiresAPIPassword = (copyStringFromTXTDict(dict: dataDict, which: "requires_api_password") == "true")
        let useSSL = (baseUrl![4] == "s")
        let version = copyStringFromTXTDict(dict: dataDict, which: "version")
        let discoveryInfo : [String:Any] = ["name": sender.name, "baseUrl": baseUrl!, "requires_api_password": requiresAPIPassword, "version": version!, "use_ssl": useSSL]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "homeassistant.discovered"), object: nil, userInfo: discoveryInfo)
    }
    
    func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser, didRemove netService: NetService, moreComing moreServicesComing: Bool) {
        NSLog("BonjourDelegate.Browser.didRemoveService")
        let discoveryInfo : [NSObject:Any] = ["name" as NSObject: netService.name]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "homeassistant.undiscovered"), object: nil, userInfo: discoveryInfo)
        resolvingDict.removeValue(forKey: netService.name)
    }
    
//    func netServiceBrowser(netServiceBrowser: NetServiceBrowser, didFindDomain domainName: String, moreComing moreDomainsComing: Bool) {
//        NSLog("BonjourDelegate.Browser.netServiceBrowser.didFindDomain")
//    }
//    func netServiceBrowser(netServiceBrowser: NetServiceBrowser, didRemoveDomain domainName: String, moreComing moreDomainsComing: Bool) {
//        NSLog("BonjourDelegate.Browser.netServiceBrowser.didRemoveDomain")
//    }
//    func netServiceBrowserWillSearch(netServiceBrowser: NetServiceBrowser){
//        NSLog("BonjourDelegate.Browser.netServiceBrowserWillSearch")
//    }
//    func netServiceBrowser(netServiceBrowser: NetServiceBrowser, didNotSearch errorInfo: [String : NSNumber]) {
//        NSLog("BonjourDelegate.Browser.netServiceBrowser.didNotSearch")
//    }
//    func netServiceBrowserDidStopSearch(netServiceBrowser: NetServiceBrowser) {
//        NSLog("BonjourDelegate.Browser.netServiceBrowserDidStopSearch")
//    }
//    func netServiceWillPublish(sender: NetService) {
//        NSLog("BonjourDelegate.Browser.netServiceWillPublish:\(sender)");
//    }
    
    private func copyStringFromTXTDict(dict: [String : Data], which: String) -> String? {
        if let data = dict[which] {
            return String(data: data, encoding: .utf8)
        } else {
            return nil
        }
    }
    
    // Publisher methods
    
//    func netService(sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
//        NSLog("BonjourDelegate.Publisher.didNotPublish:\(sender)");
//    }
//    func netServiceDidPublish(sender: NetService) {
//        NSLog("BonjourDelegate.Publisher.netServiceDidPublish:\(sender)");
//    }
//    func netServiceWillResolve(sender: NetService) {
//        NSLog("BonjourDelegate.Publisher.netServiceWillResolve:\(sender)");
//    }
//    func netService(sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
//        NSLog("BonjourDelegate.Publisher.netServiceDidNotResolve:\(sender)");
//    }
//    func netService(sender: NetService, didUpdateTXTRecordData data: NSData) {
//        NSLog("BonjourDelegate.Publisher.netServiceDidUpdateTXTRecordData:\(sender)");
//    }
//    func netServiceDidStop(sender: NetService) {
//        NSLog("BonjourDelegate.Publisher.netServiceDidStopService:\(sender)");
//    }
//    func netService(sender: NetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream stream: NSOutputStream) {
//        NSLog("BonjourDelegate.Publisher.netServiceDidAcceptConnection:\(sender)");
//    }
    
}

class Bonjour {
    var nsb: NetServiceBrowser
    var nsp: NetService
    var nsdel: BonjourDelegate?
    
    init() {
        self.nsb = NetServiceBrowser()
        self.nsp = NetService(domain: "local", type: "_home-assistant-ios._tcp.", name: "Home Assistant iOS App", port: 65535)
    }
    
    func buildPublishDict() -> [String: Data] {
        return [
            "permanentID": DeviceUID.uid().data(using: .utf8)!,
            "bundleIdentifer": Bundle.main.bundleIdentifier!.data(using: .utf8)!,
            "versionNumber": (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String).data(using: .utf8)!,
            "buildNumber": (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String).data(using: .utf8)!
        ]
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

class Location {
    let locationManager = CLLocationManager()
    init(){
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = LocationDelegate()
        if let uuid = NSUUID(uuidString: "B9407F30-F5F8-466E-AFF9-25556B57FE6D") {
            let beaconRegion = CLBeaconRegion(proximityUUID: uuid as UUID, identifier: "iBeacon")
            beaconRegion.notifyOnEntry = true
            beaconRegion.notifyOnExit = true
            locationManager.startMonitoring(for: beaconRegion)
//            locationManager.startRangingBeaconsInRegion(beaconRegion)
            locationManager.requestState(for: beaconRegion)
        }
    }
}

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("Auth status", status)
//        if status == .AuthorizedAlways {
//            if CLLocationManager.isMonitoringAvailableForClass(CLBeaconRegion.self) {
//                if CLLocationManager.isRangingAvailable() {
//                    let uuid = NSUUID(UUIDString: "B9407F30-F5F8-466E-AFF9-25556B57FE6D")!
//                    let beaconRegion = CLBeaconRegion(proximityUUID: uuid, major: 60042, minor: 43814, identifier: "MyBeacon")
//                    
//                    manager.startMonitoringForRegion(beaconRegion)
//                    manager.startRangingBeaconsInRegion(beaconRegion)
//                }
//            }
//        }
//        switch status {
//        case .Denied, .Restricted:
//            let err = LocationError.AuthorizationDidChange(newStatus: status)
//            self.cancelAllGeographicLocationMonitors(err)
//            break
//        case .AuthorizedAlways, .AuthorizedWhenInUse:
//            self.startAllPendingGeographicLocationMonitors()
//            break
//        default:
//            break
//        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        print("State determined for region", region.identifier, "is", state)
//        if let request = self.monitoredGeoRegions.filter({ request in request.region == region }).first {
//            switch state {
//            case .Inside:
//                request.onRegionEntered?()
//            case .Outside:
//                request.onRegionExited?()
//            default:
//                break
//            }
//        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Region entered!", region.identifier)
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Region exited!", region.identifier)
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Swift.Error) {
        print("Monitoring failed for region", region!.identifier, "with error", error)
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        print("didRangeBeacons", beacons, "for region", region.identifier)
//        if let request = self.monitoredBeacons.filter({request in return request.beaconRegion == region}).first {
//            request.onRangeDidFoundBeacons?(beacons)
//        }
        if beacons.count > 0 {
            print("Got beacons", beacons)
        } else {
            print("No beacons found!")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, rangingBeaconsDidFailFor region: CLBeaconRegion, withError error: Swift.Error) {
//        if let request = self.monitoredBeacons.filter({request in return request.beaconRegion == region}).first {
//            request.onRangeDidFail?(LocationError.LocationManager(error: error))
//            self.stopMonitorForBeaconRegion(request)
//        }
    }
}

// This isn't getting called at all currently????
@available(iOS 10.0, *)
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("UserNotification didReceive!", response)
        print("Action button hit", response.actionIdentifier)
        print("response", response)
        let device = Device()
        var eventData : [String:Any] = ["actionName": response.actionIdentifier, "sourceDevicePermanentID": DeviceUID.uid(), "sourceDeviceName": device.name]
        if let dataDict = response.notification.request.content.userInfo["homeassistant"] {
            eventData["action_data"] = dataDict
        }
        if let textInput = response as? UNTextInputNotificationResponse {
            eventData["response_info"] = textInput.userText
        }
        HomeAssistantAPI.sharedInstance.CreateEvent(eventType: "ios.notification_action_fired", eventData: eventData).then { _ in
            completionHandler()
        }.catch {error in
            Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
            completionHandler()
        }
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("UserNotification willPresent!", notification)
        completionHandler([.alert, .badge, .sound])
    }
}
