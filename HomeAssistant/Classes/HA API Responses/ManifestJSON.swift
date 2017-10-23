//
//  ManifestJSON.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 10/22/17.
//  Copyright © 2017 Robbie Trencheny. All rights reserved.
//

import Foundation
import CoreLocation
import ObjectMapper

class ManifestJSONIcon: Mappable {
    var Sizes: String?
    var Source: String?
    var IconType: String?
    
    required init?(map: Map) {
        
    }
    
    func mapping(map: Map) {
        Sizes      <- map["sizes"]
        Source     <- map["src"]
        IconType       <- map["type"]
    }
}


class ManifestJSON: Mappable {
    var BackgroundColor: String?
    var Description: String?
    var Direction: String?
    var Display: String?
    var GCMSenderID: String?
    var Icons: [ManifestJSONIcon]?
    var Language: String?
    var Name: String?
    var ShortName: String?
    var StartURL: String?
    var ThemeColor: String?

    required init?(map: Map) { }

    func mapping(map: Map) {
        BackgroundColor <- map["background_color"]
        Description     <- map["description"]
        Direction       <- map["dir"]
        Display         <- map["display"]
        GCMSenderID     <- map["gcm_sender_id"]
        Icons           <- map["icons"]
        Language        <- map["lang"]
        Name            <- map["name"]
        ShortName       <- map["short_name"]
        StartURL        <- map["start_url"]
        ThemeColor      <- map["theme_color"]
    }
}
