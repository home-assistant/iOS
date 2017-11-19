//
//  PushConfiguration.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 5/26/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class PushConfiguration: Mappable {
    var Categories: [PushCategory]?

    required init?(map: Map) {

    }

    func mapping(map: Map) {
        Categories        <- map["categories"]
    }
}

class PushCategory: Mappable {
    var Name: String = "Unknown"
    var Identifier: String = "unknown"

    var Actions: [PushAction]?

    required init?(map: Map) {

    }

    func mapping(map: Map) {
        Name        <- map["name"]
        Identifier  <- map["identifier"]
        Actions     <- map["actions"]
    }
}

class PushAction: Mappable {
    var Title: String = "Missing title"
    var Identifier: String = "missing"
    var AuthenticationRequired: Bool = false
    var Behavior: String = "default"
    var ActivationMode: String = "background"
    var Destructive: Bool = false
    var TextInputButtonTitle: String?
    var TextInputPlaceholder: String?

    required init?(map: Map) {

    }

    func mapping(map: Map) {
        Title                  <- map["title"]
        Identifier             <- map["identifier"]
        AuthenticationRequired <- map["authenticationRequired"]
        Behavior               <- map["behavior"]
        ActivationMode         <- map["activationMode"]
        Destructive            <- map["destructive"]
        TextInputButtonTitle   <- map["textInputButtonTitle"]
        TextInputPlaceholder   <- map["textInputPlaceholder"]
    }
}
