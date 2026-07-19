import Foundation
import ObjectMapper

public struct WebhookSensorSetting {
    public enum SettingType {
        case `switch`(getter: () -> Bool, setter: (Bool) -> Void)
        case stepper(
            getter: () -> Double,
            setter: (Double) -> Void,
            minimum: Double = 0,
            maximum: Double = 100,
            step: Double = 1,
            displayValueFor: ((Double?) -> String?)?
        )
    }

    public let type: SettingType
    public let title: String
}

public class WebhookSensor: Mappable, Equatable, Comparable {
    public var Attributes: [String: Any]?
    public var DeviceClass: DeviceClass?
    public var Icon: String?
    public var Name: String?
    public var State: Any? = "Initial"
    public var StateClass: SensorStateClass?
    public var `Type`: String = "sensor"
    public var UniqueID: String?
    public var UnitOfMeasurement: String?
    public var entityCategory: String?
    public var translationKey: String?
    public var options: [String]?

    public var Settings: [WebhookSensorSetting] = []

    init() {}

    public required init?(map: Map) {}

    convenience init(redacting sensor: WebhookSensor) {
        self.init()
        self.Name = sensor.Name
        self.UniqueID = sensor.UniqueID
        self.State = "unavailable"
        self.Icon = "mdi:dots-square"
        self.Type = sensor.Type
    }

    convenience init(name: String, uniqueID: String) {
        self.init()
        self.Name = name
        self.UniqueID = uniqueID
    }

    convenience init(
        name: String,
        uniqueID: String,
        state: Any,
        unit: String? = nil,
        entityCategory: String? = nil,
        stateClass: SensorStateClass? = nil
    ) {
        self.init(name: name, uniqueID: uniqueID)
        self.State = state
        self.UnitOfMeasurement = unit
        self.entityCategory = entityCategory
        self.StateClass = stateClass
    }

    convenience init(
        name: String,
        uniqueID: String,
        icon: String?,
        state: Any,
        unit: String? = nil,
        entityCategory: String? = nil,
        stateClass: SensorStateClass? = nil
    ) {
        self.init(
            name: name,
            uniqueID: uniqueID,
            state: state,
            unit: unit,
            entityCategory: entityCategory,
            stateClass: stateClass
        )
        self.Icon = icon
    }

    convenience init(
        name: String,
        uniqueID: String,
        icon: MaterialDesignIcons,
        state: Any,
        unit: String? = nil,
        entityCategory: String? = nil
    ) {
        self.init(
            name: name,
            uniqueID: uniqueID,
            icon: "mdi:\(icon.name)",
            state: state,
            unit: unit,
            entityCategory: entityCategory
        )
    }

    convenience init(
        name: String,
        uniqueID: String,
        icon: String,
        deviceClass: DeviceClass,
        state: Any,
        unit: String? = nil,
        entityCategory: String? = nil
    ) {
        self.init(name: name, uniqueID: uniqueID, icon: icon, state: state, unit: unit, entityCategory: entityCategory)
        self.DeviceClass = deviceClass
    }

    // Mappable
    public func mapping(map: Map) {
        Attributes <- map["attributes"]
        Icon <- map["icon"]
        State <- map["state"]
        `Type` <- map["type"]
        UniqueID <- map["unique_id"]

        let isUpdate = (map.context as? WebhookSensorContext)?.SensorUpdate ?? false

        if !isUpdate {
            DeviceClass <- map["device_class"]
            entityCategory <- map["entity_category"]
            Name <- map["name"]
            options <- map["options"]
            StateClass <- map["state_class"]
            translationKey <- map["translation_key"]
            UnitOfMeasurement <- map["unit_of_measurement"]
        }
    }

    /// Declares the translation metadata core needs to localize an enum-style sensor's state:
    /// the raw state values stay English (existing automations keep working) and the frontend
    /// renders them through core's `entity.<platform>.<translation_key>.state.<state>` pipeline.
    /// Core requires `options` to come with an `enum` device class, so it is set here too.
    /// Servers older than `canRegisterSensorTranslationKeys` fail `register_sensor` validation on
    /// unknown keys and silently drop the whole registration, so this is a no-op for them.
    public func setEnumTranslation(key: String, options: [String], serverVersion: Version) {
        guard serverVersion >= .canRegisterSensorTranslationKeys else { return }
        translationKey = key
        self.options = options
        DeviceClass = .enum
    }

    public var StateDescription: String? {
        if let value = State {
            return String(describing: value) + (UnitOfMeasurement.flatMap { " " + $0 } ?? "")
        } else {
            return nil
        }
    }

    public static func == (lhs: WebhookSensor, rhs: WebhookSensor) -> Bool {
        let mapper = Mapper<WebhookSensor>()
        let lhsData = try? JSONSerialization.data(withJSONObject: mapper.toJSON(lhs), options: [.sortedKeys])
        let rhsData = try? JSONSerialization.data(withJSONObject: mapper.toJSON(rhs), options: [.sortedKeys])
        return lhsData == rhsData
    }

    public static func < (lhs: WebhookSensor, rhs: WebhookSensor) -> Bool {
        (lhs.Name ?? "").localizedCompare(rhs.Name ?? "") == .orderedAscending
    }
}

public class WebhookSensorContext: MapContext {
    public var SensorUpdate: Bool = false

    convenience init(update: Bool = false) {
        self.init()
        self.SensorUpdate = update
    }
}

public class WebhookSensorResponse: Mappable {
    public var Success: Bool = false
    public var ErrorMessage: String?
    public var ErrorCode: String?

    init() {}
    init(success: Bool, errorMessage: String? = nil, errorCode: String? = nil) {
        self.Success = success
        self.ErrorMessage = errorMessage
        self.ErrorCode = errorCode
    }

    public required init?(map: Map) {}

    // Mappable
    public func mapping(map: Map) {
        Success <- map["success"]
        ErrorMessage <- map["error.message"]
        ErrorCode <- map["error.code"]
    }
}
