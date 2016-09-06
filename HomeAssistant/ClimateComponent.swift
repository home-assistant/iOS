//
//  ClimateComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 9/3/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import RealmSwift
import Realm

class Climate: Entity {
    
    dynamic var AuxHeat = false
    dynamic var AwayMode = false
    var CurrentHumidity = RealmOptional<Int>()
    var CurrentTemperature = RealmOptional<Float>()
    let FanList = List<StringObject>()
    dynamic var FanMode: String? = nil
    var Humidity = RealmOptional<Int>()
    var MaximumHumidity = RealmOptional<Int>()
    var MaximumTemp = RealmOptional<Float>()
    var MinimumHumidity = RealmOptional<Int>()
    var MinimumTemp = RealmOptional<Float>()
    let OperationList = List<StringObject>()
    dynamic var OperationMode: String? = nil
    let SwingList = List<StringObject>()
    dynamic var SwingMode = false
    var Temperature = RealmOptional<Float>()
    
    // MARK: - Requireds
    required init() { super.init() }
    required init?(_ map: Map) { super.init() }
    required init(value: AnyObject, schema: RLMSchema) { super.init(value: value, schema: schema) }
    required init(realm: RLMRealm, schema: RLMObjectSchema) { super.init(realm: realm, schema: schema) }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        AuxHeat              <- (map["attributes.aux_heat"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        AwayMode             <- (map["attributes.away_mode"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        CurrentHumidity      <- map["attributes.current_humidity"]
        CurrentTemperature   <- map["attributes.current_temperature"]
        FanMode              <- map["attributes.fan_mode"]
        Humidity             <- map["attributes.humidity"]
        MaximumHumidity      <- map["attributes.max_humidity"]
        MaximumTemp          <- map["attributes.max_temp"]
        MinimumHumidity      <- map["attributes.min_humidity"]
        MinimumTemp          <- map["attributes.min_temp"]
        OperationMode        <- map["attributes.operation_mode"]
        SwingMode            <- (map["attributes.swing_mode"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        Temperature          <- map["attributes.temperature"]
        
        var FanList: [String]? = nil
        FanList              <- map["attributes.fan_list"]
        FanList?.forEach { option in
            let value = StringObject()
            value.value = option
            self.FanList.append(value)
        }
        
        var OperationList: [String]? = nil
        OperationList        <- map["attributes.operation_list"]
        OperationList?.forEach { option in
            let value = StringObject()
            value.value = option
            self.OperationList.append(value)
        }
        
        var SwingList: [String]? = nil
        SwingList            <- map["attributes.swing_list"]
        SwingList?.forEach { option in
            let value = StringObject()
            value.value = option
            self.SwingList.append(value)
        }
    }
    
    func TurnFanOn() {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_fan_mode", serviceData: ["entity_id": self.ID, "fan": "on"])
    }
    
    func TurnFanOff() {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_fan_mode", serviceData: ["entity_id": self.ID, "fan": "off"])
    }
    
    func SetAwayModeOn() {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_away_mode", serviceData: ["entity_id": self.ID, "away_mode": "on"])
    }
    
    func SetAwayModeOff() {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_away_mode", serviceData: ["entity_id": self.ID, "away_mode": "off"])
    }
    
    func SetTemperature(newTemp: Float) {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_temperature", serviceData: ["entity_id": self.ID, "temperature": newTemp])
    }
    
    func SetHumidity(newHumidity: Int) {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_humidity", serviceData: ["entity_id": self.ID, "humidity": newHumidity])
    }
    
    func SetSwingMode(newSwingMode: String) {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_swing_mode", serviceData: ["entity_id": self.ID, "swing_mode": newSwingMode])
    }
    
    func SetOperationMode(newOperationMode: String) {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_operation_mode", serviceData: ["entity_id": self.ID, "operation_mode": newOperationMode])
    }
    
    func TurnAuxHeatOn() {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_aux_heat", serviceData: ["entity_id": self.ID, "aux_heat": "on"])
    }
    
    func TurnAuxHeatOff() {
        HomeAssistantAPI.sharedInstance.CallService("climate", service: "set_aux_heat", serviceData: ["entity_id": self.ID, "aux_heat": "off"])
    }
    
    override var ComponentIcon: String {
        return "mdi:nest-thermostat"
    }
}