//
//  Entity.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

// swiftlint:disable:next type_body_length
public class Entity: StaticMappable {
    let DefaultEntityUIColor = UIColor.defaultEntityColor

    @objc public dynamic var ID: String = ""
    @objc public dynamic var State: String = ""
    @objc public dynamic var Attributes: [String: Any] {
        get {
            guard let dictionaryData = attributesData else {
                return [String: Any]()
            }
            do {
                let dict = try JSONSerialization.jsonObject(with: dictionaryData, options: []) as? [String: Any]
                return dict!
            } catch {
                return [String: Any]()
            }
        }

        set {
            do {
                let data = try JSONSerialization.data(withJSONObject: newValue, options: [])
                attributesData = data
            } catch {
                attributesData = nil
            }
        }
    }
    @objc fileprivate dynamic var attributesData: Data?
    @objc public dynamic var FriendlyName: String?
    @objc public dynamic var Hidden = false
    @objc public dynamic var Icon: String?
    @objc public dynamic var MobileIcon: String?
    @objc public dynamic var Picture: String?
    public var DownloadedPicture: UIImage?
    public var UnitOfMeasurement: String?
    @objc public dynamic var LastChanged: Date?
    @objc public dynamic var LastUpdated: Date?
    //    let Groups = LinkingObjects(fromType: Group.self, property: "Entities")

    // Z-Wave properties
    @objc public dynamic var Location: String?
    @objc public dynamic var NodeID: String?
    public var BatteryLevel: Int?

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public class func objectForMapping(map: Map) -> BaseMappable? {
        if let entityId: String = map["entity_id"].value() {
            let entityType = entityId.components(separatedBy: ".")[0]
            switch entityType {
            case "automation":
                return Automation()
            case "binary_sensor":
                return BinarySensor()
            case "climate":
                return Climate()
            case "device_tracker":
                return DeviceTracker()
            case "fan":
                return Fan()
            case "group":
                return Group()
            case "garage_door":
                return GarageDoor()
            case "input_boolean":
                return InputBoolean()
            case "input_slider":
                return InputSlider()
            case "input_select":
                return InputSelect()
            case "light":
                return Light()
            case "lock":
                return Lock()
            case "media_player":
                return MediaPlayer()
            case "scene":
                return Scene()
            case "script":
                return Script()
            case "sensor":
                return Sensor()
            case "sun":
                return Sun()
            case "switch":
                return Switch()
            case "thermostat":
                return Thermostat()
            case "weblink":
                return Weblink()
            case "zone":
                return Zone()
            default:
                //print("No class found for:", entityType)
                return Entity()
            }
        }
        return nil
    }

    public func mapping(map: Map) {
        ID                <- map["entity_id"]
        State             <- map["state"]
        Attributes        <- map["attributes"]
        FriendlyName      <- map["attributes.friendly_name"]
        Hidden            <- map["attributes.hidden"]
        Icon              <- map["attributes.icon"]
        MobileIcon        <- map["attributes.mobile_icon"]
        Picture           <- map["attributes.entity_picture"]
        UnitOfMeasurement <- map["attributes.unit_of_measurement"]
        LastChanged       <- (map["last_changed"], HomeAssistantTimestampTransform())
        LastUpdated       <- (map["last_updated"], HomeAssistantTimestampTransform())

        // Z-Wave properties
        NodeID            <- map["attributes.node_id"]
        Location          <- map["attributes.location"]
        BatteryLevel      <- map["attributes.battery_level"]

    }

    public func turnOn() {
        _ = HomeAssistantAPI.authenticatedAPI()?.turnOnEntity(entity: self)
    }

    public func turnOff() {
        _ = HomeAssistantAPI.authenticatedAPI()?.turnOffEntity(entity: self)
    }

    public func toggle() {
        _ = HomeAssistantAPI.authenticatedAPI()?.toggleEntity(entity: self)
    }

