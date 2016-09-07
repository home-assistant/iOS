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

class Light: SwitchableEntity {
    
    var Brightness = RealmOptional<Float>()
    var ColorTemp = RealmOptional<Float>()
    dynamic var RGBColor: [Int]?
    
    override func mapping(_ map: Map) {
        super.mapping(map)
        
        Brightness   <- map["attributes.brightness"]
        ColorTemp    <- map["attributes.color_temp"]
        RGBColor     <- map["attributes.rgb_color"]
    }
    
    override func EntityColor() -> UIColor {
        if self.IsOn! {
            if self.Attributes["rgb_color"] != nil {
                let rgb = self.Attributes["rgb_color"]!
                let red = CGFloat((rgb[0]).doubleValue/255.0)
                let green = CGFloat(rgb[1].doubleValue/255.0)
                let blue = CGFloat(rgb[2].doubleValue/255.0)
                return UIColor.init(red: red, green: green, blue: blue, alpha: 1)
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

    override class func ignoredProperties() -> [String] {
        return ["RGBColor"]
    }
}
