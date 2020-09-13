//
//  WebhookSensor.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 3/8/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

public class WebhookSensor: Mappable, Equatable {
    public var Attributes: [String: Any]?
    public var DeviceClass: DeviceClass?
    public var Icon: String?
    public var Name: String?
    public var State: Any = "Initial"
    public var `Type`: String = "sensor"
    public var UniqueID: String?
    public var UnitOfMeasurement: String?

    init() {}

    public required init?(map: Map) {}

    convenience init(name: String, uniqueID: String) {
        self.init()
        self.Name = name
        self.UniqueID = uniqueID
    }

    convenience init(name: String, uniqueID: String, state: Any, unit: String? = nil) {
        self.init(name: name, uniqueID: uniqueID)
        self.State = state
        self.UnitOfMeasurement = unit
    }

    convenience init(name: String, uniqueID: String, icon: String?, state: Any, unit: String? = nil) {
        self.init(name: name, uniqueID: uniqueID, state: state, unit: unit)
        self.Icon = icon
    }

    convenience init(name: String, uniqueID: String, icon: MaterialDesignIcons, state: Any, unit: String? = nil) {
        self.init(name: name, uniqueID: uniqueID, icon: "mdi:\(icon.name)", state: state, unit: unit)
    }

    convenience init(name: String, uniqueID: String, icon: String, deviceClass: DeviceClass,
                     state: Any, unit: String? = nil) {
        self.init(name: name, uniqueID: uniqueID, icon: icon, state: state, unit: unit)
        self.DeviceClass = deviceClass
    }

    // Mappable
    public func mapping(map: Map) {
        Attributes        <-  map["attributes"]
        Icon              <-  map["icon"]
        State             <-  map["state"]
        `Type`            <-  map["type"]
        UniqueID          <-  map["unique_id"]

        let isUpdate = (map.context as? WebhookSensorContext)?.SensorUpdate ?? false

        if !isUpdate {
            DeviceClass       <-  map["device_class"]
            Name              <-  map["name"]
            UnitOfMeasurement <-  map["unit_of_measurement"]
        }
    }

    private static func string(for value: Any) -> String {
        if let value = value as? String {
            return value
        } else {
            // Swift e.g. arrays print nicely from String(describing:) but if we persist/load from disk
            // we end up with values that print like NSArray versions, which are grossly verbose
            do {
                return String(
                    data: try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
                    encoding: .utf8
                ) ?? ""
            } catch {
                Current.Log.error("couldn't describe value '\(value)'")
                return String(describing: value)
            }
        }
    }

    public var attributeDescriptions: [String: String]? {
        Attributes?.mapValues(Self.string(for:))
    }

    public var StateDescription: String? {
        let value: String

        // swiftlint:disable:next syntactic_sugar
        if case Optional<Any>.some(let inside) = State {
            value = Self.string(for: inside)
        } else {
            value = Self.string(for: State)
        }

        return value + (UnitOfMeasurement.flatMap { " " + $0 } ?? "")
    }

    public static func == (lhs: WebhookSensor, rhs: WebhookSensor) -> Bool {
        let mapper = Mapper<WebhookSensor>()
        let lhsData = try? JSONSerialization.data(withJSONObject: mapper.toJSON(lhs), options: [.sortedKeys])
        let rhsData = try? JSONSerialization.data(withJSONObject: mapper.toJSON(rhs), options: [.sortedKeys])
        return lhsData == rhsData
    }
}

public enum DeviceClass: String, CaseIterable {
    case battery
    case cold
    case connectivity
    case door
    case garage_door
    case gas
    case heat
    case humidity
    case illuminance
    case light
    case lock
    case moisture
    case motion
    case moving
    case occupancy
    case opening
    case plug
    case power
    case presence
    case pressure
    case problem
    case safety
    case smoke
    case sound
    case temperature
    case timestamp
    case vibration
    case window
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
        Success        <-  map["success"]
        ErrorMessage   <-  map["error.message"]
        ErrorCode      <-  map["error.code"]
    }
}
