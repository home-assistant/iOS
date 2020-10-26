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

public final class Action: Object, ImmutableMappable, UpdatableModel {
    public enum PositionOffset: Int {
        case manual = 0
        case synced = 5_000
        case scene = 10_000
    }

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

    public required override init() {
        let background = UIColor.randomBackgroundColor()
        BackgroundColor = background.hexString()
        if background.isLight {
            TextColor = UIColor.black.hexString()
            IconColor = UIColor.black.hexString()
        } else {
            TextColor = UIColor.white.hexString()
            IconColor = UIColor.white.hexString()
        }

        super.init()
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

    public required init(map: Map) throws {
        // this is used for watch<->app syncing
        self.ID              = try map.value("ID")
        self.Name            = try map.value("Name")
        self.Position        = try map.value("Position")
        self.BackgroundColor = try map.value("BackgroundColor")
        self.IconName        = try map.value("IconName")
        self.IconColor       = try map.value("IconColor")
        self.Text            = try map.value("Text")
        self.TextColor       = try map.value("TextColor")
        self.CreatedAt       = try map.value("CreatedAt", using: DateTransform())
        self.isServerControlled = try map.value("isServerControlled")
        super.init()
    }

    public func mapping(map: Map) {
        ID               >>> map["ID"]
        Name             >>> map["Name"]
        Position         >>> map["Position"]
        BackgroundColor  >>> map["BackgroundColor"]
        IconName         >>> map["IconName"]
        IconColor        >>> map["IconColor"]
        Text             >>> map["Text"]
        TextColor        >>> map["TextColor"]
        CreatedAt        >>> (map["CreatedAt"], DateTransform())
        isServerControlled >>> map["isServerControlled"]
    }

    static func didUpdate(objects: [Action], realm: Realm) {
        for (idx, object) in objects.enumerated() {
            object.Position = PositionOffset.synced.rawValue + idx
        }
    }

    static func willDelete(objects: [Action], realm: Realm) {

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
        // we don't sync the scene information over to the watch, so checking ID which is synced
        if ID.starts(with: "scene.") {
            return .scene
        } else {
            return .event
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

    public var widgetLinkURL: URL {
        var components = URLComponents()
        components.scheme = "homeassistant"
        components.host = "perform_action"
        components.path = "/" + ID
        components.queryItems = [
            .init(name: "source", value: HomeAssistantAPI.ActionSource.Widget.rawValue)
        ]
        return components.url!
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
