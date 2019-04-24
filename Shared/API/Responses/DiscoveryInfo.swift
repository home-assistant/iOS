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

public class DiscoveredHomeAssistant: Mappable {
    public var BaseURL: URL?
    public var LocationName: String = ""
    public var Version: String = ""
    public var UsesSSL: Bool = false

    // If false, this class was manually constructed
    public var Discovered: Bool = true

    public init() {}

    public convenience init(baseURL: URL, name: String, version: String, ssl: Bool) {
        self.init()
        self.BaseURL = baseURL
        self.LocationName = name
        self.Version = version
        self.UsesSSL = ssl
    }

    required public init?(map: Map) { }

    public func mapping(map: Map) {
        BaseURL             <- (map["base_url"], URLTransform())
        LocationName        <- map["location_name"]
        Version             <- map["version"]

        UsesSSL             <- (map["base_url"], usesSSL)
    }
}
