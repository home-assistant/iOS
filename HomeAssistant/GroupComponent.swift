//
//  GroupComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import RealmSwift

let isAllGroupTransform = TransformOf<Bool, String>(fromJSON: { (value: String?) -> Bool? in
    return value!.hasPrefix("group.all_")
}, toJSON: { (value: Bool?) -> String? in
    if let value = value {
        return String(value)
    }
    return nil
})

class Group: Entity {
    
    dynamic var IsAllGroup: Bool = false
    dynamic var View: Bool = false
    dynamic var Auto: Bool = false
    var Order = RealmOptional<Int>()
    var Entities = List<Entity>()
    dynamic var EntityIds = [String]()
    
    override func mapping(_ map: Map) {
        super.mapping(map)
        
        IsAllGroup    <- (map["entity_id"], isAllGroupTransform)
        View          <- map["attributes.view"]
        Auto          <- map["attributes.auto"]
        Order.value         <- map["attributes.order"]
        
        EntityIds     <- map["attributes.entity_id"]
        
        EntityIds.forEach { entityId in
            let returning = Entity()
            returning.ID = entityId
            self.Entities.append(returning)
        }
    }
    
    override var ComponentIcon: String {
        return "mdi:google-circles-communities"
    }
    
    override class func ignoredProperties() -> [String] {
        return ["EntityIds"]
    }
}
