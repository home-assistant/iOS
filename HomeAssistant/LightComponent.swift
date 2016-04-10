//
//  LightComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import RealmSwift

class Light: Entity {
    
    var Brightness = RealmOptional<Float>()
    var ColorTemp = RealmOptional<Float>()
    dynamic var RGBColor: [Int]?
    
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
    
    override class func ignoredProperties() -> [String] {
        return ["RGBColor"]
    }
}