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
import SwiftyJSON
import IKEventSource
import SwiftLocation
import CoreLocation
import Whisper
import AlamofireObjectMapper
import ObjectMapper
import DeviceKit
import PermissionScope

let prefs = NSUserDefaults.standardUserDefaults()

class HomeAssistantAPI: NSObject {
    
    let manager:Alamofire.Manager?
    
    var baseAPIURL : String = ""
    var apiPassword : String = ""
    
    var mostRecentlySentMessage : String = String()
    
    var services = [NSNetService]()
    
    init(baseAPIUrl: String, APIPassword: String) {
        baseAPIURL = baseAPIUrl+"/api/"
        apiPassword = APIPassword
        var defaultHeaders = Alamofire.Manager.sharedInstance.session.configuration.HTTPAdditionalHeaders ?? [:]
        if apiPassword != "" {
            defaultHeaders["X-HA-Access"] = apiPassword
        }
        
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.HTTPAdditionalHeaders = defaultHeaders
        
        self.manager = Alamofire.Manager(configuration: configuration)
        
        var sseHeaders : [String:String] = [:]
        
        if apiPassword != "" {
            sseHeaders["X-HA-Access"] = apiPassword
        }
        
        let eventSource: EventSource = EventSource(url: baseAPIURL+"stream", headers: sseHeaders)
        
        eventSource.onOpen {
            print("SSE: Connection Opened")
            Whistle(Murmur(title: "Connected to HA realtime API!"))
        }
        
        eventSource.onError { (error) in
            if let localizedDescription = error?.localizedDescription {
                Whistle(Murmur(title: "SSE Error! \(localizedDescription)"))
            }
            print("SSE: Error", error)
        }
        
        eventSource.onMessage { (id, eventName, data) in
            if let event = Mapper<SSEEvent>().map(data) {
                NSNotificationCenter.defaultCenter().postNotificationName("sse."+event.Type, object: nil, userInfo: event.toJSON())
            } else {
                print("Unable to ObjectMap this SSE message", eventName, data)
            }
        }
    }
    
    func submitLocation(updateType: String, deviceId: String, latitude: Double, longitude: Double, accuracy: Double, locationName: String) {
        UIDevice.currentDevice().batteryMonitoringEnabled = true
        
        var locationUpdate : [String:AnyObject] = [
            "battery": Int(UIDevice.currentDevice().batteryLevel*100),
            "gps": [latitude, longitude],
            "gps_accuracy": accuracy,
            "hostname": UIDevice().name,
            "dev_id": deviceId
        ]
        
        if locationName != "" {
           locationUpdate["location_name"] = locationName
        }
        
        self.CallService("device_tracker", service: "see", serviceData: locationUpdate).then {_ in
            print("Device seen!")
        }
        
        UIDevice.currentDevice().batteryMonitoringEnabled = false
        
        let notification = UILocalNotification()
        notification.alertBody = updateType+", alerting Home Assistant"
        notification.alertAction = "open"
        notification.fireDate = NSDate()
        notification.soundName = UILocalNotificationDefaultSoundName
        UIApplication.sharedApplication().scheduleLocalNotification(notification)
    }
    
    func trackLocation(deviceId: String) {
        do {
            try SwiftLocation.shared.significantLocation({ (location) -> Void in
                self.submitLocation("Significant location change detected", deviceId: deviceId, latitude: location!.coordinate.latitude, longitude: location!.coordinate.longitude, accuracy: location!.horizontalAccuracy, locationName: "")
            }, onFail: { (error) -> Void in
                // something went wrong. request will be cancelled automatically
                print("Something went wrong when trying to get significant location updates! Error was:", error)
            })
        } catch {
            print("Error when trying to get sig location changes!!")
        }
        
        self.GetStates().then { states -> Void in
            for zone in states.filter({ return $0.Domain == "zone" }) {
                let zone = zone as! Zone
                if zone.Latitude != nil && zone.Longitude != nil {
                    let regionCoordinates = CLLocationCoordinate2DMake(zone.Latitude!, zone.Longitude!)
                    let region = CLCircularRegion(center: regionCoordinates, radius: CLLocationDistance(zone.Radius!), identifier: zone.ID)
                    do {
                        try SwiftLocation.shared.monitorRegion(region, onEnter: { (region) -> Void in
                            print("Region entered!", region)
                            var title = "Region"
                            if let friendlyName = zone.FriendlyName {
                                title = friendlyName+" zone"
                            }
                            self.submitLocation(title+" entered", deviceId: deviceId, latitude: regionCoordinates.latitude, longitude: regionCoordinates.longitude, accuracy: 1, locationName: "")
                        }) { (region) -> Void in
                            print("Region exited!", region)
                            var title = "Region"
                            if let friendlyName = zone.FriendlyName {
                                title = friendlyName+" zone"
                            }
                            self.submitLocation(title+" exited", deviceId: deviceId, latitude: regionCoordinates.latitude, longitude: regionCoordinates.longitude, accuracy: 1, locationName: "")
                        }
                    } catch {
                        print("Error when setting up home region location monitoring")
                    }
                }
            }
        }

    }
    
