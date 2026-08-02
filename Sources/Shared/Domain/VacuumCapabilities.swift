import Foundation
import HAKit

/// What a vacuum entity can do, parsed from its state attributes.
///
/// Home Assistant advertises vacuum capabilities through the `supported_features` bitmask. The
/// watch and CarPlay use this to decide which commands the vacuum's control screen offers —
/// vacuums have no single tap action, so every capable command is an explicit button.
public struct VacuumCapabilities: Equatable {
    /// `supported_features` bits, as defined by Home Assistant's vacuum entity model.
    public enum Feature: Int {
        case pause = 4
        case stop = 8
        case returnHome = 16
        case fanSpeed = 32
        case battery = 64
        case locate = 512
        case start = 8192
        case cleanArea = 16384
    }

    public let supportsStart: Bool
    public let supportsPause: Bool
    public let supportsStop: Bool
    public let supportsReturnHome: Bool
    public let supportsLocate: Bool
    /// Whether the vacuum can be told to clean specific Home Assistant areas
    /// (`vacuum.clean_area`). The areas themselves come from the entity registry — see
    /// `VacuumAreaMapping`.
    public let supportsCleanArea: Bool
    public let supportsFanSpeed: Bool
    /// The active fan speed; nil when the vacuum doesn't report one.
    public let fanSpeed: String?
    /// The selectable fan speeds; empty when the vacuum doesn't expose any.
    public let fanSpeedList: [String]
    /// 0–100; nil when the vacuum doesn't report battery (or the feature bit is unset).
    public let batteryLevel: Double?

    public init(entity: HAEntity) {
        self.init(attributes: entity.attributes.dictionary)
    }

    public init(attributes: [String: Any]) {
        let features = (attributes["supported_features"] as? Int) ?? 0
        func supports(_ feature: Feature) -> Bool {
            features & feature.rawValue != 0
        }
        self.supportsStart = supports(.start)
        self.supportsPause = supports(.pause)
        self.supportsStop = supports(.stop)
        self.supportsReturnHome = supports(.returnHome)
        self.supportsLocate = supports(.locate)
        self.supportsCleanArea = supports(.cleanArea)
        let fanSpeedList = attributes["fan_speed_list"] as? [String] ?? []
        self.supportsFanSpeed = supports(.fanSpeed) && !fanSpeedList.isEmpty
        self.fanSpeedList = fanSpeedList
        self.fanSpeed = attributes["fan_speed"] as? String
        if supports(.battery), let battery = attributes["battery_level"] as? NSNumber {
            self.batteryLevel = battery.doubleValue
        } else {
            self.batteryLevel = nil
        }
    }
}
