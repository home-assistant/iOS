//
//  StateChangedSSE.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/8/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class StateChangedEvent: SSEEvent {
    var NewState: Entity?
    var OldState: Entity?
    var EntityID: String?
    var EntityDomain: String?

    override func mapping(map: Map) {
        super.mapping(map: map)
        NewState  <- map["data.new_state"]
        OldState  <- map["data.old_state"]
        EntityID  <- map["data.entity_id"]
        EntityDomain <- (map["data.entity_id"], EntityIDToDomainTransform())
    }
}

open class EntityIDToDomainTransform: TransformType {
    public typealias Object = String
    public typealias JSON = String

    public init() {}

    public func transformFromJSON(_ value: Any?) -> String? {
        if let entityId = value as? String {
            return entityId.components(separatedBy: ".")[0]
        }
        return nil
    }

    open func transformToJSON(_ value: String?) -> String? {
        return nil
    }
}
