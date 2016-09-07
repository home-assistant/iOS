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
                
                if PermissionScope().statusNotifications() == .authorized {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                if self.loadedComponents.contains("ios") {
                    CLSLogv("iOS component loaded, attempting identify and setup of push categories %@", getVaList(["this is a silly string!"]))
                    when(self.identifyDevice(), self.setupPushActions()).then { _, categories -> Void in
                        UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: [.Alert, .Sound, .Badge], categories: categories))
                    }.catch {error -> Void in
                        print("Error when attempting an identify or setup push actions", error)
                        Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
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
            Whisper.show(whistle: Murmur(title: "Connected to Home Assistant"), action: .Show(1))
        }
        
        eventSource.onError { error in
            if let err = error {
                Crashlytics.sharedInstance().recordError(err)
                print("SSE: ", err)
                Whisper.show(whistle: Murmur(title: "SSE Error! \(err.localizedDescription)"), action: .Show(1))
            }
        }
        
        eventSource.onMessage { (id, eventName, data) in
            if data == "ping" { return }
            if let event = Mapper<SSEEvent>().map(data) {
                if let mapped = event as? StateChangedEvent {
                    HomeAssistantAPI.sharedInstance.storeEntities(entities: [mapped.NewState!])
                }
                NotificationCenter.default.postNotificationName("sse."+event.Type, object: nil, userInfo: event.toJSON())
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
        
        self.CallService(domain: "device_tracker", service: "see", serviceData: locationUpdate as [String : AnyObject]).then {_ in
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
            self.manager!.request(queryUrl, withMethod: .get).validate().responseObject { (response: Response<StatusResponse, NSError>) in
                switch response.result {
                case .Success:
                    fulfill(response.result.value!)
                case .Failure(let error):
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
            self.manager!.request(queryUrl, withMethod: .get).validate().responseObject { (response: Response<ConfigResponse, NSError>) in
                switch response.result {
                case .Success:
                    fulfill(response.result.value!)
                case .Failure(let error):
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
            self.manager!.request(queryUrl, withMethod: .get).validate().responseArray { (response: Response<[ServicesResponse], NSError>) in
                switch response.result {
                case .Success:
                    fulfill(response.result.value!)
                case .Failure(let error):
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
//            self.manager!.request(queryUrl, withMethod: .get).validate().responseJSON { response in
//                switch response.result {
//                case .Success:
//                    print("GOT HISTORY", queryUrl)
//                    let mapped = Mapper<HistoryResponse>().map(response.result.value!)
//                    print("MAPPED", mapped)
//                    fulfill(mapped!)
//                case .Failure(let error):
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
            self.manager!.request(queryUrl, withMethod: .get).validate().responseArray { (response: Response<[Entity], NSError>) in
                switch response.result {
                case .Success:
                    self.storeEntities(response.result.value!)
                    fulfill(response.result.value!)
                case .Failure(let error):
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
            self.manager!.request(queryUrl, withMethod: .get).validate().responseObject { (response: Response<Entity, NSError>) in
                switch response.result {
                case .Success:
                    self.storeEntities([response.result.value!])
                    fulfill(response.result.value!)
                case .Failure(let error):
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
            self.manager!.request(queryUrl, withMethod: .get).validate().responseString { response in
                switch response.result {
                case .Success:
                    fulfill(response.result.value!)
                case .Failure(let error):
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
            self.manager!.request(.POST, withMethod: queryUrl, parameters: ["state": state], encoding: .JSON).validate().responseObject { (response: Response<Entity, NSError>) in
                switch response.result {
                case .Success:
                    show(whistle: Murmur(title: response.result.value!.Domain+" state set to "+response.result.value!.State), action: .Show(1))
                    self.storeEntities([response.result.value!])
                    fulfill(response.result.value!)
                case .Failure(let error):
                    CLSLogv("Error when attemping to SetState(): %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }
    
    func CreateEvent(eventType: String, eventData: [String:AnyObject]) -> Promise<String> {
        let queryUrl = baseAPIURL+"events/"+eventType
        return Promise { fulfill, reject in
            self.manager!.request(.POST, withMethod: queryUrl, parameters: eventData, encoding: .JSON).validate().responseJSON { response in
                switch response.result {
                case .Success:
                    if let jsonDict = response.result.value as? [String : String] {
                        show(whistle: Murmur(title: eventType+" created"), action: .Show(1))
                        fulfill(jsonDict["message"]!)
                    }
                case .Failure(let error):
                    CLSLogv("Error when attemping to CreateEvent(): %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }
    
    func CallService(domain: String, service: String, serviceData: [String:AnyObject]) -> Promise<[ServicesResponse]> {
//        show(whistle: Murmur(title: domain+"/"+service+" called"), action: .Show(1))
        let queryUrl = baseAPIURL+"services/"+domain+"/"+service
        return Promise { fulfill, reject in
            self.manager!.request(.POST, withMethod: queryUrl, parameters: serviceData, encoding: .JSON).validate().responseArray { (response: Response<[ServicesResponse], NSError>) in
                switch response.result {
                case .Success:
                    fulfill(response.result.value!)
                case .Failure(let error):
                    CLSLogv("Error on CallService() request: %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }
    
    func turnOn(entityId: String) -> Promise<[ServicesResponse]> {
        show(whistle: Murmur(title: entityId+" turned on"), action: .Show(1))
        return CallService(domain: "homeassistant", service: "turn_on", serviceData: ["entity_id": entityId as AnyObject])
    }
    
    func turnOnEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        show(whistle: Murmur(title: "\(entity.Name) turned on"), action: .Show(1))
        return CallService(domain: "homeassistant", service: "turn_on", serviceData: ["entity_id": entity.ID as AnyObject])
    }
    
    func turnOff(entityId: String) -> Promise<[ServicesResponse]> {
        show(whistle: Murmur(title: entityId+" turned off"), action: .Show(1))
        return CallService(domain: "homeassistant", service: "turn_off", serviceData: ["entity_id": entityId as AnyObject])
    }
    
    func turnOffEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        show(whistle: Murmur(title: "\(entity.Name) turned off"), action: .Show(1))
        return CallService(domain: "homeassistant", service: "turn_off", serviceData: ["entity_id": entity.ID as AnyObject])
    }
    
    func toggle(entityId: String) -> Promise<[ServicesResponse]> {
        let entity = realm.object(ofType: Entity.self, forPrimaryKey: entityId as AnyObject)
        show(whistle: Murmur(title: "\(entity!.Name) toggled"), action: .Show(1))
        return CallService(domain: "homeassistant", service: "toggle", serviceData: ["entity_id": entityId as AnyObject])
    }
    
    func toggleEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        show(whistle: Murmur(title: "\(entity.Name) toggled"), action: .Show(1))
        return CallService(domain: "homeassistant", service: "toggle", serviceData: ["entity_id": entity.ID as AnyObject])
    }
    
    func buildIdentifyDict() -> [String:AnyObject] {
        let device = UIDevice.current
        let deviceKitDevice = Device()
        let deviceInfo = ["name": device.name, "systemName": device.systemName, "systemVersion": device.systemVersion, "model": device.model, "localizedModel": device.localizedModel, "type": deviceKitDevice.description, "permanentID": DeviceUID.uid()]
        let buildNumber : Int? = Int(Bundle.main.infoDictionary!["CFBundleVersion"]! as! String)
        let versionNumber = Bundle.main.infoDictionary!["CFBundleShortVersionString"]!
        let bundleID = Bundle.main.bundleIdentifier
        let appInfo : [String: AnyObject] = ["bundleIdentifer": bundleID! as AnyObject, "versionNumber": versionNumber as AnyObject, "buildNumber": buildNumber!]
        var deviceContainer : [String : AnyObject] = ["device": deviceInfo as AnyObject, "app": appInfo as AnyObject, "permissions": [:]]
        deviceContainer["pushId"] = endpointARN.componentsSeparatedByString("/").last!
        deviceContainer["pushToken"] = deviceToken
        deviceContainer["pushSounds"] = listAllInstalledPushNotificationSounds()
        deviceContainer["deviceId"] = deviceID
        var permissionsContainer : [String] = []
        for status in PermissionScope().permissionStatuses([NotificationsPermission().type, LocationAlwaysPermission().type]) {
            if status.1 == .Authorized {
                permissionsContainer.append(status.0.prettyDescription.lowercased)
            }
        }
        deviceContainer["permissions"] = permissionsContainer
        return deviceContainer
    }
    
    func identifyDevice() -> Promise<String> {
        let queryUrl = baseAPIURL+"ios/identify"
        return Promise { fulfill, reject in
            self.manager!.request(.POST, withMethod: queryUrl, parameters: buildIdentifyDict(), encoding: .JSON).validate().responseString { response in
                switch response.result {
                case .Success:
                    fulfill(response.result.value!)
                case .Failure(let error):
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
            self.manager!.request(queryUrl, withMethod: .get).validate().responseArray { (response: Response<[PushCategory], NSError>) in
                switch response.result {
                case .Success:
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
                            newAction.authenticationRequired = action.AuthenticationRequired!
                            newAction.destructive = action.Destructive!
                            newAction.behavior = (action.Behavior == "default") ? UIUserNotificationActionBehavior.Default : UIUserNotificationActionBehavior.TextInput
                            newAction.activationMode = (action.ActivationMode == "foreground") ? UIUserNotificationActivationMode.Foreground : UIUserNotificationActivationMode.Background
                            if let params = action.Parameters {
                                newAction.parameters = params
                            }
                            if (action.Context == "default") {
                                defaultCategoryActions.append(newAction)
                            } else {
                                minimalCategoryActions.append(newAction)
                            }
                        }
                        finalCategory.setActions(defaultCategoryActions, forContext: UIUserNotificationActionContext.Default)
                        finalCategory.setActions(minimalCategoryActions, forContext: UIUserNotificationActionContext.Minimal)
                        allCategories.insert(finalCategory)
                    }
                    fulfill(allCategories)
                case .Failure(let error):
                    CLSLogv("Error on setupPushActions() request: %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }
    
    func getBeacons() -> Promise<[Beacon]> {
        let queryUrl = baseAPIURL+"ios/beacons"
        return Promise { fulfill, reject in
            self.manager!.request(queryUrl, withMethod: .get).validate().responseArray { (response: Response<[Beacon], NSError>) in
                switch response.result {
                case .Success:
                    fulfill(response.result.value!)
                case .Failure(let error):
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
            url = baseAPIURL+url.stringByReplacingOccurrencesOfString("/api/", withString: "").stringByReplacingOccurrencesOfString("/local/", withString: "")
        }
        return Promise { fulfill, reject in
            self.manager!.request(url, withMethod: .get).validate().responseImage { response in
                switch response.result {
                case .Success:
                    if let value = response.result.value {
                        fulfill(value)
                    } else {
                        print("Response was not an image!", response)
                    }
                case .Failure(let error):
                    CLSLogv("Error on getImage() request to %@: %@", getVaList([url, error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }
    
    func locationEnabled() -> Bool {
        return PermissionScope().statusLocationAlways() == .Authorized && self.loadedComponents.contains("device_tracker")
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
        let baseUrl = copyStringFromTXTDict(dict: dataDict as [NSObject : AnyObject], which: "base_url")
        let requiresAPIPassword = (copyStringFromTXTDict(dict: dataDict as [NSObject : AnyObject], which: "requires_api_password") == "true")
        let useSSL = (baseUrl![4] == "s")
        let version = copyStringFromTXTDict(dict: dataDict as [NSObject : AnyObject], which: "version")
        let discoveryInfo : [NSObject:AnyObject] = ["name" as NSObject: sender.name as AnyObject, "baseUrl" as NSObject: baseUrl!, "requires_api_password": requiresAPIPassword, "version": version!, "use_ssl": useSSL]
        NotificationCenter.defaultCenter.postNotificationName("homeassistant.discovered", object: nil, userInfo: discoveryInfo)
    }
    
    func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser, didRemove netService: NetService, moreComing moreServicesComing: Bool) {
        NSLog("BonjourDelegate.Browser.didRemoveService")
        let discoveryInfo : [NSObject:AnyObject] = ["name" as NSObject: netService.name as AnyObject]
        NotificationCenter.defaultCenter.postNotificationName("homeassistant.undiscovered", object: nil, userInfo: discoveryInfo)
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
    
    private func copyStringFromTXTDict(dict: [NSObject : AnyObject], which: String) -> String? {
        if let data = dict[which] as? NSData {
            return NSString(data: data, encoding: NSUTF8StringEncoding) as? String
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
    
    func buildPublishDict() -> [String: NSData] {
        let buildNumber = Bundle.main.infoDictionary!["CFBundleVersion"]!
        let versionNumber = Bundle.main.infoDictionary!["CFBundleShortVersionString"]!
        let bundleID = Bundle.main.bundleIdentifier
        let publishDict : [String:AnyObject] = ["permanentID": DeviceUID.uid() as AnyObject, "bundleIdentifer": bundleID! as AnyObject, "versionNumber": versionNumber as AnyObject, "buildNumber": buildNumber as AnyObject]
        var publishDictionary = [String: NSData]()
        for (key, value) in publishDict {
            guard let val = value.dataUsingEncoding(NSUTF8StringEncoding)
                else
            {
                continue
            }
            publishDictionary[key] = val
        }
        return publishDictionary
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
        nsp.setTXTRecord(NetService.data(fromTXTRecord: buildPublishDict() as [String : Data]))
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
        if let uuid = NSUUID(UUIDString: "B9407F30-F5F8-466E-AFF9-25556B57FE6D") {
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
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
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
    
    func locationManager(manager: CLLocationManager, didDetermineState state: CLRegionState, forRegion region: CLRegion) {
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
    
    func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Region entered!", region.identifier)
    }
    
    func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Region exited!", region.identifier)
    }
    
    func locationManager(manager: CLLocationManager, monitoringDidFailForRegion region: CLRegion?, withError error: NSError) {
        print("Monitoring failed for region", region!.identifier, "with error", error)
    }
    
    @objc func locationManager(manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion) {
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
    
    @objc func locationManager(manager: CLLocationManager, rangingBeaconsDidFailForRegion region: CLBeaconRegion, withError error: NSError) {
//        if let request = self.monitoredBeacons.filter({request in return request.beaconRegion == region}).first {
//            request.onRangeDidFail?(LocationError.LocationManager(error: error))
//            self.stopMonitorForBeaconRegion(request)
//        }
    }
}
