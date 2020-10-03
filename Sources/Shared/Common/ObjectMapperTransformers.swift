//
//  ObjectMapperTransformers.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 8/6/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import CoreLocation

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
        return nil
    }
}

open class HomeAssistantTimestampTransform: DateFormatterTransform {

    public init() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let HATimezone = Current.settingsStore.timezone {
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
        return nil
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
