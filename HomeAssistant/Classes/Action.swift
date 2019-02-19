//
//  Action.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 10/7/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import RealmSwift
import ObjectMapper

public class Action: Object, Mappable, NSCoding {
    @objc dynamic var ID: String = UUID().uuidString
    @objc dynamic var Name: String = ""
    @objc dynamic var Position: Int = 0
    @objc dynamic var BackgroundColor: String = "FC2D49"
    @objc dynamic var IconName: String = "upload"
    @objc dynamic var IconColor: String = "FFFFFF"
    @objc dynamic var Text: String = "Action"
    @objc dynamic var TextColor: String = "FFFFFF"
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
}

public enum ActionSource: CaseIterable {
    case Watch
    case Widget

    var description: String {
        switch self {
        case .Watch:
            return "watch"
        case .Widget:
            return "widget"
        }
    }
}