    func sendOneshotLocation() -> Promise<Bool> {
        return Promise { fulfill, reject in
            if let deviceId = prefs.stringForKey("deviceId") {
                do {
                    try SwiftLocation.shared.currentLocation(Accuracy.Neighborhood, timeout: 20, onSuccess: { (location) -> Void in
                        self.submitLocation("One off location update requested", deviceId: deviceId, latitude: location!.coordinate.latitude, longitude: location!.coordinate.longitude, accuracy: location!.horizontalAccuracy, locationName: "")
                        fulfill(true)
                    }) { (error) -> Void in
                        print("Error when trying to get a oneshot location!", error)
                        reject(error!)
                    }
                } catch {
                    print("Error when getting a oneshot location!")
                }
            }
        }
    }
    
    func GET(url:String) -> Promise<JSON> {
        let queryUrl = baseAPIURL+url
        return Promise { fulfill, reject in
            self.manager!.request(.GET, queryUrl).responseJSON { response in
                switch response.result {
                    case .Success:
                        if let value = response.result.value {
                            fulfill(JSON(value))
                        } else {
                            print("Response was not JSON!", response)
                        }
                    case .Failure(let error):
                        print("Error on GET request to \(url):", error)
                        reject(error)
                }
            }
        }
    }
    
    func POST(url:String, parameters: [String: AnyObject]) -> Promise<JSON> {
        mostRecentlySentMessage = url
        let queryUrl = baseAPIURL+url
        return Promise { fulfill, reject in
            self.manager!.request(.POST, queryUrl, parameters: parameters, encoding: .JSON).responseJSON { response in
                switch response.result {
                case .Success:
                    if let value = response.result.value {
                        fulfill(JSON(value))
                    } else {
                        print("Response was not JSON!", response)
                    }
                case .Failure(let error):
                    print("Error on GET request to \(url):", error)
                    reject(error)
                }
            }
        }
    }
    
    func GetStatus() -> Promise<StatusResponse> {
        let queryUrl = baseAPIURL+"config"
        return Promise { fulfill, reject in
            self.manager!.request(.GET, queryUrl).responseObject { (response: Response<StatusResponse, NSError>) in
                switch response.result {
                case .Success:
                    fulfill(response.result.value!)
                case .Failure(let error):
                    print("Error on GET request:", error)
                    reject(error)
                }
            }
        }
    }
    
    func GetConfig() -> Promise<ConfigResponse> {
        let queryUrl = baseAPIURL+"config"
        return Promise { fulfill, reject in
            self.manager!.request(.GET, queryUrl).responseObject { (response: Response<ConfigResponse, NSError>) in
                switch response.result {
                case .Success:
                    fulfill(response.result.value!)
                case .Failure(let error):
                    print("Error on GET request:", error)
                    reject(error)
                }
            }
        }
    }
    
    func GetBootstrap() -> Promise<JSON> {
        return GET("bootstrap")
    }
    
    func GetEvents() -> Promise<JSON> {
        return GET("events")
    }
    
    func GetServices() -> Promise<[ServicesResponse]> {
        let queryUrl = baseAPIURL+"services"
        return Promise { fulfill, reject in
            self.manager!.request(.GET, queryUrl).responseArray { (response: Response<[ServicesResponse], NSError>) in
                switch response.result {
                case .Success:
                    fulfill(response.result.value!)
                case .Failure(let error):
                    print("Error on GET request:", error)
                    reject(error)
                }
            }
        }
    }
    
    func GetHistory() -> Promise<JSON> {
        return GET("history")
    }
    
    func GetHistoryMapped() -> Promise<[HistoryResponse]> {
        let queryUrl = baseAPIURL+"history/period/2016-4-4"
        return Promise { fulfill, reject in
            self.manager!.request(.GET, queryUrl).responseArray { (response: Response<[HistoryResponse], NSError>) in
                switch response.result {
                case .Success:
                    if let historyArray = response.result.value {
                        print("HISTORYARRAY", historyArray)
                        fulfill(historyArray)
                    }
                case .Failure(let error):
                    print("Error on GET request:", error)
                    reject(error)
                }
            }
        }
    }
    
