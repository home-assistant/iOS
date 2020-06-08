//
//  Action.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 10/7/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import RealmSwift
import ObjectMapper
import Iconic

public class Action: Object, Mappable, NSCoding {
    @objc dynamic public var ID: String = UUID().uuidString
    @objc dynamic public var Name: String = ""
    @objc dynamic public var Position: Int = 0
    @objc dynamic public var BackgroundColor: String = UIColor.randomColor().hexString()
    @objc dynamic public var IconName: String = MaterialDesignIcons.allCases.randomElement()!.name
    @objc dynamic public var IconColor: String = UIColor.randomColor().hexString()
    @objc dynamic public var Text: String = "Action"
    @objc dynamic public var TextColor: String = UIColor.randomColor().hexString()
    @objc dynamic public var CreatedAt = Date()

    override public static func primaryKey() -> String? {
        return "ID"
    }

    required convenience public init?(map: Map) {
        self.init()
    }

    // NSCoding
    public func encode(with aCoder: NSCoder) {
        let jsonString = self.toJSONString() ?? ""
        aCoder.encode(jsonString, forKey: "jsonString")
    }

    required public convenience init?(coder aDecoder: NSCoder) {
        let jsonString = aDecoder.decodeObject(forKey: "jsonString") as? String
        self.init(JSONString: jsonString ?? "")
    }

    public func mapping(map: Map) {
        let realm = Realm.live()
        let isWriteRequired = realm.isInWriteTransaction == false
        isWriteRequired ? realm.beginWrite() : ()

        if map.mappingType == .toJSON {
            var id = self.ID
            id <- map["ID"]
        } else {
            ID <- map["ID"]
        }

        Name             <- map["Name"]
        Position         <- map["Position"]
        BackgroundColor  <- map["BackgroundColor"]
        IconName         <- map["IconName"]
        IconColor        <- map["IconColor"]
        Text             <- map["Text"]
        TextColor        <- map["TextColor"]
        CreatedAt        <- map["CreatedAt"]

        isWriteRequired ? try? realm.commitWrite() : ()
    }

    #if os(iOS)
    public var uiShortcut: UIApplicationShortcutItem {
        return UIApplicationShortcutItem(type: self.ID, localizedTitle: self.Text,
                                         localizedSubtitle: nil, icon: nil,
                                         userInfo: ["name": self.Name as NSSecureCoding])
    }
    #endif
    
    public var exampleTrigger: String {
        let data = HomeAssistantAPI.actionEvent(actionID: ID, actionName: Name, source: .Preview)
        let eventDataStrings = data.eventData.map { $0 + ": " + $1 }.sorted()
        let sourceStrings = HomeAssistantAPI.ActionSource.allCases.map { $0.description }.sorted()
        
        let indentation = "\n    "
        
        return """
        - platform: event
          event_type: \(data.eventType)
          event_data:
            # source may be one of:
            # - \(sourceStrings.joined(separator: indentation + "# - "))
            \(eventDataStrings.joined(separator: indentation))
        """
    }
}

extension UIColor {
    public static func randomColor() -> UIColor {
        let random = {CGFloat(arc4random_uniform(255)) / 255.0}
        return UIColor(red: random(), green: random(), blue: random(), alpha: 1)
    }
}
