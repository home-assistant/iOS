//
//  DiscoveryInfo.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 9/18/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

let usesSSL = TransformOf<Bool, String>(fromJSON: { (value: String?) -> Bool? in
    if let url = value {
        return Bool(url.hasPrefix("https://"))
    }
    return false
}, toJSON: { (_: Bool?) -> String? in
    return nil
})

public class DiscoveryInfoResponse: Mappable {
    public var BaseURL: URL?
    public var BaseURLString: String = ""
    public var LocationName: String = ""
    public var RequiresPassword: Bool = false
    public var Version: String = ""
    public var UsesSSL: Bool = false

    required public init?(map: Map) {

    }

    public func mapping(map: Map) {
        BaseURL             <- (map["base_url"], URLTransform())
        BaseURLString       <- map["base_url"]
        LocationName        <- map["location_name"]
        RequiresPassword    <- map["requires_api_password"]
        Version             <- map["version"]

        UsesSSL             <- (map["base_url"], usesSSL)
    }
}
