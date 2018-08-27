//
//  ThermostatComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Thermostat: Entity {

    var AwayMode: Bool?
    var CurrentTemperature: Int?
    var Fan: Bool?
    var MaximumTemperature: Int?
    var MinimumTemperature: Int?
    var TargetTemperatureHigh: Int?
    var TargetTemperatureLow: Int?
    var Temperature: Int?

    override func mapping(map: Map) {
        super.mapping(map: map)

        AwayMode              <- (map["attributes.away_mode"],
                                  ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        CurrentTemperature    <- map["attributes.current_temperature"]
        Fan                   <- (map["attributes.fan"],
                                  ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        Temperature           <- map["attributes.temperature"]
        MaximumTemperature    <- map["attributes.max_temp"]
        MinimumTemperature    <- map["attributes.min_temp"]
        TargetTemperatureHigh <- map["attributes.target_temp_high"]
        TargetTemperatureLow  <- map["attributes.target_temp_low"]
    }
    func turnFanOn() {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "thermostat",
                                                             service: "set_fan_mode",
                                                             serviceData: [
                                                                "entity_id": self.ID as AnyObject,
                                                                "fan": "on" as AnyObject
            ])
    }
    func turnFanOff() {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "thermostat",
                                                             service: "set_fan_mode",
                                                             serviceData: [
                                                                "entity_id": self.ID as AnyObject,
                                                                "fan": "off" as AnyObject
            ])
    }
    func setAwayModeOn() {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "thermostat",
                                                             service: "set_away_mode",
                                                             serviceData: [
                                                                "entity_id": self.ID as AnyObject,
                                                                "away_mode": "on" as AnyObject
            ])
    }
    func setAwayModeOff() {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "thermostat",
                                                             service: "set_away_mode",
                                                             serviceData: [
                                                                "entity_id": self.ID as AnyObject,
                                                                "away_mode": "off" as AnyObject
            ])
    }
    func setTemperature(_ newTemp: Float) {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "thermostat",
                                                             service: "set_temperature",
                                                             serviceData: [
                                                                "entity_id": self.ID as AnyObject,
                                                                "temperature": newTemp as AnyObject
            ])
    }

    override var ComponentIcon: String {
        return "mdi:nest-thermostat"
    }
}
