//
//  DiscoveryInfo.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 9/18/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import PromiseKit

public class DiscoveredHomeAssistant: Mappable {
    public var BaseURL: URL?
    public var LocationName: String = ""
    public var Version: String = ""

    // If false, this class was manually constructed
    public var Discovered: Bool = true

    public var AnnouncedFrom: [String] = []

    public init() {}

    required public init?(map: Map) { }

    public convenience init(baseURL: URL, name: String, version: String, announcedFrom: [String] = []) {
        self.init()
        self.BaseURL = baseURL
        self.LocationName = name
        self.Version = version
        self.AnnouncedFrom = announcedFrom
        self.Discovered = false
    }

    public func mapping(map: Map) {
        BaseURL             <- (map["base_url"], URLTransform())
        LocationName        <- map["location_name"]
        Version             <- map["version"]
    }
}
