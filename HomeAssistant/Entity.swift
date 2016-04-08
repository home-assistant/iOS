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

class Entity: Object, MappableCluster {
    dynamic var ID: String? = nil
    dynamic var Domain: String? = nil
    dynamic var State: String? = nil
//    private dynamic var attributesData: NSData?
    dynamic var Attributes: [String:AnyObject] = [:]
    dynamic var FriendlyName: String? = nil
    dynamic var Hidden = false
    dynamic var Icon: String? = nil
    dynamic var Picture: String? = nil
    dynamic var LastChanged: NSDate? = nil
    dynamic var LastUpdated: NSDate? = nil
    
    class func objectForMapping(map: Map) -> Mappable? {
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
            default:
                print("No ObjectMapper found for:", entityType)
                return nil
            }
        }
        return nil
    }
    
    required convenience init?(_ map: Map) {
        self.init()
    }
    
    func mapping(map: Map) {
        ID            <- map["entity_id"]
        Domain        <- (map["entity_id"], EntityIDToDomainTransform())
        State         <- map["state"]
        Attributes    <- map["attributes"]
        FriendlyName  <- map["attributes.friendly_name"]
        Hidden        <- map["attributes.hidden"]
        Icon          <- map["attributes.icon"]
        Picture       <- map["attributes.entity_picture"]
        LastChanged   <- (map["last_changed"], CustomDateFormatTransform(formatString: "HH:mm:ss dd-MM-YYYY"))
        LastUpdated   <- (map["last_updated"], CustomDateFormatTransform(formatString: "HH:mm:ss dd-MM-YYYY"))
    }
    
    override class func ignoredProperties() -> [String] {
        return ["Attributes"]
    }
    
    override static func primaryKey() -> String? {
        return "ID"
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