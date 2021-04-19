import Foundation
import RealmSwift
import UserNotifications

public class NotificationAction: Object {
    @objc public dynamic var uuid: String = UUID().uuidString
    @objc public dynamic var Identifier: String = ""
    @objc public dynamic var Title: String = ""
    @objc public dynamic var TextInput: Bool = false
    @objc public dynamic var isServerControlled: Bool = false

    // Options
    @objc public dynamic var Foreground: Bool = false
    @objc public dynamic var Destructive: Bool = false
    @objc public dynamic var AuthenticationRequired: Bool = false

    // Text Input Options
    @objc public dynamic var TextInputButtonTitle: String = L10n.NotificationsConfigurator.Action.Rows
        .TextInputButtonTitle.title
    @objc public dynamic var TextInputPlaceholder: String = L10n.NotificationsConfigurator.Action.Rows
        .TextInputPlaceholder.title
    // swiftlint:enable line_length

    public convenience init(action: MobileAppConfigPushCategory.Action) {
        self.init()

        self.isServerControlled = true
        self.Title = action.title
        self.Identifier = action.identifier
        self.AuthenticationRequired = action.authenticationRequired
        self.Foreground = (action.activationMode.lowercased() == "foreground")
        self.Destructive = action.destructive
        self.TextInput = (action.behavior.lowercased() == "textinput")
        if let title = action.textInputButtonTitle {
            self.TextInputButtonTitle = title
        } else {
            self.TextInputButtonTitle = L10n.NotificationsConfigurator.Action.Rows.TextInputButtonTitle.title
        }
        if let placeholder = action.textInputPlaceholder {
            self.TextInputPlaceholder = placeholder
        } else {
            self.TextInputPlaceholder = L10n.NotificationsConfigurator.Action.Rows.TextInputPlaceholder.title
        }
    }

    override public static func primaryKey() -> String? {
        "uuid"
    }

    public let categories = LinkingObjects(fromType: NotificationCategory.self, property: "Actions")

    public var options: UNNotificationActionOptions {
        var actionOptions = UNNotificationActionOptions([])
        if AuthenticationRequired { actionOptions.insert(.authenticationRequired) }
        if Destructive { actionOptions.insert(.destructive) }
        if Foreground { actionOptions.insert(.foreground) }

        return actionOptions
    }

    public var action: UNNotificationAction {
        if TextInput {
            return UNTextInputNotificationAction(
                identifier: Identifier,
                title: Title,
                options: options,
                textInputButtonTitle: TextInputButtonTitle,
                textInputPlaceholder: TextInputPlaceholder
            )
        }

        return UNNotificationAction(identifier: Identifier, title: Title, options: options)
    }

    public class func exampleTrigger(
        identifier: String,
        category: String?,
        textInput: Bool
    ) -> String {
        let data = HomeAssistantAPI.legacyNotificationActionEvent(
            identifier: identifier,
            category: category,
            actionData: "# value of action_data in notify call",
            textInput: textInput ? "# text you input" : nil
        )
        let eventDataStrings = data.eventData.map { $0 + ": " + String(describing: $1) }.sorted()

        let indentation = "\n    "

        return """
        - platform: event
          event_type: \(data.eventType)
          event_data:
            \(eventDataStrings.joined(separator: indentation))
        """
    }
}
