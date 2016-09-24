//
//  AutomationComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 9/14/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Fan: Entity {
    
    dynamic var Oscillating = false
    dynamic var Speed: String? = nil
    dynamic var SupportsSetSpeed: Bool = false
    dynamic var SupportsOscillate: Bool = false
    
    override func mapping(map: Map) {
        super.mapping(map: map)
        
        Oscillating <- map["attributes.oscillating"]
        Speed       <- map["attributes.speed"]
        
        let features = FanSupportedFeatures(rawValue: map["attributes.supported_features"].value()!)
        self.SupportsSetSpeed = features.contains(.SetSpeed)
        self.SupportsOscillate = features.contains(.Oscillate)
    }
    
    override var ComponentIcon: String {
        return "mdi:fan"
    }
    
    override class func ignoredProperties() -> [String] {
        return ["SupportsSetSpeed", "SupportsOscillate"]
    }
}

struct FanSupportedFeatures: OptionSet {
    let rawValue: Int
    
    static let SetSpeed = FanSupportedFeatures(rawValue: 1)
    static let Oscillate = FanSupportedFeatures(rawValue: 2)
}
