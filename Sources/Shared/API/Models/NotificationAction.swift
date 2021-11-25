import Foundation
import RealmSwift
import UserNotifications

public class NotificationAction: Object {
    @objc public dynamic var uuid: String = UUID().uuidString
    @objc public dynamic var Identifier: String = ""
    @objc public dynamic var Title: String = ""
    @objc public dynamic var TextInput: Bool = false
    @objc public dynamic var isServerControlled: Bool = false
    @objc public dynamic var icon: String?

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
        self.icon = action.icon
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
        let action: UNNotificationAction

        let baseAction: () -> UNNotificationAction = { [self] in
            if TextInput {
                return UNTextInputNotificationAction(
                    identifier: Identifier,
                    title: Title,
                    options: options,
                    textInputButtonTitle: TextInputButtonTitle,
                    textInputPlaceholder: TextInputPlaceholder
                )
            } else {
                return UNNotificationAction(
                    identifier: Identifier,
                    title: Title,
                    options: options
                )
            }
        }

        if #available(iOS 15, watchOS 8, *) {
            let actionIcon: UNNotificationActionIcon?

            if let icon = icon, icon.hasPrefix("sfsymbols:") {
                actionIcon = .init(systemImageName: icon.replacingOccurrences(of: "sfsymbols:", with: ""))
            } else {
                actionIcon = nil
            }

            if TextInput {
                action = UNTextInputNotificationAction(
                    identifier: Identifier,
                    title: Title,
                    options: options,
                    icon: actionIcon,
                    textInputButtonTitle: TextInputButtonTitle,
                    textInputPlaceholder: TextInputPlaceholder
                )
            } else {
                action = UNNotificationAction(
                    identifier: Identifier,
                    title: Title,
                    options: options,
                    icon: actionIcon
                )
            }
        } else {
            action = baseAction()
        }

        return action
    }

    public class func exampleTrigger(
        api: HomeAssistantAPI,
        identifier: String,
        category: String?,
        textInput: Bool
    ) -> String {
        let data = api.legacyNotificationActionEvent(
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
