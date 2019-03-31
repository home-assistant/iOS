//
//  WebhookSensor.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 3/8/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import Iconic

public class WebhookSensor: Mappable {
    public var Attributes: [String: Any]?
    public var DeviceClass: DeviceClass?
    public var Icon: String?
    public var Name: String?
    public var State: Any? = "Initial"
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
