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
import Realm

class Entity: Object, StaticMappable {
    let DefaultEntityUIColor = colorWithHexString("#44739E", alpha: 1)
    
    dynamic var ID: String = ""
    dynamic var Domain: String = ""
    dynamic var State: String = ""
    dynamic var Attributes: [String:AnyObject] = [:]
    dynamic var FriendlyName: String? = nil
    dynamic var Hidden = false
    dynamic var Icon: String? = nil
    dynamic var MobileIcon: String? = nil
    dynamic var Picture: String? = nil
    var DownloadedPicture: UIImage?
    dynamic var LastChanged: NSDate? = nil
    dynamic var LastUpdated: NSDate? = nil
    
    // MARK: - Requireds - https://github.com/Hearst-DD/ObjectMapper/issues/462
    required init() { super.init() }
    required init?(_ map: Map) { super.init() }
    required init(value: AnyObject, schema: RLMSchema) { super.init(value: value, schema: schema) }
    required init(realm: RLMRealm, schema: RLMObjectSchema) { super.init(realm: realm, schema: schema) }
    
    init(id: String) {
        super.init()
        self.ID = id
        self.Domain = EntityIDToDomainTransform().transformFromJSON(self.ID)!
    }
    
    class func objectForMapping(map: Map) -> Mappable? {
        if let entityId: String = map["entity_id"].value() {
            let entityType = EntityIDToDomainTransform().transformFromJSON(entityId)!
            switch entityType {
            case "binary_sensor":
                return BinarySensor(map)
            case "climate":
                return Climate(map)
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
                print("No class found for:", entityType)
                return Entity(map)
            }
        }
        return nil
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
                self.DownloadedPicture = image
            }.error { err -> Void in
                print("Error when attempting to download image", err)
            }
        }
    }
    
    override class func ignoredProperties() -> [String] {
        return ["Attributes", "DownloadedPicture"]
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
        switch self {
        case is BinarySensor:
            return (self as! BinarySensor).StateIcon()
        case is Lock:
            return (self as! Lock).StateIcon()
        case is MediaPlayer:
            return (self as! MediaPlayer).StateIcon()
        case is Sensor:
            return (self as! Sensor).StateIcon()
        default:
            return self.ComponentIcon
        }
    }

    func EntityColor() -> UIColor {
        switch self {
        case is Light:
            return (self as! Light).EntityColor()
        case is Sun:
            return (self as! Sun).EntityColor()
        case is SwitchableEntity:
            return (self as! SwitchableEntity).EntityColor()
        default:
            let hexColor = self.State == "unavailable" ? "#bdbdbd" : "#44739E"
            return colorWithHexString(hexColor, alpha: 1)
        }
    }
    
    func EntityIcon() -> UIImage {
        var icon = self.StateIcon()
        if self.MobileIcon != nil { icon = self.MobileIcon! }
        if self.Icon != nil { icon = self.Icon! }
        return getIconForIdentifier(icon, iconWidth: 30, iconHeight: 30, color: EntityColor())
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