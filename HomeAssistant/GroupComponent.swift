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
    return Bool((String(value!).rangeOfString("group.all_") != nil))
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
        Order         <- map["attributes.order"]
        
        EntityIds     <- map["attributes.entity_id"]
        
        EntityIds.forEach { entityId in
            self.Entities.append(Entity(id: entityId))
        }
    }
    
    override var ComponentIcon: String {
        return "mdi:google-circles-communities"
    }
    
    override class func ignoredProperties() -> [String] {
        return ["EntityIds"]
    }
}
