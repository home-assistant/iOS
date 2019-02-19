//
//  Identify.swift
//  Shared
//
//  Created by Robert Trencheny on 2/18/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

public class IdentifyResponse: Mappable {
    public var Status: String?
    public var WebhookID: String?

    public required init?(map: Map) {

    }

    public func mapping(map: Map) {
        Status          <- map["status"]
        WebhookID       <- map["webhook_id"]
    }
}
