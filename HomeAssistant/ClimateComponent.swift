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
    
    var AuxHeat: Bool?
    var AwayMode: Bool?
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
    var SwingMode: Bool?
    var Temperature: Float?
    var UnitOfMeasurement: String?
    
    required init?(_ map: Map) {
        super.init(map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        AuxHeat              <- (map["attributes.aux_heat"], onOffStateTransform)
        AwayMode             <- (map["attributes.away_mode"], onOffStateTransform)
        CurrentHumidity      <- map["attributes.current_humidity"]
        CurrentTemperature   <- map["attributes.current_temperature"]
        FanList              <- map["attributes.fan_list"]
        FanMode              <- map["attributes.fan_mode"]
        Humidity             <- map["attributes.humidity"]
        MaximumHumidity      <- map["attributes.max_humidity"]
        MaximumTemp          <- map["attributes.max_temp"]
        MinimumHumidity      <- map["attributes.min_humidity"]
        MinimumTemp          <- map["attributes.min_temp"]
        OperationList        <- map["attributes.operation_list"]
        OperationMode        <- map["attributes.operation_mode"]
        SwingList            <- map["attributes.swing_list"]
        SwingMode            <- (map["attributes.swing_mode"], onOffStateTransform)
        Temperature          <- map["attributes.temperature"]
        UnitOfMeasurement    <- map["attributes.unit_of_measurement"]
    }
    func turnFanOn() {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_fan_mode", serviceData: ["entity_id": self.ID, "fan": "on"])
    }
    func turnFanOff() {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_fan_mode", serviceData: ["entity_id": self.ID, "fan": "off"])
    }
    func setAwayModeOn() {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_away_mode", serviceData: ["entity_id": self.ID, "away_mode": "on"])
    }
    func setAwayModeOff() {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_away_mode", serviceData: ["entity_id": self.ID, "away_mode": "off"])
    }
    func setTemperature(newTemp: Float) {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_temperature", serviceData: ["entity_id": self.ID, "temperature": newTemp])
    }
    
    func setHumidity(newHumidity: Int) {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_humidity", serviceData: ["entity_id": self.ID, "humidity": newHumidity])
    }
    
    func setSwingMode(newSwingMode: String) {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_swing_mode", serviceData: ["entity_id": self.ID, "swing_mode": newSwingMode])
    }
    
    func setOperationMode(newOperationMode: String) {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_operation_mode", serviceData: ["entity_id": self.ID, "operation_mode": newOperationMode])
    }
    
    func turnAuxHeatOn() {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_aux_heat", serviceData: ["entity_id": self.ID, "aux_heat": "on"])
    }
    
    func turnAuxHeatOff() {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_aux_heat", serviceData: ["entity_id": self.ID, "aux_heat": "off"])
    }
    
    override var ComponentIcon: String {
        return "mdi:nest-thermostat"
    }
}