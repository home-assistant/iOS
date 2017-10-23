//
//  GroupComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

let isAllGroupTransform = TransformOf<Bool, String>(fromJSON: { (value: String?) -> Bool? in
    return value!.hasPrefix("group.all_")
}, toJSON: { (value: Bool?) -> String? in
    if let value = value {
        return String(value)
    }
    return nil
})

class Group: Entity {

    @objc dynamic var IsAllGroup: Bool = false
    @objc dynamic var View: Bool = false
    @objc dynamic var Auto: Bool = false
    var Order: Int?
    var Entities: [String]?
    @objc dynamic var EntityIds = [String]()

    override func mapping(map: Map) {
        super.mapping(map: map)

        IsAllGroup    <- (map["entity_id"], isAllGroupTransform)
        View          <- map["attributes.view"]
        Auto          <- map["attributes.auto"]
        Order         <- map["attributes.order"]

        EntityIds     <- map["attributes.entity_id"]
    }

    override var ComponentIcon: String {
        return "mdi:google-circles-communities"
    }
}
