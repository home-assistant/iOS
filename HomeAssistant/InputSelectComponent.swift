//
//  InputSelectComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import RealmSwift

class InputSelect: Entity {
    
    let Options = List<StringObject>()
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        var Options: [String]? = nil
        Options          <- map["attributes.options"]
        Options?.forEach { option in
            let value = StringObject()
            value.value = option
            self.Options.append(value)
        }
    }
    
    override var ComponentIcon: String {
        return "mdi:format-list-bulleted"
    }
}