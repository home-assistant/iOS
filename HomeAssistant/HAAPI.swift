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
import SwiftyJSON
import IKEventSource
import SwiftLocation

class HomeAssistantAPI: NSObject {
    
    let prefs = NSUserDefaults.standardUserDefaults()
    
    let manager:Alamofire.Manager
    
    var baseAPIURL : String = "https://homeassistant.thegrand.systems/api/"
    var apiPassword : String = "thegrand1212"
    
    init(baseAPIUrl: String, APIPassword: String) {
        baseAPIURL = baseAPIUrl+"/api/"
        apiPassword = APIPassword
        var defaultHeaders = Alamofire.Manager.sharedInstance.session.configuration.HTTPAdditionalHeaders ?? [:]
        defaultHeaders["X-HA-Access"] = apiPassword
        
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.HTTPAdditionalHeaders = defaultHeaders
        
        self.manager = Alamofire.Manager(configuration: configuration)
        
        let eventSource: EventSource = EventSource(url: baseAPIURL+"stream", headers: ["X-HA-Access": apiPassword])
        
        eventSource.onOpen {
            print("SSE: Connection Opened")
        }
        
        eventSource.onError { (error) in
            print("SSE: Error", error)
        }

        eventSource.onMessage { (id, event, data) in
            if let dataFromString = data!.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
                let json = JSON(data: dataFromString)
                switch json["event_type"] {
                case "state_changed":
                    NSNotificationCenter.defaultCenter().postNotificationName("EntityStateChanged", object: nil, userInfo: json.object as? [NSObject : AnyObject])
                    
                default:
                    print("unknown event type!!", json["event_type"])
                }
                
            }
        }
    }
    
    func trackLocation() {
        UIDevice.currentDevice().batteryMonitoringEnabled = true
        do {
            try SwiftLocation.shared.significantLocation({ (location) -> Void in
                // a new significant location has arrived
                print("NEW LOCATION!!!!", location)
                let battery = UIDevice.currentDevice().batteryLevel
                let latlongstring = [location!.coordinate.latitude.description, location!.coordinate.longitude.description]
                var deviceId = "iphone"
                if let dID = self.prefs.stringForKey("deviceId") {
                    deviceId = dID
                }
                let batlevel = String(Int(battery*100))
                let locationUpdate = ["battery": batlevel, "gps": latlongstring, "hostname": UIDevice().name, "dev_id": deviceId]
                print("About to send this to device_tracker/see", locationUpdate)
                var notification = UILocalNotification()
                notification.alertBody = "Significant location change detected, alerting Home Assistant"
                notification.alertAction = "open"
                notification.fireDate = NSDate()
                notification.soundName = UILocalNotificationDefaultSoundName // play default sound
                UIApplication.sharedApplication().scheduleLocalNotification(notification)
                self.CallService("device_tracker", service: "see", serviceData: locationUpdate as! [String : AnyObject]).then {_ in
                    print("Device seen!")
                }
            }, onFail: { (error) -> Void in
                // something went wrong. request will be cancelled automatically
                print("SOMETHING WENT WRONG!!!", error)
            })
        } catch {
            print("Error when trying to get sig location changes!!")
        }
        // Sometime in the future... you may want to interrupt the subscription
//        SwiftLocation.shared.cancelRequest(requestID)
    }
    
    func GET(url:String) -> Promise<JSON> {
        let queryUrl = baseAPIURL+url
        return Promise { fulfill, reject in
            self.manager.request(.GET, queryUrl).responseJSON { response in
//                print("Request", response.request)  // original URL request
//                print("Response", response.response) // URL response
//                print("Data", response.data)     // server data
//                print("Result", response.result)   // result of response serialization
                
                switch response.result {
                case .Success:
                    if let value = response.result.value {
                        let json = JSON(value)
//                        print("JSON: \(json)")
                        fulfill(json)
                    }
                case .Failure(let error):
                    print(error)
                    reject(error)
                }
            }
        }
    }
    func POST(url:String, parameters: [String: AnyObject]) -> Promise<JSON> {
        let queryUrl = baseAPIURL+url
        return Promise { fulfill, reject in
            self.manager.request(.POST, queryUrl, parameters: parameters, encoding: .JSON).responseJSON { response in
//                print("Request", response.request)  // original URL request
//                print("Response", response.response) // URL response
//                print("Data", response.data)     // server data
//                print("Result", response.result)   // result of response serialization
                
                switch response.result {
                case .Success:
                    if let value = response.result.value {
                        let json = JSON(value)
//                        print("JSON: \(json)")
                        fulfill(json)
                    }
                case .Failure(let error):
                    print(error)
                    reject(error)
                }
            }
        }
    }
    
    func GetStatus() -> Promise<JSON> {
        return GET("")
    }
    
    func GetConfig() -> Promise<JSON> {
        return GET("config")
    }
    
    func GetBootstrap() -> Promise<JSON> {
        return GET("bootstrap")
    }
    
    func GetEvents() -> Promise<JSON> {
        return GET("events")
    }
    
    func GetServices() -> Promise<JSON> {
        return GET("services")
    }
    
    func GetHistory() -> Promise<JSON> {
        return GET("history")
    }
    
    func GetStates() -> Promise<JSON> {
        return GET("states")
    }
    
    func GetStateForEntityId(entityId: String) -> Promise<JSON> {
        return GET("states/"+entityId)
    }
    
    func GetErrorLog() -> Promise<JSON> {
        return GET("error_log")
    }
    
    func SetState(entityId: String, state: String) -> Promise<JSON> {
        return POST("states/"+entityId, parameters: ["state": state])
    }
    
    func CreateEvent(eventType: String, eventData: [String:AnyObject]) -> Promise<JSON> {
        return POST("events/"+eventType, parameters: eventData)
    }
    
    func CallService(domain: String, service: String, serviceData: [String:AnyObject]) -> Promise<JSON> {
        return POST("services/"+domain+"/"+service, parameters: serviceData)
    }
    
    func getEntityType(entityId: String) -> String {
        return entityId.componentsSeparatedByString(".")[0]
    }
    
    func turnOn(entityId: String) -> Promise<JSON> {
        return CallService("homeassistant", service: "turn_on", serviceData: ["entity_id": entityId])
    }
    
    func turnOff(entityId: String) -> Promise<JSON> {
        return CallService("homeassistant", service: "turn_off", serviceData: ["entity_id": entityId])
    }
    
    func toggle(entityId: String) -> Promise<JSON> {
        return CallService("homeassistant", service: "toggle", serviceData: ["entity_id": entityId])
    }
}

func getEntityType(entityId: String) -> String {
    return entityId.componentsSeparatedByString(".")[0]
}