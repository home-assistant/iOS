//
//  PushConfiguration.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 5/26/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

public class PushConfiguration: Mappable {
    public var Categories: [PushCategory]?

    public required init?(map: Map) {

    }

    public func mapping(map: Map) {
        Categories        <- map["categories"]
    }
}

public class PushCategory: Mappable {
    public var Name: String = "Unknown"
    public var Identifier: String = "unknown"

    public var Actions: [PushAction]?

    public required init?(map: Map) {

    }

    public func mapping(map: Map) {
        Name        <- map["name"]
        Identifier  <- map["identifier"]
        Actions     <- map["actions"]
    }
}

public class PushAction: Mappable {
    public var Title: String = "Missing title"
    public var Identifier: String = "missing"
    public var AuthenticationRequired: Bool = false
    public var Behavior: String = "default"
    public var ActivationMode: String = "background"
    public var Destructive: Bool = false
    public var TextInputButtonTitle: String?
    public var TextInputPlaceholder: String?

    public required init?(map: Map) {
    }

    public func mapping(map: Map) {
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
