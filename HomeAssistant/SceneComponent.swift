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
    
    var Entities = List<Entity>()
    dynamic var EntityIds = [String]()
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        EntityIds     <- map["attributes.entity_id"]
        
        EntityIds.forEach { entityId in
            self.Entities.append(Entity(id: entityId))
        }
    }
    
    override var ComponentIcon: String {
        return "mdi:google-pages"
    }
    
    override class func ignoredProperties() -> [String] {
        return ["EntityIds"]
    }
}