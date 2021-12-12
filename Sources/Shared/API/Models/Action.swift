import Foundation
import ObjectMapper
import RealmSwift
import UIKit

public final class Action: Object, ImmutableMappable, UpdatableModel {
    public enum PositionOffset: Int {
        case manual = 0
        case synced = 5000
        case scene = 1_000_000
    }

    @objc public dynamic var ID: String = UUID().uuidString
    @objc public dynamic var Name: String = ""
    @objc public dynamic var Text: String = ""
    @objc public dynamic var IconName: String = MaterialDesignIcons.allCases.randomElement()!.name
    @objc public dynamic var BackgroundColor: String
    @objc public dynamic var IconColor: String
    @objc public dynamic var TextColor: String
    @objc public dynamic var Position: Int = 0
    @objc public dynamic var CreatedAt = Date()
    @objc public dynamic var Scene: RLMScene?
    @objc public dynamic var isServerControlled: Bool = false
    @objc public dynamic var serverIdentifier: String = ""

    static func primaryKey(sourceIdentifier: String, serverIdentifier: String) -> String {
        #warning("multiserver - primary key duplication")
        return sourceIdentifier
    }

    override public static func primaryKey() -> String? {
        #keyPath(ID)
    }

    static func serverIdentifierKey() -> String {
        #keyPath(serverIdentifier)
    }

    override public required init() {
        let background = UIColor.randomBackgroundColor()
        self.BackgroundColor = background.hexString()
        if background.isLight {
            self.TextColor = UIColor.black.hexString()
            self.IconColor = UIColor.black.hexString()
        } else {
            self.TextColor = UIColor.white.hexString()
            self.IconColor = UIColor.white.hexString()
        }

        super.init()
    }

    public func canConfigure(_ keyPath: PartialKeyPath<Action>) -> Bool {
        if isServerControlled {
            return false
        }

        switch keyPath {
        case \Action.BackgroundColor:
            return Scene == nil || Scene?.backgroundColor == nil
        case \Action.TextColor:
            return Scene == nil || Scene?.textColor == nil
        case \Action.IconColor:
            return Scene == nil || Scene?.iconColor == nil
        case \Action.IconName,
             \Action.Name,
             \Action.Text:
            return Scene == nil
        case \Action.serverIdentifier:
            return Scene == nil
        default:
            return true
        }
    }

    public required init(map: ObjectMapper.Map) throws {
        // this is used for watch<->app syncing
        self.ID = try map.value("ID")
        self.Name = try map.value("Name")
        self.Position = try map.value("Position")
        self.BackgroundColor = try map.value("BackgroundColor")
        self.IconName = try map.value("IconName")
        self.IconColor = try map.value("IconColor")
        self.Text = try map.value("Text")
        self.TextColor = try map.value("TextColor")
        self.CreatedAt = try map.value("CreatedAt", using: DateTransform())
        self.isServerControlled = try map.value("isServerControlled")
        self.serverIdentifier = try map.value("serverIdentifier")
        super.init()
    }

    public func mapping(map: ObjectMapper.Map) {
        ID >>> map["ID"]
        Name >>> map["Name"]
        Position >>> map["Position"]
        BackgroundColor >>> map["BackgroundColor"]
        IconName >>> map["IconName"]
        IconColor >>> map["IconColor"]
        Text >>> map["Text"]
        TextColor >>> map["TextColor"]
        CreatedAt >>> (map["CreatedAt"], DateTransform())
        isServerControlled >>> map["isServerControlled"]
        serverIdentifier >>> map["serverIdentifier"]
    }

    static func didUpdate(objects: [Action], server: Server, realm: Realm) {
        for (idx, object) in objects.enumerated() {
            object.Position = PositionOffset.synced.rawValue + server.info.sortOrder + idx
        }
    }

    static func willDelete(objects: [Action], server: Server?, realm: Realm) {}

    static var updateEligiblePredicate: NSPredicate {
        .init(format: "isServerControlled == YES")
    }

    public func update(with object: MobileAppConfigAction, server: Server, using realm: Realm) -> Bool {
        if self.realm == nil {
            ID = object.name
            Name = object.name
        } else {
            precondition(ID == object.name)
            precondition(Name == object.name)
        }

        isServerControlled = true
        serverIdentifier = server.identifier.rawValue
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

        return true
    }

    #if os(iOS)
    public var uiShortcut: UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: ID,
            localizedTitle: Text,
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

    public func exampleTrigger(api: HomeAssistantAPI) -> String {
        switch triggerType {
        case .event:
            let data = api.actionEvent(actionID: ID, actionName: Name, source: .Preview)
            let eventDataStrings = data.eventData.map { $0 + ": " + $1 }.sorted()
            let sourceStrings = HomeAssistantAPI.ActionSource.allCases.map(\.description).sorted()

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
            let data = api.actionScene(actionID: ID, source: .Preview)
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
            .init(name: "source", value: HomeAssistantAPI.ActionSource.Widget.rawValue),
        ]
        return components.url!
    }
}

public extension UIColor {
    static func randomBackgroundColor() -> UIColor {
        // avoiding:
        // - super gray (low saturation)
        // - super black (low brightness)
        // - super white (high brightness)
        UIColor(
            hue: CGFloat.random(in: 0 ... 1.0),
            saturation: CGFloat.random(in: 0.5 ... 1.0),
            brightness: CGFloat.random(in: 0.25 ... 0.75),
            alpha: 1.0
        )
    }
}
