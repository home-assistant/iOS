//
//  Entity.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Entity: Mappable {
    let DefaultEntityUIColor = colorWithHexString("#44739E", alpha: 1)
    
    var ID: String = ""
    var Domain: String = ""
    var State: String = ""
    var Attributes: [String : AnyObject] = [:]
    var FriendlyName: String?
    var Hidden: Bool = false
    var Icon: String?
    var MobileIcon: String?
    var Picture: String?
    var DownloadedPicture: UIImage?
    var LastChanged: NSDate?
    var LastUpdated: NSDate?
    
    static func objectForMapping(map: Map) -> Mappable? {
        if let entityId: String = map["entity_id"].value() {
            let entityType = EntityIDToDomainTransform().transformFromJSON(entityId)!
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
    
    init(id: String) {
        self.ID = id
        self.Domain = EntityIDToDomainTransform().transformFromJSON(self.ID)!
    }
    
    required init?(_ map: Map) {
        
    }
    
    func mapping(map: Map) {
        ID            <- map["entity_id"]
        Domain        <- (map["entity_id"], EntityIDToDomainTransform())
        State         <- map["state"]
        Attributes    <- map["attributes"]
        FriendlyName  <- map["attributes.friendly_name"]
        Hidden        <- map["attributes.hidden"]
        Icon          <- map["attributes.icon"]
        MobileIcon    <- map["attributes.mobile_icon"]
        Picture       <- map["attributes.entity_picture"]
        LastChanged   <- (map["last_changed"], HomeAssistantTimestampTransform())
        LastUpdated   <- (map["last_updated"], HomeAssistantTimestampTransform())
        
        if let pic = self.Picture {
            HomeAssistantAPI.sharedInstance.getImage(pic).then { image -> Void in
                print("Downloaded image!", pic)
                self.DownloadedPicture = image
            }.error { err -> Void in
                print("Error when attempting to download image", err)
            }
        }
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
    
    var ComponentIcon : String {
        switch (self.Domain) {
        case "alarm_control_panel":
            return (self.State == "disarmed") ? "mdi:bell-outline" : "mdi:bell"
        case "automation":
            return "mdi:playlist-play"
        case "binary_sensor":
            return "mdi:radiobox-blank"
        case "camera":
            return "mdi:video"
        case "configurator":
            return "mdi:settings"
        case "conversation":
            return "mdi:text-to-speech"
        case "device_tracker":
            return "mdi:account"
        case "garage_door":
            return "mdi:glassdoor"
        case "group":
            return "mdi:google-circles-communities"
        case "homeassistant":
            return "mdi:home"
        case "input_boolean":
            return "mdi:drawing"
        case "input_select":
            return "mdi:format-list-bulleted"
        case "input_slider":
            return "mdi:ray-vertex"
        case "light":
            return "mdi:lightbulb"
        case "lock":
            return "mdi:lock-open"
        case "media_player":
            return "mdi:cast"
        case "notify":
            return "mdi:comment-alert"
        case "proximity":
            return "mdi:apple-safari"
        case "rollershutter":
            return (self.State == "open") ? "mdi:window-open" : "mdi:window-closed"
        case "scene":
            return "mdi:google-pages"
        case "script":
            return "mdi:file-document"
        case "sensor":
            return "mdi:eye"
        case "simple_alarm":
            return "mdi:bell"
        case "sun":
            return "mdi:white-balance-sunny"
        case "switch":
            return "mdi:flash"
        case "thermostat":
            return "mdi:nest-thermostat"
        case "updater":
            return "mdi:cloud-upload"
        case "weblink":
            return "mdi:open-in-new"
        default:
            return "mdi:bookmark"
        }
    }
    
    func StateIcon() -> String {
        return self.ComponentIcon
    }

    func EntityColor() -> UIColor {
        let hexColor = self.State == "unavailable" ? "#bdbdbd" : "#44739E"
        return colorWithHexString(hexColor, alpha: 1)
    }
    
    func EntityIcon() -> UIImage {
        var icon = self.StateIcon()
        if self.MobileIcon != nil { icon = self.MobileIcon! }
        if self.Icon != nil { icon = self.Icon! }
        return getIconForIdentifier(icon, iconWidth: 30, iconHeight: 30, color: self.EntityColor())
    }
}

public class EntityIDToDomainTransform: TransformType {
    public typealias Object = String
    public typealias JSON = String
    
    public init() {}
    
    public func transformFromJSON(value: AnyObject?) -> String? {
        if let entityId = value as? String {
            return entityId.componentsSeparatedByString(".")[0]
        }
        return nil
    }
    
    public func transformToJSON(value: String?) -> String? {
        return nil
    }
}

public class HomeAssistantTimestampTransform: DateFormatterTransform {
    
    public init() {
        let formatter = NSDateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = NSTimeZone.localTimeZone()
        if let HATimezone = NSUserDefaults.standardUserDefaults().stringForKey("time_zone") {
            formatter.timeZone = NSTimeZone(name: HATimezone)!
        }
        
        super.init(dateFormatter: formatter)
    }
}