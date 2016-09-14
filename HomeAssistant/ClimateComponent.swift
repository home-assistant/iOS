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
    
    override func mapping(_ map: Map) {
        super.mapping(map)
        
        AuxHeat              <- (map["attributes.aux_heat"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        AwayMode             <- (map["attributes.away_mode"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        CurrentHumidity.value      <- map["attributes.current_humidity"]
        CurrentTemperature.value   <- map["attributes.current_temperature"]
        FanMode              <- map["attributes.fan_mode"]
        Humidity.value             <- map["attributes.humidity"]
        MaximumHumidity.value      <- map["attributes.max_humidity"]
        MaximumTemp.value          <- map["attributes.max_temp"]
        MinimumHumidity.value      <- map["attributes.min_humidity"]
        MinimumTemp.value          <- map["attributes.min_temp"]
        OperationMode        <- map["attributes.operation_mode"]
        SwingMode            <- (map["attributes.swing_mode"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        Temperature.value          <- map["attributes.temperature"]
        
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
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "climate", service: "set_fan_mode", serviceData: ["entity_id": self.ID as AnyObject, "fan": "on" as AnyObject])
    }
    
    func TurnFanOff() {
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "climate", service: "set_fan_mode", serviceData: ["entity_id": self.ID as AnyObject, "fan": "off" as AnyObject])
    }
    
    func SetAwayModeOn() {
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "climate", service: "set_away_mode", serviceData: ["entity_id": self.ID as AnyObject, "away_mode": "on" as AnyObject])
    }
    
    func SetAwayModeOff() {
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "climate", service: "set_away_mode", serviceData: ["entity_id": self.ID as AnyObject, "away_mode": "off" as AnyObject])
    }
    
    func SetTemperature(_ newTemp: Float) {
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "climate", service: "set_temperature", serviceData: ["entity_id": self.ID as AnyObject, "temperature": newTemp as AnyObject])
    }
    
    func SetHumidity(_ newHumidity: Int) {
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "climate", service: "set_humidity", serviceData: ["entity_id": self.ID as AnyObject, "humidity": newHumidity as AnyObject])
    }
    
    func SetSwingMode(_ newSwingMode: String) {
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "climate", service: "set_swing_mode", serviceData: ["entity_id": self.ID as AnyObject, "swing_mode": newSwingMode as AnyObject])
    }
    
    func SetOperationMode(_ newOperationMode: String) {
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "climate", service: "set_operation_mode", serviceData: ["entity_id": self.ID as AnyObject, "operation_mode": newOperationMode as AnyObject])
    }
    
    func TurnAuxHeatOn() {
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "climate", service: "set_aux_heat", serviceData: ["entity_id": self.ID as AnyObject, "aux_heat": "on" as AnyObject])
    }
    
    func TurnAuxHeatOff() {
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "climate", service: "set_aux_heat", serviceData: ["entity_id": self.ID as AnyObject, "aux_heat": "off" as AnyObject])
    }
    
    override var ComponentIcon: String {
        return "mdi:nest-thermostat"
    }
}
