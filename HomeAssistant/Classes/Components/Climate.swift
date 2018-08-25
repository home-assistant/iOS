//
//  ClimateComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 9/3/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Climate: Entity {

    var AuxHeat = false
    var AwayMode = false
    var CurrentHumidity: Int?
    var CurrentTemperature: Float?
    var FanList: [String]?
    var FanMode: String?
    var Humidity: Int?
    var MaximumHumidity: Int?
    var MaximumTemp: Float?
    var MinimumHumidity: Int?
    var MinimumTemp: Float?
    var OperationList: [String]?
    var OperationMode: String?
    var SwingList: [String]?
    var SwingMode = false
    var Temperature: Float?

    override func mapping(map: Map) {
        super.mapping(map: map)

        AuxHeat                    <- (map["attributes.aux_heat"],
                                       ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        AwayMode                   <- (map["attributes.away_mode"],
                                       ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        CurrentHumidity      <- map["attributes.current_humidity"]
        CurrentTemperature   <- map["attributes.current_temperature"]
        FanMode                    <- map["attributes.fan_mode"]
        Humidity             <- map["attributes.humidity"]
        MaximumHumidity      <- map["attributes.max_humidity"]
        MaximumTemp          <- map["attributes.max_temp"]
        MinimumHumidity      <- map["attributes.min_humidity"]
        MinimumTemp          <- map["attributes.min_temp"]
        OperationMode              <- map["attributes.operation_mode"]
        SwingMode                  <- (map["attributes.swing_mode"],
                                       ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        Temperature          <- map["attributes.temperature"]

        FanList              <- map["attributes.fan_list"]

        OperationList        <- map["attributes.operation_list"]

        SwingList            <- map["attributes.swing_list"]
    }

    func TurnFanOn() {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "climate",
                                                        service: "set_fan_mode",
                                                        serviceData: [
                                                            "entity_id": self.ID as AnyObject,
                                                            "fan": "on" as AnyObject
            ])
    }

    func TurnFanOff() {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "climate",
                                                        service: "set_fan_mode",
                                                        serviceData: [
                                                            "entity_id": self.ID as AnyObject,
                                                            "fan": "off" as AnyObject
            ])
    }

    func SetAwayModeOn() {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "climate",
                                                        service: "set_away_mode",
                                                        serviceData: [
                                                            "entity_id": self.ID as AnyObject,
                                                            "away_mode": "on" as AnyObject
            ])
    }

    func SetAwayModeOff() {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "climate",
                                                        service: "set_away_mode",
                                                        serviceData: [
                                                            "entity_id": self.ID as AnyObject,
                                                            "away_mode": "off" as AnyObject
            ])
    }

    func SetTemperature(_ newTemp: Float) {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "climate",
                                                        service: "set_temperature",
                                                        serviceData: [
                                                            "entity_id": self.ID as AnyObject,
                                                            "temperature": newTemp as AnyObject
            ])
    }

    func SetHumidity(_ newHumidity: Int) {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "climate",
                                                        service: "set_humidity",
                                                        serviceData: [
                                                            "entity_id": self.ID as AnyObject,
                                                            "humidity": newHumidity as AnyObject
            ])
    }

    func SetSwingMode(_ newSwingMode: String) {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "climate",
                                                        service: "set_swing_mode",
                                                        serviceData: [
                                                            "entity_id": self.ID as AnyObject,
                                                            "swing_mode": newSwingMode as AnyObject
            ])
    }

    func SetOperationMode(_ newOperationMode: String) {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "climate",
                                                        service: "set_operation_mode",
                                                        serviceData: [
                                                            "entity_id": self.ID as AnyObject,
                                                            "operation_mode": newOperationMode as AnyObject
            ])
    }

    func TurnAuxHeatOn() {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "climate",
                                                        service: "set_aux_heat",
                                                        serviceData: [
                                                            "entity_id": self.ID as AnyObject,
                                                            "aux_heat": "on" as AnyObject
            ])
    }

    func TurnAuxHeatOff() {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "climate",
                                                        service: "set_aux_heat",
                                                        serviceData: [
                                                            "entity_id": self.ID as AnyObject,
                                                            "aux_heat": "off" as AnyObject
            ])
    }

    override var ComponentIcon: String {
        return "mdi:nest-thermostat"
    }
}
