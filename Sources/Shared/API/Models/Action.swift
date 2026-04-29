import Foundation
import ObjectMapper
import RealmSwift
import UIKit

public final class Action: Object, ImmutableMappable {
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
    @objc public dynamic var showInCarPlay: Bool = true
    @objc public dynamic var showInWatch: Bool = true
    @objc public dynamic var useCustomColors: Bool = false

    override public static func primaryKey() -> String? {
        #keyPath(ID)
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
        case \Action.showInCarPlay:
            return Scene == nil
        case \Action.showInWatch:
            return Scene == nil
        case \Action.useCustomColors:
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
        self.showInCarPlay = try map.value("showInCarPlay")
        self.showInWatch = try map.value("showInWatch")
        self.useCustomColors = try map.value("useCustomColors")
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
        showInCarPlay >>> map["showInCarPlay"]
        showInWatch >>> map["showInWatch"]
        useCustomColors >>> map["useCustomColors"]
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

    public func exampleTrigger(api: HomeAssistantAPI) -> String {
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

    public var widgetLinkURL: URL {
        var components = URLComponents()
        components.scheme = "homeassistant"
        components.host = "perform_action"
        components.path = "/" + ID
        components.queryItems = [
            .init(name: "source", value: AppTriggerSource.Widget.rawValue),
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
