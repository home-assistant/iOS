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
    var UnitOfMeasurement: String?
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        AwayMode              <- (map["attributes.away_mode"], onOffStateTransform)
        CurrentTemperature    <- map["attributes.current_temperature"]
        Fan                   <- (map["attributes.fan"], onOffStateTransform)
        Temperature           <- map["attributes.temperature"]
        MaximumTemperature    <- map["attributes.max_temp"]
        MinimumTemperature    <- map["attributes.min_temp"]
        TargetTemperatureHigh <- map["attributes.target_temp_high"]
        TargetTemperatureLow  <- map["attributes.target_temp_low"]
        UnitOfMeasurement     <- map["attributes.unit_of_measurement"]
    }
    func turnFanOn() {
        HomeAssistantAPI.sharedInstance.CallService("thermostat", service: "set_fan_mode", serviceData: ["entity_id": self.ID, "fan": "on"])
    }
    func turnFanOff() {
        HomeAssistantAPI.sharedInstance.CallService("thermostat", service: "set_fan_mode", serviceData: ["entity_id": self.ID, "fan": "off"])
    }
    func setAwayModeOn() {
        HomeAssistantAPI.sharedInstance.CallService("thermostat", service: "set_away_mode", serviceData: ["entity_id": self.ID, "away_mode": "on"])
    }
    func setAwayModeOff() {
        HomeAssistantAPI.sharedInstance.CallService("thermostat", service: "set_away_mode", serviceData: ["entity_id": self.ID, "away_mode": "off"])
    }
    func setTemperature(newTemp: Float) {
        HomeAssistantAPI.sharedInstance.CallService("thermostat", service: "set_temperature", serviceData: ["entity_id": self.ID, "temperature": newTemp])
    }
    
    override var ComponentIcon: String {
        return "mdi:nest-thermostat"
    }
}