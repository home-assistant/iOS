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
            return "API not running or an error was encountered."
        }
    }
    return nil
})

public class StatusResponse: Mappable {
    var Result: String?
    var Message: String?
    var IsOK: Bool?

    required public init?(map: Map) {

    }

    public func mapping(map: Map) {
        Result  <- map["result"]
        Message <- map["message"]
        IsOK    <- (map["message"], isOKTransform)
    }
}
