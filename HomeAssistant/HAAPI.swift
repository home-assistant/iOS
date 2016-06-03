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

let prefs = NSUserDefaults.standardUserDefaults()

let APIClientSharedInstance = HomeAssistantAPI()

public class HomeAssistantAPI {
    
    class var sharedInstance:HomeAssistantAPI {
        get {
            return APIClientSharedInstance;
        }
    }
    
    private var manager : Alamofire.Manager?
    
    var baseAPIURL : String = ""
    var apiPassword : String = ""
    
    var deviceID : String = ""
    var endpointARN : String = ""
    var deviceToken : String = ""
    
    var mostRecentlySentMessage : String = String()
    
    var services = [NSNetService]()
    
    var headers = [String:String]()
    
    var loadedComponents = [String]()
    
    func Setup(baseAPIUrl: String, APIPassword: String) -> Promise<StatusResponse> {
        self.baseAPIURL = baseAPIUrl+"/api/"
        self.apiPassword = APIPassword
        if apiPassword != "" {
            headers["X-HA-Access"] = apiPassword
        }
        
        var defaultHeaders = Alamofire.Manager.sharedInstance.session.configuration.HTTPAdditionalHeaders ?? [:]
        for (header, value) in headers {
            defaultHeaders[header] = value
        }
        
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.HTTPAdditionalHeaders = defaultHeaders
        configuration.timeoutIntervalForResource = 3 // seconds
        
        self.manager = Alamofire.Manager(configuration: configuration)
        
        if let deviceId = prefs.stringForKey("deviceId") {
            deviceID = deviceId
        }
        
        if let endpointArn = prefs.stringForKey("endpointARN") {
            endpointARN = endpointArn
        }
        
        if let deviceTok = prefs.stringForKey("deviceToken") {
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
                    print("Found device_tracker in config components, starting location monitoring!")
                    self.trackLocation()
                }
                
                if PermissionScope().statusNotifications() == .Authorized {
                    print("User authorized the use of notifications")
                    UIApplication.sharedApplication().registerForRemoteNotifications()
                }
                
                if self.loadedComponents.contains("ios") {
                    CLSLogv("iOS component loaded, attempting identify and setup of push categories %@", getVaList(["this is a silly string!"]))
                    when(self.identifyDevice(), self.setupPushActions()).then { _, categories -> Void in
                        UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: [.Alert, .Sound, .Badge], categories: categories))
                    }.error { error -> Void in
                        print("Error when attempting an identify or setup push actions", error)
                        Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
                    }
                }
                
                self.startStream()
                fulfill(true)
            }.error { error in
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
            Whistle(Murmur(title: "Connected to Home Assistant"))
        }
        
        eventSource.onError { error in
            if let err = error {
                Crashlytics.sharedInstance().recordError(err)
                print("SSE: ", err)
                Whistle(Murmur(title: "SSE Error! \(err.localizedDescription)"))
            }
        }
        
        eventSource.onMessage { (id, eventName, data) in
            if data == "ping" { return }
            if let event = Mapper<SSEEvent>().map(data) {
                NSNotificationCenter.defaultCenter().postNotificationName("sse."+event.Type, object: nil, userInfo: event.toJSON())
            } else {
                print("Unable to ObjectMap this SSE message", eventName, data)
            }
        }
    }
    
    func submitLocation(updateType: String, latitude: Double, longitude: Double, accuracy: Double, locationName: String) {
        UIDevice.currentDevice().batteryMonitoringEnabled = true
        
        var batteryState = "Unplugged"
        switch UIDevice.currentDevice().batteryState {
            case .Unknown:
                batteryState = "Unknown"
            case .Charging:
                batteryState = "Charging"
            case .Unplugged:
                batteryState = "Unplugged"
            case .Full:
                batteryState = "Full"
        }
        
        var locationUpdate : [String:AnyObject] = [
            "battery": Int(UIDevice.currentDevice().batteryLevel*100),
            "battery_status": batteryState,
            "gps": [latitude, longitude],
            "gps_accuracy": accuracy,
            "hostname": UIDevice().name,
            "dev_id": deviceID
        ]
        
        if locationName != "" {
           locationUpdate["location_name"] = locationName
        }
        
        self.CallService("device_tracker", service: "see", serviceData: locationUpdate).then {_ in
            print("Device seen!")
        }.error { err in
            Crashlytics.sharedInstance().recordError(err as NSError)
        }
        
        UIDevice.currentDevice().batteryMonitoringEnabled = false
        
        if updateType != "" {
            let notification = UILocalNotification()
            notification.alertBody = updateType
            notification.alertAction = "open"
            notification.fireDate = NSDate()
            notification.soundName = UILocalNotificationDefaultSoundName
            UIApplication.sharedApplication().scheduleLocalNotification(notification)
        }
    }
    
    func trackLocation() {
        LocationManager.shared.observeLocations(.Neighborhood, frequency: .Significant, onSuccess: { (location) -> Void in
            self.submitLocation("Significant location change detected", latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, accuracy: location.horizontalAccuracy, locationName: "")
        }, onError: { (error) -> Void in
            // something went wrong. request will be cancelled automatically
            print("Something went wrong when trying to get significant location updates! Error was:", error)
            Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
        })
        
        self.GetStates().then { states -> Void in
            for zone in states.filter({ return $0.Domain == "zone" }) {
                let zone = zone as! Zone
                if zone.Latitude != nil && zone.Longitude != nil {
                    let regionCoordinates = CLLocationCoordinate2DMake(zone.Latitude!, zone.Longitude!)
                    try BeaconManager.shared.monitorGeographicRegion(centeredAt: regionCoordinates, radius: zone.Radius!, onEnter: { (region) -> Void in
                        print("Region entered!", region)
                        var title = "Region"
                        if let friendlyName = zone.FriendlyName {
                            title = friendlyName+" zone"
                        }
                        self.submitLocation(title+" entered", latitude: regionCoordinates.latitude, longitude: regionCoordinates.longitude, accuracy: 1, locationName: "")
                    }) { (region) -> Void in
                        print("Region exited!", region)
                        var title = "Region"
                        if let friendlyName = zone.FriendlyName {
                            title = friendlyName+" zone"
                        }
                        self.submitLocation(title+" exited", latitude: regionCoordinates.latitude, longitude: regionCoordinates.longitude, accuracy: 1, locationName: "")
                    }
                }
            }
        }.error { error in
            print("Error when getting states!", error)
            Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
        }

    }
    
    func sendOneshotLocation(notifyString: String) -> Promise<Bool> {
        return Promise { fulfill, reject in
            LocationManager.shared.observeLocations(.Neighborhood, frequency: .OneShot, onSuccess: { (location) -> Void in
                self.submitLocation(notifyString, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, accuracy: location.horizontalAccuracy, locationName: "")
                fulfill(true)
            }) { (error) -> Void in
                print("Error when trying to get a oneshot location!", error)
                Crashlytics.sharedInstance().recordError((error as Any) as! NSError)
                reject(error)
            }
        }
    }
    
    func GetStatus() -> Promise<StatusResponse> {
        let queryUrl = baseAPIURL
        return Promise { fulfill, reject in
            self.manager!.request(.GET, queryUrl).validate().responseObject { (response: Response<StatusResponse, NSError>) in
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
            self.manager!.request(.GET, queryUrl).validate().responseObject { (response: Response<ConfigResponse, NSError>) in
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
            self.manager!.request(.GET, queryUrl).validate().responseArray { (response: Response<[ServicesResponse], NSError>) in
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
    
    func GetHistoryMapped() -> Promise<[HistoryResponse]> {
        let queryUrl = baseAPIURL+"history/period/2016-4-4"
        return Promise { fulfill, reject in
            self.manager!.request(.GET, queryUrl).validate().responseArray { (response: Response<[HistoryResponse], NSError>) in
                switch response.result {
                case .Success:
                    if let historyArray = response.result.value {
                        print("HISTORYARRAY", historyArray)
                        fulfill(historyArray)
                    }
                case .Failure(let error):
                    CLSLogv("Error on GetHistoryMapped() request: %@", getVaList([error.localizedDescription]))
                    Crashlytics.sharedInstance().recordError(error)
                    reject(error)
                }
            }
        }
    }
    
    func GetStates() -> Promise<[Entity]> {
        let queryUrl = baseAPIURL+"states"
        return Promise { fulfill, reject in
            self.manager!.request(.GET, queryUrl).validate().responseArray { (response: Response<[Entity], NSError>) in
                switch response.result {
                case .Success:
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
            self.manager!.request(.GET, queryUrl).validate().responseObject { (response: Response<Entity, NSError>) in
                switch response.result {
                case .Success:
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
            self.manager!.request(.GET, queryUrl).validate().responseString { response in
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
            self.manager!.request(.POST, queryUrl, parameters: ["state": state], encoding: .JSON).validate().responseObject { (response: Response<Entity, NSError>) in
                switch response.result {
                case .Success:
                    Whistle(Murmur(title: getEntityType(entityId)+" state set to "+state))
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
            self.manager!.request(.POST, queryUrl, parameters: eventData, encoding: .JSON).validate().responseJSON { response in
                switch response.result {
                case .Success:
                    if let jsonDict = response.result.value as? [String : String] {
                        Whistle(Murmur(title: eventType+" created"))
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
//        Whistle(Murmur(title: domain+"/"+service+" called"))
        let queryUrl = baseAPIURL+"services/"+domain+"/"+service
        return Promise { fulfill, reject in
            self.manager!.request(.POST, queryUrl, parameters: serviceData, encoding: .JSON).validate().responseArray { (response: Response<[ServicesResponse], NSError>) in
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
        Whistle(Murmur(title: entityId+" turned on"))
        return CallService("homeassistant", service: "turn_on", serviceData: ["entity_id": entityId])
    }
    
    func turnOnEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        var title = entity.ID
        if let friendlyName = entity.FriendlyName {
            title = friendlyName
        }
        Whistle(Murmur(title: title+" turned on"))
        return CallService("homeassistant", service: "turn_on", serviceData: ["entity_id": entity.ID])
    }
    
    func turnOff(entityId: String) -> Promise<[ServicesResponse]> {
        Whistle(Murmur(title: entityId+" turned off"))
        return CallService("homeassistant", service: "turn_off", serviceData: ["entity_id": entityId])
    }
    
    func turnOffEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        var title = entity.ID
        if let friendlyName = entity.FriendlyName {
            title = friendlyName
        }
        Whistle(Murmur(title: title+" turned off"))
        return CallService("homeassistant", service: "turn_off", serviceData: ["entity_id": entity.ID])
    }
    
    func toggle(entityId: String) -> Promise<[ServicesResponse]> {
        Whistle(Murmur(title: entityId+" toggled"))
        return CallService("homeassistant", service: "toggle", serviceData: ["entity_id": entityId])
    }
    
    func toggleEntity(entity: Entity) -> Promise<[ServicesResponse]> {
        var title = entity.ID
        if let friendlyName = entity.FriendlyName {
            title = friendlyName
        }
        Whistle(Murmur(title: title+" toggled"))
        return CallService("homeassistant", service: "toggle", serviceData: ["entity_id": entity.ID])
    }
    
    func buildIdentifyDict() -> [String:AnyObject] {
        let device = UIDevice.currentDevice()
        let deviceKitDevice = Device()
        let deviceInfo = ["name": device.name, "systemName": device.systemName, "systemVersion": device.systemVersion, "model": device.model, "localizedModel": device.localizedModel, "type": deviceKitDevice.description, "permanentID": DeviceUID.uid()]
        let buildNumber : Int? = Int(NSBundle.mainBundle().infoDictionary!["CFBundleVersion"]! as! String)
        let versionNumber = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"]!
        let bundleID = NSBundle.mainBundle().bundleIdentifier
        let appInfo : [String: AnyObject] = ["bundleIdentifer": bundleID!, "versionNumber": versionNumber, "buildNumber": buildNumber!]
        var deviceContainer : [String : AnyObject] = ["device": deviceInfo, "app": appInfo, "permissions": [:]]
        deviceContainer["pushId"] = endpointARN.componentsSeparatedByString("/").last!
        deviceContainer["pushToken"] = deviceToken
        deviceContainer["deviceId"] = deviceID
        var permissionsContainer : [String] = []
        for status in PermissionScope().permissionStatuses([NotificationsPermission().type, LocationAlwaysPermission().type]) {
            if status.1 == .Authorized {
                permissionsContainer.append(status.0.prettyDescription.lowercaseString)
            }
        }
        deviceContainer["permissions"] = permissionsContainer
        return deviceContainer
    }
    
    func identifyDevice() -> Promise<String> {
        let queryUrl = baseAPIURL+"ios/identify"
        return Promise { fulfill, reject in
            self.manager!.request(.POST, queryUrl, parameters: buildIdentifyDict(), encoding: .JSON).validate().responseString { response in
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
            self.manager!.request(.GET, queryUrl).validate().responseArray { (response: Response<[PushCategory], NSError>) in
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
                                print("Got params", params)
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
    
    func getImage(imageUrl: String) -> Promise<UIImage> {
        var url = imageUrl
        if url.containsString("/local/") || url.containsString("/api/") {
            url = baseAPIURL+url
        }
        return Promise { fulfill, reject in
            self.manager!.request(.GET, url).validate().responseImage { response in
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

class BonjourDelegate : NSObject, NSNetServiceBrowserDelegate, NSNetServiceDelegate {
    
    var resolving = [NSNetService]()
    var resolvingDict = [String:NSNetService]()
    
    // Browser methods
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didFindService netService: NSNetService, moreComing moreServicesComing: Bool) {
        NSLog("BonjourDelegate.Browser.didFindService")
        netService.delegate = self
        resolvingDict[netService.name] = netService
        netService.resolveWithTimeout(0.0)
    }
    
    func netServiceDidResolveAddress(sender: NSNetService) {
        NSLog("BonjourDelegate.Browser.netServiceDidResolveAddress")
        let dataDict = NSNetService.dictionaryFromTXTRecordData(sender.TXTRecordData()!)
        let baseUrl = copyStringFromTXTDict(dataDict, which: "base_url")
        let requiresAPIPassword = (copyStringFromTXTDict(dataDict, which: "requires_api_password") == "true")
        let useSSL = (baseUrl![4] == "s")
        let version = copyStringFromTXTDict(dataDict, which: "version")
        let discoveryInfo : [NSObject:AnyObject] = ["name": sender.name, "baseUrl": baseUrl!, "requires_api_password": requiresAPIPassword, "version": version!, "use_ssl": useSSL]
        NSNotificationCenter.defaultCenter().postNotificationName("homeassistant.discovered", object: nil, userInfo: discoveryInfo)
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didRemoveService netService: NSNetService, moreComing moreServicesComing: Bool) {
        NSLog("BonjourDelegate.Browser.didRemoveService")
        let discoveryInfo : [NSObject:AnyObject] = ["name": netService.name]
        NSNotificationCenter.defaultCenter().postNotificationName("homeassistant.undiscovered", object: nil, userInfo: discoveryInfo)
        resolvingDict.removeValueForKey(netService.name)
    }
    
//    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didFindDomain domainName: String, moreComing moreDomainsComing: Bool) {
//        NSLog("BonjourDelegate.Browser.netServiceBrowser.didFindDomain")
//    }
//    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didRemoveDomain domainName: String, moreComing moreDomainsComing: Bool) {
//        NSLog("BonjourDelegate.Browser.netServiceBrowser.didRemoveDomain")
//    }
//    func netServiceBrowserWillSearch(netServiceBrowser: NSNetServiceBrowser){
//        NSLog("BonjourDelegate.Browser.netServiceBrowserWillSearch")
//    }
//    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didNotSearch errorInfo: [String : NSNumber]) {
//        NSLog("BonjourDelegate.Browser.netServiceBrowser.didNotSearch")
//    }
//    func netServiceBrowserDidStopSearch(netServiceBrowser: NSNetServiceBrowser) {
//        NSLog("BonjourDelegate.Browser.netServiceBrowserDidStopSearch")
//    }
//    func netServiceWillPublish(sender: NSNetService) {
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
    
//    func netService(sender: NSNetService, didNotPublish errorDict: [String : NSNumber]) {
//        NSLog("BonjourDelegate.Publisher.didNotPublish:\(sender)");
//    }
//    func netServiceDidPublish(sender: NSNetService) {
//        NSLog("BonjourDelegate.Publisher.netServiceDidPublish:\(sender)");
//    }
//    func netServiceWillResolve(sender: NSNetService) {
//        NSLog("BonjourDelegate.Publisher.netServiceWillResolve:\(sender)");
//    }
//    func netService(sender: NSNetService, didNotResolve errorDict: [String : NSNumber]) {
//        NSLog("BonjourDelegate.Publisher.netServiceDidNotResolve:\(sender)");
//    }
//    func netService(sender: NSNetService, didUpdateTXTRecordData data: NSData) {
//        NSLog("BonjourDelegate.Publisher.netServiceDidUpdateTXTRecordData:\(sender)");
//    }
//    func netServiceDidStop(sender: NSNetService) {
//        NSLog("BonjourDelegate.Publisher.netServiceDidStopService:\(sender)");
//    }
//    func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream stream: NSOutputStream) {
//        NSLog("BonjourDelegate.Publisher.netServiceDidAcceptConnection:\(sender)");
//    }
    
}

class Bonjour {
    var nsb: NSNetServiceBrowser
    var nsp: NSNetService
    var nsdel: BonjourDelegate?
    
    init() {
        self.nsb = NSNetServiceBrowser()
        self.nsp = NSNetService(domain: "local", type: "_home-assistant-ios._tcp.", name: "Home Assistant iOS App", port: 65535)
    }
    
    func buildPublishDict() -> [String: NSData] {
        let buildNumber = NSBundle.mainBundle().infoDictionary!["CFBundleVersion"]!
        let versionNumber = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"]!
        let bundleID = NSBundle.mainBundle().bundleIdentifier
        let publishDict : [String:AnyObject] = ["permanentID": DeviceUID.uid(), "bundleIdentifer": bundleID!, "versionNumber": versionNumber, "buildNumber": buildNumber]
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
        nsb.searchForServicesOfType("_home-assistant._tcp.", inDomain: "local.")
    }
    
    func stopDiscovery() {
        nsb.stop()
    }
    
    func startPublish() {
//        self.nsdel = BonjourDelegate()
//        nsp.delegate = nsdel
        nsp.setTXTRecordData(NSNetService.dataFromTXTRecordDictionary(buildPublishDict()))
        nsp.publish()
    }
    
    func stopPublish() {
        nsp.stop()
    }
    
}