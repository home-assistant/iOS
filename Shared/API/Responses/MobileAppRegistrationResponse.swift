//
//  MobileAppRegistrationResponse.swift
//  Shared
//
//  Created by Robert Trencheny on 2/27/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

public class MobileAppRegistrationResponse: Mappable {
    public var CloudhookID: String?
    public var CloudhookURL: String?
    public var RemoteUIURL: String?
    public var WebhookID: String?
    public var WebhookSecret: String?

    public required init?(map: Map) {}

    public func mapping(map: Map) {
        CloudhookID         <- map["cloudhook_id"]
        CloudhookURL        <- map["cloudhook_id"]
        RemoteUIURL         <- map["remote_ui_url"]
        WebhookID           <- map["webhook_id"]
        WebhookSecret       <- map["secret"]
    }
}
