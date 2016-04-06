//
//  APIStatus.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

let isOKTransform = TransformOf<Bool, String>(fromJSON: { (value: String?) -> Bool? in
    return Bool(value! == "API running.")
    }, toJSON: { (value: Bool?) -> String? in
        if let value = value {
            if value == true {
                return "API running."
            } else {
                return "API not running."
            }
        }
        return nil
})


class StatusResponse: Mappable {
    var Message: String?
    var IsOK: Bool?
    
    required init?(_ map: Map){
        
    }
    
    func mapping(map: Map) {
        Message <- map["message"]
        IsOK    <- (map["message"], isOKTransform)
    }
}