//
//  SceneComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Scene: Entity {
    
    var EntityIds: [String]?
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        EntityIds     <- map["attributes.entity_id"]
    }
    
    override class func ignoredProperties() -> [String] {
        return ["EntityIds"]
    }
}