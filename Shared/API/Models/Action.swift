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

public final class Action: Object, Mappable, NSCoding, UpdatableModel {
    @objc dynamic public var ID: String = UUID().uuidString
    @objc dynamic public var Name: String = ""
    @objc dynamic public var Text: String = ""
    @objc dynamic public var IconName: String = MaterialDesignIcons.allCases.randomElement()!.name
    @objc dynamic public var BackgroundColor: String
    @objc dynamic public var IconColor: String
    @objc dynamic public var TextColor: String
    @objc dynamic public var Position: Int = 0
    @objc dynamic public var CreatedAt = Date()
    @objc dynamic public var Scene: RLMScene?
    @objc dynamic public var isServerControlled: Bool = false

    override public static func primaryKey() -> String? {
        return "ID"
    }

    public required init() {
        let background = UIColor.randomBackgroundColor()
        BackgroundColor = background.hexString()
        if background.isLight {
            TextColor = UIColor.black.hexString()
            IconColor = UIColor.black.hexString()
        } else {
            TextColor = UIColor.white.hexString()
            IconColor = UIColor.white.hexString()
        }
    }

    required convenience public init?(map: Map) {
        self.init()
    }

    public func canConfigure(_ keyPath: PartialKeyPath<Action>) -> Bool {
        if isServerControlled {
            return false
        }

        switch keyPath {
        case \Action.BackgroundColor:
            return Scene == nil || Scene?.scene.backgroundColor == nil
        case \Action.TextColor:
            return Scene == nil || Scene?.scene.textColor == nil
        case \Action.IconColor:
            return Scene == nil || Scene?.scene.iconColor == nil
        case \Action.IconName,
             \Action.Name,
             \Action.Text:
            return Scene == nil
        default:
            return true
        }
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

    static func didUpdate(objects: [Action]) {
        for (idx, object) in objects.enumerated() {
            object.Position = -10_000 + idx
        }
    }

    static var updateEligiblePredicate: NSPredicate {
        .init(format: "isServerControlled == YES")
    }

    public func update(with object: MobileAppConfigAction, using realm: Realm) {
        if self.realm == nil {
            ID = object.name
            Name = object.name
        } else {
            precondition(ID == object.name)
            precondition(Name == object.name)
        }

        isServerControlled = true
        Name = object.name

        if let backgroundColor = object.backgroundColor {
            BackgroundColor = backgroundColor
        }

        if let iconName = object.iconIcon {
            IconName = iconName.normalizingIconString
        } else {
            let allCases = MaterialDesignIcons.allCases
            IconName = allCases[abs(object.name.djb2hash % allCases.count)].name
        }

        if let iconColor = object.iconColor {
            IconColor = iconColor
        }

        if let text = object.labelText {
            Text = text
        } else {
            Text = object.name.replacingOccurrences(of: "_", with: " ").localizedCapitalized
        }

        if let textColor = object.labelColor {
            TextColor = textColor
        }
    }

    #if os(iOS)
    public var uiShortcut: UIApplicationShortcutItem {
        return UIApplicationShortcutItem(
            type: self.ID,
            localizedTitle: self.Text,
            localizedSubtitle: nil,
            icon: nil,
            userInfo: [:]
        )
    }
    #endif

    public enum TriggerType {
        case event
        case scene
    }
    public var triggerType: TriggerType {
        if Scene == nil {
            return .event
        } else {
            return .scene
        }
    }

    public var exampleTrigger: String {
        switch triggerType {
        case .event:
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
        case .scene:
            let data = HomeAssistantAPI.actionScene(actionID: ID, source: .Preview)
            let eventDataStrings = data.serviceData.map { $0 + ": " + $1 }.sorted()

            let indentation = "\n      "

            return """
            # you can watch for the scene change
            - platform: event
              event_type: call_service
              event_data:
                domain: \(data.serviceDomain)
                service: \(data.serviceName)
                service_data:
                  \(eventDataStrings.joined(separator: indentation))
            """
        }
    }
}

extension UIColor {
    public static func randomBackgroundColor() -> UIColor {
        // avoiding:
        // - super gray (low saturation)
        // - super black (low brightness)
        // - super white (high brightness)
        UIColor(
            hue: CGFloat.random(in: 0...1.0),
            saturation: CGFloat.random(in: 0.5...1.0),
            brightness: CGFloat.random(in: 0.25...0.75),
            alpha: 1.0
        )
    }
}
