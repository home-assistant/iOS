//
//  WatchComplication.swift
//  Shared
//
//  Created by Robert Trencheny on 9/26/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import RealmSwift

public class WatchComplication: Object {
    @objc dynamic var Family: String?
    @objc dynamic var Template: String?
    @objc dynamic var Data: [String: Any] {
        get {
            guard let dictionaryData = complicationData else {
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
                complicationData = data
            } catch {
                complicationData = nil
            }
        }
    }
    @objc fileprivate dynamic var complicationData: Data?
    @objc dynamic var RenderedData: [String: Any] = [:]
    @objc dynamic var CreatedAt = Date()

    override public static func primaryKey() -> String? {
        return "Family"
    }

    override public static func ignoredProperties() -> [String] {
        return ["RenderedData"]
    }

    var group: ComplicationGroup? {
        if let groupStr = self.Family {
            return ComplicationGroup(rawValue: groupStr)
        }
        return nil
    }

    var template: ComplicationTemplate? {
        if let templateStr = self.Template {
            return ComplicationTemplate(rawValue: templateStr)
        }
        return nil
    }
}