    public var ComponentIcon: String {
        switch self.Domain {
        case "alarm_control_panel":
            return "mdi:bell"
        case "automation":
            return "mdi:playlist-play"
        case "binary_sensor":
            return "mdi:checkbox-marked-circle"
        case "camera":
            return "mdi:video"
        case "climate":
            return "mdi:nest-thermostat"
        case "configurator":
            return "mdi:settings"
        case "conversation":
            return "mdi:text-to-speech"
        case "cover":
            return "mdi:window-closed"
        case "device_tracker":
            return "mdi:account"
        case "fan":
            return "mdi:fan"
        case "garage_door":
            return "mdi:glassdoor"
        case "group":
            return "mdi:google-circles-communities"
        case "homeassistant":
            return "mdi:home"
        case "hvac":
            return "mdi:air-conditioner"
        case "input_boolean":
            return "mdi:drawing"
        case "input_select":
            return "mdi:format-list-bulleted"
        case "input_slider":
            return "mdi:ray-vertex"
        case "light":
            return "mdi:lightbulb"
        case "lock":
            return "mdi:lock"
        case "media_player":
            return "mdi:cast"
        case "notify":
            return "mdi:comment-alert"
        case "proximity":
            return "mdi:apple-safari"
        case "rollershutter":
            return "mdi:window-closed"
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
            print("Unable to find icon for domain \(self.Domain) (\(self.State))")
            return "mdi:bookmark"
        }
    }

    public func StateIcon() -> String {
        if self.MobileIcon != nil { return self.MobileIcon! }
        if self.Icon != nil { return self.Icon! }
        switch self {
        case let binarySensor as BinarySensor:
            return binarySensor.StateIcon()
        case let lock as Lock:
            return lock.StateIcon()
        case let mediaPlayer as MediaPlayer:
            return mediaPlayer.StateIcon()
        default:
            if self.UnitOfMeasurement == "°C" || self.UnitOfMeasurement == "°F" {
                return "mdi:thermometer"
            } else if self.UnitOfMeasurement == "Mice" {
                return "mdi:mouse-variant"
            }
            return self.ComponentIcon
        }
    }

    public var EntityColor: UIColor {
        switch self.Domain {
        case "binary_sensor", "input_boolean", "media_player", "script", "switch":
            return self.State == "on" ? UIColor.onColor : self.DefaultEntityUIColor
        case "light":
            if self.State == "on" {
                if let rgb = self.Attributes["rgb_color"] as? [Float] {
                    let red = CGFloat(rgb[0]/255.0)
                    let green = CGFloat(rgb[1]/255.0)
                    let blue = CGFloat(rgb[2]/255.0)
                    return UIColor.init(red: red, green: green, blue: blue, alpha: 1)
                } else {
                    return UIColor.onColor
                }
            } else {
                return self.DefaultEntityUIColor
            }
        case "sun":
            return self.State == "above_horizon" ? UIColor.onColor : self.DefaultEntityUIColor
        default:
            let hexColor = self.State == "unavailable" ? "#bdbdbd" : "#44739E"
            return hexColor.colorWithHexValue()
        }
    }

    public var EntityIcon: UIImage {
        return  UIImage.iconForIdentifier(self.StateIcon(), iconWidth: 30, iconHeight: 30, color: self.EntityColor)
    }

    public func EntityIcon(width: Double, height: Double, color: UIColor) -> UIImage {
        return UIImage.iconForIdentifier(self.StateIcon(), iconWidth: width, iconHeight: height, color: color)
    }

    public var Name: String {
        if let friendly = self.FriendlyName {
            return friendly
        } else {
            return self.ID.replacingOccurrences(of: "\(self.Domain).",
                with: "").replacingOccurrences(of: "_",
                                               with: " ").capitalized
        }
    }

    public var CleanedState: String {
        return self.State.replacingOccurrences(of: "_", with: " ").capitalized
    }

    public var Domain: String {
        return self.ID.components(separatedBy: ".")[0]
    }
}
