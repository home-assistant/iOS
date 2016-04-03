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
    
    let manager:Alamofire.Manager?
    
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
                    print("unknown event type!! SSE event is \(event!) and event_type is", json["event_type"])
                }
                
            }
        }
    }
    
    func trackLocation(deviceId: String) {
        UIDevice.currentDevice().batteryMonitoringEnabled = true
        do {
            try SwiftLocation.shared.significantLocation({ (location) -> Void in
                // a new significant location has arrived
                let locationUpdate = [
                    "battery": Int(UIDevice.currentDevice().batteryLevel*100),
                    "gps": [location!.coordinate.latitude, location!.coordinate.longitude],
                    "gps_accuracy": location!.horizontalAccuracy,
                    "hostname": UIDevice().name,
                    "dev_id": deviceId
                ]
//                print("About to send this to device_tracker/see", locationUpdate)
                
                self.CallService("device_tracker", service: "see", serviceData: locationUpdate as! [String : AnyObject]).then {_ in
                    print("Device seen!")
                }
                
                let notification = UILocalNotification()
                notification.alertBody = "Significant location change detected, alerting Home Assistant"
                notification.alertAction = "open"
                notification.fireDate = NSDate()
                notification.soundName = UILocalNotificationDefaultSoundName // play default sound
                UIApplication.sharedApplication().scheduleLocalNotification(notification)
            }, onFail: { (error) -> Void in
                // something went wrong. request will be cancelled automatically
                print("Something went wrong when trying to get significant location updates! Error was:", error)
            })
        } catch {
            print("Error when trying to get sig location changes!!")
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