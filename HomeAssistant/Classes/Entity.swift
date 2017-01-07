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

// swiftlint:disable:next type_body_length
class Entity: Object, StaticMappable {
    let DefaultEntityUIColor = colorWithHexString("#44739E", alpha: 1)

    dynamic var ID: String = ""
    dynamic var State: String = ""
    dynamic var Attributes: [String:Any] {
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
    fileprivate dynamic var attributesData: Data?
    dynamic var FriendlyName: String? = nil
    dynamic var Hidden = false
    dynamic var Icon: String? = nil
    dynamic var MobileIcon: String? = nil
    dynamic var Picture: String? = nil
    var DownloadedPicture: UIImage?
    var UnitOfMeasurement: String?
    dynamic var LastChanged: Date? = nil
    dynamic var LastUpdated: Date? = nil
    //    let Groups = LinkingObjects(fromType: Group.self, property: "Entities")

    // Z-Wave properties
    dynamic var Location: String? = nil
    dynamic var NodeID: String? = nil
    var BatteryLevel = RealmOptional<Int>()

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    class func objectForMapping(map: Map) -> BaseMappable? {
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
                print("No class found for:", entityType)
                return Entity()
            }
        }
        return nil
    }
    // swiftlint:enable cyclomatic_complexity function_body_length

    func mapping(map: Map) {
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
        BatteryLevel.value      <- map["attributes.battery_level"]

        if let pic = self.Picture {
            HomeAssistantAPI.sharedInstance.getImage(imageUrl: pic).then { image -> Void in
                self.DownloadedPicture = image
                }.catch { err -> Void in
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
        let _ = HomeAssistantAPI.sharedInstance.turnOnEntity(entity: self)
    }

    func turnOff() {
        let _ = HomeAssistantAPI.sharedInstance.turnOffEntity(entity: self)
    }

    func toggle() {
        let _ = HomeAssistantAPI.sharedInstance.toggleEntity(entity: self)
    }

    var ComponentIcon: String {
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

    func StateIcon() -> String {
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

    func EntityColor() -> UIColor {
        switch self {
        case let light as Light:
            return light.EntityColor()
        case let sun as Sun:
            return sun.EntityColor()
        case let switchableEntity as SwitchableEntity:
            return switchableEntity.EntityColor()
        default:
            let hexColor = self.State == "unavailable" ? "#bdbdbd" : "#44739E"
            return colorWithHexString(hexColor, alpha: 1)
        }
    }

    var EntityIcon: UIImage {
        return getIconForIdentifier(self.StateIcon(), iconWidth: 30, iconHeight: 30, color: self.EntityColor())
    }

    func EntityIcon(width: Double, height: Double, color: UIColor) -> UIImage {
        return getIconForIdentifier(self.StateIcon(), iconWidth: width, iconHeight: height, color: color)
    }

    var Name: String {
        if let friendly = self.FriendlyName {
            return friendly
        } else {
            return self.ID.replacingOccurrences(of: "\(self.Domain).",
                with: "").replacingOccurrences(of: "_",
                                               with: " ").capitalized
        }
    }

    var CleanedState: String {
        return self.State.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var Domain: String {
        return self.ID.components(separatedBy: ".")[0]
    }
}

open class StringObject: Object {
    open dynamic var value: String?
}

open class HomeAssistantTimestampTransform: DateFormatterTransform {

    public init() {
        let formatter = DateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX") as Locale!
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let HATimezone = UserDefaults(suiteName: "group.io.robbie.homeassistant")!.string(forKey: "time_zone") {
            formatter.timeZone = TimeZone(identifier: HATimezone)!
        } else {
            formatter.timeZone = TimeZone.autoupdatingCurrent
        }

        super.init(dateFormatter: formatter)
    }
}

open class ComponentBoolTransform: TransformType {

    public typealias Object = Bool
    public typealias JSON = String

    let trueValue: String
    let falseValue: String

    public init(trueValue: String, falseValue: String) {
        self.trueValue = trueValue
        self.falseValue = falseValue
    }

    public func transformFromJSON(_ value: Any?) -> Bool? {
        if let valueString = value as? String {
            return valueString == self.trueValue
        } else {
            return false
        }
    }

    open func transformToJSON(_ value: Bool?) -> String? {
        return (value == true) ? self.trueValue : self.falseValue
    }
}
