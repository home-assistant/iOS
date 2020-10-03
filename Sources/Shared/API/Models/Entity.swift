//
//  Entity.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import CoreGraphics
import ObjectMapper

public class Entity: StaticMappable {
    @objc public dynamic var ID: String = ""
    @objc public dynamic var State: String = ""
    @objc public dynamic var Attributes: [String: Any] {
        get {
            guard let dictionaryData = attributesData else {
                return [String: Any]()
            }
            do {
                let dict = try JSONSerialization.jsonObject(with: dictionaryData, options: []) as? [String: Any]
                return dict!
            } catch {
                return [String: Any]()
            }
        }

        set {
            do {
                let data = try JSONSerialization.data(withJSONObject: newValue, options: [])
                attributesData = data
            } catch {
                attributesData = nil
            }
        }
    }
    @objc fileprivate dynamic var attributesData: Data?
    @objc public dynamic var FriendlyName: String?
    @objc public dynamic var Hidden = false
    @objc public dynamic var Icon: String?
    @objc public dynamic var MobileIcon: String?
    @objc public dynamic var Picture: String?
    @objc public dynamic var LastChanged: Date?
    @objc public dynamic var LastUpdated: Date?
    //    let Groups = LinkingObjects(fromType: Group.self, property: "Entities")

    // Z-Wave properties
    @objc public dynamic var Location: String?
    @objc public dynamic var NodeID: String?

    public func mapping(map: Map) {
        ID                <- map["entity_id"]
        State             <- map["state"]
        Attributes        <- map["attributes"]
        FriendlyName      <- map["attributes.friendly_name"]
        Hidden            <- map["attributes.hidden"]
        Icon              <- map["attributes.icon"]
        MobileIcon        <- map["attributes.mobile_icon"]
        Picture           <- map["attributes.entity_picture"]
        LastChanged       <- (map["last_changed"], HomeAssistantTimestampTransform())
        LastUpdated       <- (map["last_updated"], HomeAssistantTimestampTransform())

        // Z-Wave properties
        NodeID            <- map["attributes.node_id"]
        Location          <- map["attributes.location"]
    }

    public var Domain: String {
        return self.ID.components(separatedBy: ".")[0]
    }

    public class func objectForMapping(map: Map) -> BaseMappable? {
        guard let entityId: String = map["entity_id"].value() else {
            return nil
        }

        let entityType = entityId.components(separatedBy: ".")[0]
        switch entityType {
        case "zone":
            return Zone()
        case "scene":
            return Scene()
        default:
            return Entity()
        }
    }
}
