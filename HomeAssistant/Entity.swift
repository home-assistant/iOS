//
//  Entity.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import RealmSwift

class Entity: Object, Mappable {
    let prefs = NSUserDefaults.standardUserDefaults()
    
    dynamic var ID = ""
    dynamic var Domain: String = ""
    dynamic var State: String = ""
    dynamic var Attributes: [String : AnyObject] = [:]
    //    private dynamic var attributesData: NSData?
    dynamic var FriendlyName: String?
    dynamic var Hidden: Bool = false
    dynamic var Icon: String?
    dynamic var MobileIcon: String?
    dynamic var Picture: String?
    dynamic var LastChanged: NSDate?
    dynamic var LastUpdated: NSDate?
    
    func objectForMapping(map: Map) -> Mappable? {
        if let entityId: String = map["entity_id"].value() {
            let entityType = getEntityType(entityId)
            switch entityType {
            case "binary_sensor":
                return BinarySensor(map)
            case "device_tracker":
                return DeviceTracker(map)
            case "group":
                return Group(map)
            case "garage_door":
                return GarageDoor(map)
            case "input_boolean":
                return InputBoolean(map)
            case "input_select":
                return InputSelect(map)
            case "light":
                return Light(map)
            case "lock":
                return Lock(map)
            case "media_player":
                return MediaPlayer(map)
            case "scene":
                return Scene(map)
            case "script":
                return Script(map)
            case "sensor":
                return Sensor(map)
            case "sun":
                return Sun(map)
            case "switch":
                return Switch(map)
            case "thermostat":
                return Thermostat(map)
            case "weblink":
                return Weblink(map)
            case "zone":
                return Zone(map)
            default:
                print("No component ObjectMapper found for:", entityId, entityType, map.JSONDictionary)
                return Entity(map)
            }
        }
        return nil
    }
    
    // More info: https://github.com/Hearst-DD/ObjectMapper/issues/462
    
    required convenience init?(_ map: Map) {
        self.init()
    }

    func mapping(map: Map) {
        var timezone = NSTimeZone.localTimeZone()
        if let HATimezone = prefs.stringForKey("time_zone") {
            timezone = NSTimeZone(name: HATimezone)!
        }
        
        ID            <- map["entity_id"]
        Domain        <- (map["entity_id"], EntityIDToDomainTransform())
        State         <- map["state"]
        Attributes    <- map["attributes"]
        FriendlyName  <- map["attributes.friendly_name"]
        Hidden        <- map["attributes.hidden"]
        Icon          <- map["attributes.icon"]
        MobileIcon    <- map["attributes.mobile_icon"]
        Picture       <- map["attributes.entity_picture"]
        LastChanged   <- (map["last_changed"], CustomDateFormatTransformWithTimezone(formatString: "yyyy-MM-dd'T'HH:mm:ss.SSSZ", timezone: timezone))
        LastUpdated   <- (map["last_updated"], CustomDateFormatTransformWithTimezone(formatString: "yyyy-MM-dd'T'HH:mm:ss.SSSZ", timezone: timezone))
    }
    
    override class func ignoredProperties() -> [String] {
        return ["Attributes"]
    }
    
    override static func primaryKey() -> String? {
        return "ID"
    }
    
    func turnOn() {
        HomeAssistantAPI.sharedInstance.turnOnEntity(self)
    }
    
    func turnOff() {
        HomeAssistantAPI.sharedInstance.turnOffEntity(self)
    }
    
    func toggle() {
        HomeAssistantAPI.sharedInstance.toggleEntity(self)
    }
}

public class EntityIDToDomainTransform: TransformType {
    public typealias Object = String
    public typealias JSON = String
    
    public init() {}
    
    public func transformFromJSON(value: AnyObject?) -> String? {
        if let entityId = value as? String {
            return getEntityType(entityId)
        }
        return nil
    }
    
    public func transformToJSON(value: String?) -> String? {
        return nil
    }
}

public class CustomDateFormatTransformWithTimezone: DateFormatterTransform {
    
    public init(formatString: String, timezone: NSTimeZone) {
        let formatter = NSDateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        formatter.dateFormat = formatString
        formatter.timeZone = timezone
        
        super.init(dateFormatter: formatter)
    }
}