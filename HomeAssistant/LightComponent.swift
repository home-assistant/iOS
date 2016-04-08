//
//  LightComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Light: Entity {
    
    var Brightness: Float?
    var ColorTemp: Float?
    var RGBColor: [Int]?
    
    required init?(_ map: Map) {
        super.init(value: map)
    }
    
    required init() {
        super.init()
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        Brightness   <- map["attributes.brightness"]
        ColorTemp    <- map["attributes.color_temp"]
        RGBColor     <- map["attributes.rgb_color"]
    }
}