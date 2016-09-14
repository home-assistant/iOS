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
        
        Brightness.value   <- map["attributes.brightness"]
        ColorTemp.value    <- map["attributes.color_temp"]
        RGBColor     <- map["attributes.rgb_color"]
    }
    
    override func EntityColor() -> UIColor {
        if self.IsOn! {
            if self.RGBColor != nil {
                let rgb = self.RGBColor
                let red = CGFloat(rgb![0]/255)
                let green = CGFloat(rgb![1]/255)
                let blue = CGFloat(rgb![2]/255)
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
