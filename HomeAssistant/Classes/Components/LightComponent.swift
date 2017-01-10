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

    dynamic var IsOn: Bool = false
    var Brightness = RealmOptional<Float>()
    var ColorTemp = RealmOptional<Float>()
    dynamic var RGBColor: [Float]?
    dynamic var XYColor: [Float]?
    dynamic var SupportsBrightness: Bool = false
    dynamic var SupportsColorTemp: Bool = false
    dynamic var SupportsEffect: Bool = false
    dynamic var SupportsFlash: Bool = false
    dynamic var SupportsRGBColor: Bool = false
    dynamic var SupportsTransition: Bool = false
    dynamic var SupportsXYColor: Bool = false
    var SupportedFeatures: Int?

    override func mapping(map: Map) {
        super.mapping(map: map)

        IsOn               <- (map["state"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        Brightness.value   <- map["attributes.brightness"]
        ColorTemp.value    <- map["attributes.color_temp"]
        RGBColor           <- map["attributes.rgb_color"]
        XYColor            <- map["attributes.xy_color"]
        SupportedFeatures  <- map["attributes.supported_features"]

        if let supported = self.SupportedFeatures {
            let features = LightSupportedFeatures(rawValue: supported)
            self.SupportsBrightness = features.contains(.Brightness)
            self.SupportsColorTemp = features.contains(.ColorTemp)
            self.SupportsEffect = features.contains(.Effect)
            self.SupportsFlash = features.contains(.Flash)
            self.SupportsRGBColor = features.contains(.RGBColor)
            self.SupportsTransition = features.contains(.Transition)
            self.SupportsXYColor = features.contains(.XYColor)
        }
    }

     override var EntityColor: UIColor {
        if self.IsOn {
            if self.RGBColor != nil {
                let rgb = self.RGBColor
                let red = CGFloat(rgb![0]/255.0)
                let green = CGFloat(rgb![1]/255.0)
                let blue = CGFloat(rgb![2]/255.0)
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
        return ["SupportedFeatures", "SupportsBrightness", "SupportsColorTemp", "SupportsEffect", "SupportsFlash",
                "SupportsRGBColor", "SupportsTransition", "SupportsXYColor", "RGBColor", "XYColor"]
    }
}

struct LightSupportedFeatures: OptionSet {
    let rawValue: Int

    static let Brightness = LightSupportedFeatures(rawValue: 1)
    static let ColorTemp = LightSupportedFeatures(rawValue: 2)
    static let Effect = LightSupportedFeatures(rawValue: 4)
    static let Flash = LightSupportedFeatures(rawValue: 8)
    static let RGBColor = LightSupportedFeatures(rawValue: 16)
    static let Transition = LightSupportedFeatures(rawValue: 32)
    static let XYColor = LightSupportedFeatures(rawValue: 64)
}
