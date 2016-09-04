//
//  SceneComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import RealmSwift

class Scene: Entity {
    
    dynamic var EntityIds: [String] = [String]()
    let StoredEntityIds = List<StringObject>()
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        EntityIds     <- map["attributes.entity_id"]
        
        var StoredEntityIds: [String]? = nil
        StoredEntityIds     <- map["attributes.entity_id"]
        StoredEntityIds?.forEach { option in
            let value = StringObject()
            value.value = option
            self.StoredEntityIds.append(value)
        }
    }
    
    override var ComponentIcon: String {
        return "mdi:google-pages"
    }
    
    override class func ignoredProperties() -> [String] {
        return ["EntityIds"]
    }
}