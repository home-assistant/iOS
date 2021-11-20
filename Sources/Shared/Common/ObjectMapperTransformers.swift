import CoreLocation
import Foundation
import ObjectMapper
import Version

open class EntityIDToDomainTransform: TransformType {
    public typealias Object = String
    public typealias JSON = String

    public init() {}

    public func transformFromJSON(_ value: Any?) -> String? {
        if let entityId = value as? String {
            return entityId.components(separatedBy: ".")[0]
        }
        return nil
    }

    open func transformToJSON(_ value: String?) -> String? {
        nil
    }
}

open class HomeAssistantTimestampTransform: DateFormatterTransform {
    public init() {
        super.init(dateFormatter: .iso8601Milliseconds)
    }
}

public extension DateFormatter {
    static var iso8601Milliseconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()
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
            return valueString == trueValue
        } else {
            return false
        }
    }

    open func transformToJSON(_ value: Bool?) -> String? {
        (value == true) ? trueValue : falseValue
    }
}

open class FloatToIntTransform: TransformType {
    public typealias Object = Float
    public typealias JSON = Int

    public init() {}

    open func transformFromJSON(_ value: Any?) -> Float? {
        if let int = value as? Int {
            return Float(int / 100)
        }
        return nil
    }

    open func transformToJSON(_ value: Float?) -> Int? {
        guard let value = value else { return nil }
        return Int(value * 100)
    }
}

open class CLLocationCoordinate2DTransform: TransformType {
    public typealias Object = CLLocationCoordinate2D
    public typealias JSON = [Double]

    public init() {}

    open func transformFromJSON(_ value: Any?) -> CLLocationCoordinate2D? {
        if let loc = value as? [Double] {
            return CLLocationCoordinate2D(latitude: loc[0], longitude: loc[1])
        }
        return nil
    }

    open func transformToJSON(_ value: CLLocationCoordinate2D?) -> [Double]? {
        guard let value = value else { return nil }
        return value.toArray()
    }
}

open class TimeIntervalToString: TransformType {
    public typealias Object = TimeInterval
    public typealias JSON = String

    public init() {}

    open func transformFromJSON(_ value: Any?) -> TimeInterval? {
        nil
    }

    open func transformToJSON(_ value: TimeInterval?) -> String? {
        guard let value = value else { return nil }
        let interval = Int(value)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

open class VersionTransform: TransformType {
    public typealias Object = Version
    public typealias JSON = String

    public func transformFromJSON(_ value: Any?) -> Version? {
        if let value = value as? String {
            return try? Version(hassVersion: value)
        } else {
            return nil
        }
    }

    open func transformToJSON(_ value: Version?) -> String? {
        value?.description
    }
}