    func GetStates() -> Promise<[Entity]> {
        let queryUrl = baseAPIURL+"states"
        return Promise { fulfill, reject in
            self.manager!.request(.GET, queryUrl).responseArray { (response: Response<[Entity], NSError>) in
                switch response.result {
                case .Success:
                    fulfill(response.result.value!)
                case .Failure(let error):
                    print("Error on GET request:", error)
                    reject(error)
                }
            }
        }
    }
    
    func GetStateForEntityId(entityId: String) -> Promise<JSON> {
        return GET("states/"+entityId)
    }
    
    func GetStateForEntityIdMapped(entityId: String) -> Promise<Entity> {
        let queryUrl = baseAPIURL+"states/"+entityId
        return Promise { fulfill, reject in
            self.manager!.request(.GET, queryUrl).responseObject { (response: Response<Entity, NSError>) in
                switch response.result {
                case .Success:
                    fulfill(response.result.value!)
                case .Failure(let error):
                    print("Error on GET request:", error)
                    reject(error)
                }
            }
        }
    }
    
    func GetErrorLog() -> Promise<JSON> {
        return GET("error_log")
    }
    
    func SetState(entityId: String, state: String) -> Promise<JSON> {
        Whistle(Murmur(title: getEntityType(entityId)+" state set to "+state))
        return POST("states/"+entityId, parameters: ["state": state])
    }
    
    func CreateEvent(eventType: String, eventData: [String:AnyObject]) -> Promise<JSON> {
        Whistle(Murmur(title: eventType+" created"))
        return POST("events/"+eventType, parameters: eventData)
    }
    
    func CallService(domain: String, service: String, serviceData: [String:AnyObject]) -> Promise<JSON> {
//        Whistle(Murmur(title: domain+"/"+service+" called"))
        return POST("services/"+domain+"/"+service, parameters: serviceData)
    }
    
    func turnOn(entityId: String) -> Promise<JSON> {
        Whistle(Murmur(title: entityId+" turned on"))
        return CallService("homeassistant", service: "turn_on", serviceData: ["entity_id": entityId])
    }
    
    func turnOnEntity(entity: Entity) -> Promise<JSON> {
        var title = entity.ID
        if let friendlyName = entity.FriendlyName {
            title = friendlyName
        }
        Whistle(Murmur(title: title+" turned on"))
        return CallService("homeassistant", service: "turn_on", serviceData: ["entity_id": entity.ID])
    }
    
    func turnOff(entityId: String) -> Promise<JSON> {
        Whistle(Murmur(title: entityId+" turned off"))
        return CallService("homeassistant", service: "turn_off", serviceData: ["entity_id": entityId])
    }
    
    func turnOffEntity(entity: Entity) -> Promise<JSON> {
        var title = entity.ID
        if let friendlyName = entity.FriendlyName {
            title = friendlyName
        }
        Whistle(Murmur(title: title+" turned off"))
        return CallService("homeassistant", service: "turn_off", serviceData: ["entity_id": entity.ID])
    }
    
    func toggle(entityId: String) -> Promise<JSON> {
        Whistle(Murmur(title: entityId+" toggled"))
        return CallService("homeassistant", service: "toggle", serviceData: ["entity_id": entityId])
    }
    
    func toggleEntity(entity: Entity) -> Promise<JSON> {
        var title = entity.ID
        if let friendlyName = entity.FriendlyName {
            title = friendlyName
        }
        Whistle(Murmur(title: title+" toggled"))
        return CallService("homeassistant", service: "toggle", serviceData: ["entity_id": entity.ID])
    }
    
    func identifyDevice() -> Promise<JSON> {
        let device = UIDevice.currentDevice()
        let deviceKitDevice = Device()
        let deviceInfo = ["name": device.name, "systemName": device.systemName, "systemVersion": device.systemVersion, "model": device.model, "localizedModel": device.localizedModel, "type": deviceKitDevice.description, "permanentID": DeviceUID.uid()]
        let buildNumber : Int? = Int(NSBundle.mainBundle().infoDictionary!["CFBundleVersion"]! as! String)
        let versionNumber = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"]!
        let bundleID = NSBundle.mainBundle().bundleIdentifier
        let appInfo : [String: AnyObject] = ["bundleIdentifer": bundleID!, "versionNumber": versionNumber, "buildNumber": buildNumber!]
        var deviceContainer : [String : AnyObject] = ["device": deviceInfo, "app": appInfo, "permissions": [:]]
        if let endpointArn = prefs.stringForKey("endpointARN") {
            deviceContainer["pushToken"] = endpointArn.componentsSeparatedByString("/").last!
        }
        if let deviceTrackerId = prefs.stringForKey("deviceId") {
            deviceContainer["deviceId"] = deviceTrackerId
        }
        let permissionsContainer : [String:String] = ["location": PermissionScope().statusLocationAlways().description, "notifications": PermissionScope().statusNotifications().description]
        deviceContainer["permissions"] = permissionsContainer
        return POST("ios/identify", parameters: deviceContainer)
    }
    
