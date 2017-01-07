//
//  Beacons.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 7/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import CoreLocation
import ObjectMapper

class Beacon: Mappable {
    var Name: String?
    var Zone: String?
    var UUID: String?
    var Major: Int?
    var Minor: Int?
    var Radius: Int?

    required init?(map: Map) {

    }

    func mapping(map: Map) {
        Name        <- map["name"]
        Zone        <- map["zone"]
        UUID        <- map["uuid"]
        Major       <- map["major"]
        Minor       <- map["minor"]
        Radius      <- map["radius"]
    }
}
