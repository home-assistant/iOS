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
    @objc dynamic var ID: String = UUID().uuidString
    @objc dynamic var Name: String = ""
    @objc dynamic var Position: Int = 0
    @objc dynamic var BackgroundColor: String = UIColor.randomColor().hexString()
    @objc dynamic var IconName: String = MaterialDesignIcons.allCases.randomElement()!.name
    @objc dynamic var IconColor: String = UIColor.randomColor().hexString()
    @objc dynamic var Text: String = "Action"
    @objc dynamic var TextColor: String = UIColor.randomColor().hexString()
    @objc dynamic var CreatedAt = Date()

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
    var uiShortcut: UIApplicationShortcutItem {
        return UIApplicationShortcutItem(type: self.ID, localizedTitle: self.Text)
    }
    #endif
}

public enum ActionSource: CaseIterable {
    case Watch
    case Widget
    case AppShortcut // UIApplicationShortcutItem
    case Preview

    var description: String {
        switch self {
        case .Watch:
            return "watch"
        case .Widget:
            return "widget"
        case .AppShortcut:
            return "appShortcut"
        case .Preview:
            return "preview"
        }
    }
}

extension UIColor {
    static func randomColor() -> UIColor {
        let random = {CGFloat(arc4random_uniform(255)) / 255.0}
        return UIColor(red: random(), green: random(), blue: random(), alpha: 1)
    }
}
