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
    dynamic var Speed: String?
    dynamic var SupportsSetSpeed: Bool = false
    dynamic var SupportsOscillate: Bool = false
    var SupportedFeatures: Int?

    override func mapping(map: Map) {
        super.mapping(map: map)

        Oscillating        <- map["attributes.oscillating"]
        Speed              <- map["attributes.speed"]

        SupportedFeatures  <- map["attributes.supported_features"]

        if let supported = self.SupportedFeatures {
            let features = FanSupportedFeatures(rawValue: supported)
            self.SupportsSetSpeed = features.contains(.SetSpeed)
            self.SupportsOscillate = features.contains(.Oscillate)
        }
    }

    override var ComponentIcon: String {
        return "mdi:fan"
    }

    override class func ignoredProperties() -> [String] {
        return ["SupportedFeatures", "SupportsSetSpeed", "SupportsOscillate"]
    }
}

struct FanSupportedFeatures: OptionSet {
    let rawValue: Int

    static let SetSpeed = FanSupportedFeatures(rawValue: 1)
    static let Oscillate = FanSupportedFeatures(rawValue: 2)
}
