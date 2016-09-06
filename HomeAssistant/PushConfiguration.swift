//
//  PushConfiguration.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 5/26/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class PushCategory: Mappable {
    var Name: String?
    var Identifier: String?
    
    var Actions: [PushAction]?
    
    required init?(_ map: Map){
        
    }
    
    func mapping(_ map: Map) {
        Name        <- map["name"]
        Identifier  <- map["identifier"]
        Actions     <- map["actions"]
    }
}

class PushAction: Mappable {
    var Title: String?
    var Identifier: String?
    var AuthenticationRequired: Bool?
    var Behavior: String?
    var ActivationMode: String?
    var Destructive: Bool?
    var Context: String?
    var Parameters: [String:AnyObject]?
    
    required init?(_ map: Map){
        
    }
    
    func mapping(_ map: Map) {
        Title                  <- map["title"]
        Identifier             <- map["identifier"]
        AuthenticationRequired <- map["authenticationRequired"]
        Behavior               <- map["behavior"]
        ActivationMode         <- map["activationMode"]
        Destructive            <- map["destructive"]
        Context                <- map["context"]
        Parameters             <- map["parameters"]
    }
}