    func getImage(imageUrl: String) -> Promise<UIImage> {
        var url = imageUrl
        if url.containsString("/local/") || url.containsString("/api/") {
            if let baseURL = prefs.stringForKey("baseURL") {
                url = baseURL+url
            }
        }
        return Promise { fulfill, reject in
            self.manager!.request(.GET, url).responseImage { response in
                switch response.result {
                case .Success:
                    if let value = response.result.value {
                        fulfill(value)
                    } else {
                        print("Response was not an image!", response)
                    }
                case .Failure(let error):
                    print("Error on GET image request to \(url):", error)
                    reject(error)
                }
            }
        }
    }

}

class BrowserDelegate : NSObject, NSNetServiceBrowserDelegate, NSNetServiceDelegate {
    var resolving = [NSNetService]()
    
    func ipv4Enpoint(data: NSData) -> String {
        var address = sockaddr()
        data.getBytes(&address, length: sizeof(sockaddr))
        if address.sa_family == sa_family_t(AF_INET) {
            var addressIPv4 = sockaddr_in()
            data.getBytes(&addressIPv4, length: sizeof(sockaddr))
            let host = String.fromCString(inet_ntoa(addressIPv4.sin_addr))
            let port = Int(CFSwapInt16(addressIPv4.sin_port))
            return host!+":"+String(port)
        }
        return ""
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didFindDomain domainName: String, moreComing moreDomainsComing: Bool) {
        NSLog("BrowserDelegate.netServiceBrowser.didFindDomain")
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didRemoveDomain domainName: String, moreComing moreDomainsComing: Bool) {
        NSLog("BrowserDelegate.netServiceBrowser.didRemoveDomain")
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didFindService netService: NSNetService, moreComing moreServicesComing: Bool) {
        NSLog("BrowserDelegate.netServiceBrowser.didFindService")
        netService.delegate = self
        resolving.append(netService)
        netService.resolveWithTimeout(0.0)
    }
    
    func netServiceDidResolveAddress(sender: NSNetService) {
        let dataDict = NSNetService.dictionaryFromTXTRecordData(sender.TXTRecordData()!)
        let baseUrl = copyStringFromTXTDict(dataDict, which: "base_url")
        let needsPassword = (copyStringFromTXTDict(dataDict, which: "requires_api_password") == "true")
        let version = copyStringFromTXTDict(dataDict, which: "version")
        let discoveryInfo : [NSObject:AnyObject] = ["name": sender.name, "baseUrl": baseUrl!, "needs_auth": needsPassword, "version": version!]
        NSNotificationCenter.defaultCenter().postNotificationName("homeassistant.discovered", object: nil, userInfo: discoveryInfo)
    }
    
    private func copyStringFromTXTDict(dict: [NSObject : AnyObject], which: String) -> String? {
        if let data = dict[which] as? NSData {
            return NSString(data: data, encoding: NSUTF8StringEncoding) as? String
        }
        else {
            return nil
        }
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didRemoveService netService: NSNetService, moreComing moreServicesComing: Bool) {
        NSLog("BrowserDelegate.netServiceBrowser.didRemoveService")
    }
    
    func netServiceBrowserWillSearch(aNetServiceBrowser: NSNetServiceBrowser){
        NSLog("BrowserDelegate.netServiceBrowserWillSearch")
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didNotSearch errorInfo: [String : NSNumber]) {
        NSLog("BrowserDelegate.netServiceBrowser.didNotSearch")
    }
    
//    func netServiceBrowserDidStopSearch(netServiceBrowser: NSNetServiceBrowser) {
//        NSLog("BrowserDelegate.netServiceBrowserDidStopSearch")
//    }
    
}


class Discovery {
    let BM_DOMAIN = "local."
    let BM_TYPE = "_home-assistant._tcp."
    
    var nsb: NSNetServiceBrowser
    var nsbdel: BrowserDelegate?
    
    init() {
        self.nsb = NSNetServiceBrowser()
    }
    
    func start() {
        self.nsbdel = BrowserDelegate()
        nsb.delegate = nsbdel
        nsb.searchForServicesOfType(BM_TYPE, inDomain: BM_DOMAIN)
    }
    
    func stop() {
        nsb.stop()
    }
    
}