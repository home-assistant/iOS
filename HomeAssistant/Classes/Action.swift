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
import UIColor_Hex_Swift

public class Action: Object, Mappable, NSCoding {
    @objc dynamic var Name: String = ""
    @objc dynamic var Position: Int = 0
    @objc dynamic var BackgroundColor: String = "FC2D49"
    @objc dynamic var IconName: String = "upload"
    @objc dynamic var IconColor: String = "FFFFFF"
    @objc dynamic var Text: String = "Action"
    @objc dynamic var TextColor: String = "FFFFFF"
    @objc dynamic var CreatedAt = Date()

    override public static func primaryKey() -> String? {
        return "Name"
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

        print("HELLO")

        if map.mappingType == .toJSON {
            var name = self.Name
            name <- map["Name"]
        } else {
            Name <- map["Name"]
        }

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
