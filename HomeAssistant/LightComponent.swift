//
//  LightComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Light: SwitchableEntity {
    
    var Brightness: Float?
    var ColorTemp: Float?
    var RGBColor: [Int]?
    
    required init?(_ map: Map) {
        super.init(map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        Brightness   <- map["attributes.brightness"]
        ColorTemp    <- map["attributes.color_temp"]
        RGBColor     <- map["attributes.rgb_color"]
    }
    
    override func EntityColor() -> UIColor {
        if self.State == "on" {
            if let rgb = self.RGBColor {
                return UIColor.init(red: CGFloat(rgb[0]), green: CGFloat(rgb[1]), blue: CGFloat(rgb[2]), alpha: 1)
            } else {
                return colorWithHexString("#DCC91F", alpha: 1)
            }
        } else {
            return self.DefaultEntityUIColor
        }
    }
    
    override var ComponentIcon: String {
        return "mdi:lightbulb"
    }
}