//
//  Services.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

public class ServicesResponse: Mappable {
    public var Domain: String = ""
    public var Services: [String: ServiceDefinition] = [:]

    required public init?(map: Map) { }

    public func mapping(map: Map) {
        Domain    <- map["domain"]
        Services  <- map["services"]
    }
}

public class ServiceDefinition: Mappable {
    public var Description: String?
    public var Fields: [String: ServiceField] = [:]

    required public init?(map: Map) { }

    public func mapping(map: Map) {
        Description  <- map["description"]
        Fields       <- map["fields"]
    }
}

public class ServiceField: Mappable {
    public var Description: String?
    public var Example: Any?
    public var Default: Any?
    public var Values: [Any]?

    required public init?(map: Map) {}

    public func mapping(map: Map) {
        Description  <- map["description"]
        Example      <- map["example"]
        Default      <- map["default"]
        Values       <- map["values"]
    }
}
