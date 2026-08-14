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
        case slider(
            getter: () -> Double,
            setter: (Double) -> Void,
            minimum: Double = 0,
            maximum: Double = 100,
            step: Double = 1,
            displayValueFor: ((Double?) -> String?)?
        )
        case options(
            getter: () -> Double,
            setter: (Double) -> Void,
            values: [Double],
            displayValueFor: (Double) -> String
        )
        case numericField(
            getter: () -> Double,
            setter: (Double) -> Void,
            minimum: Double = 0,
            maximum: Double = 100
        )
        case credentials(fields: [CredentialField])
    }

    public struct CredentialField {
        public let title: String
        public let placeholder: String?
        public let isSecure: Bool
        public let getter: () -> String
        public let setter: (String) -> Void

        public init(
            title: String,
            placeholder: String? = nil,
            isSecure: Bool = false,
            getter: @escaping () -> String,
            setter: @escaping (String) -> Void
        ) {
            self.title = title
            self.placeholder = placeholder
            self.isSecure = isSecure
            self.getter = getter
            self.setter = setter
        }
    }

    public let type: SettingType
    public let title: String
    /// Optional caption shown under the row, e.g. a performance warning.
    public let subtitle: String?

    public init(type: SettingType, title: String, subtitle: String? = nil) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
    }
}

public class WebhookSensor: Mappable, Equatable, Comparable {
    public var Attributes: [String: Any]?
    public var DeviceClass: DeviceClass?
    public var Icon: String?
    public var Name: String?
    public var State: Any? = "Initial"
    public var `Type`: String = "sensor"
    public var UniqueID: String?
    public var UnitOfMeasurement: String?
    public var entityCategory: String?

    public var Settings: [WebhookSensorSetting] = []

    /// Optional footer shown at the bottom of the sensor detail screen, e.g. setup
    /// instructions or usage caveats. Local-only: never sent to the server.
    public var detailFooter: String?

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

    convenience init(name: String, uniqueID: String, state: Any, unit: String? = nil, entityCategory: String? = nil) {
        self.init(name: name, uniqueID: uniqueID)
        self.State = state
        self.UnitOfMeasurement = unit
        self.entityCategory = entityCategory
    }

    convenience init(
        name: String,
        uniqueID: String,
        icon: String?,
        state: Any,
        unit: String? = nil,
        entityCategory: String? = nil
    ) {
        self.init(name: name, uniqueID: uniqueID, state: state, unit: unit, entityCategory: entityCategory)
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
            UnitOfMeasurement <- map["unit_of_measurement"]
        }
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
