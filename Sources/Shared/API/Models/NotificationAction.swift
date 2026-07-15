import Foundation
import UserNotifications

/// An action belonging to a `NotificationCategory`. Persisted as JSON inside
/// the owning category's GRDB row.
public struct NotificationAction: Codable, Equatable, Identifiable {
    public var id: String
    public var identifier: String
    public var title: String
    public var textInput: Bool
    public var isServerControlled: Bool
    public var icon: String?

    // Options
    public var foreground: Bool
    public var destructive: Bool
    public var authenticationRequired: Bool

    // Text Input Options
    public var textInputButtonTitle: String
    public var textInputPlaceholder: String

    public init(
        id: String = UUID().uuidString,
        identifier: String = "",
        title: String = "",
        textInput: Bool = false,
        isServerControlled: Bool = false,
        icon: String? = nil,
        foreground: Bool = false,
        destructive: Bool = false,
        authenticationRequired: Bool = false,
        textInputButtonTitle: String? = nil,
        textInputPlaceholder: String? = nil
    ) {
        self.id = id
        self.identifier = identifier
        self.title = title
        self.textInput = textInput
        self.isServerControlled = isServerControlled
        self.icon = icon
        self.foreground = foreground
        self.destructive = destructive
        self.authenticationRequired = authenticationRequired
        self.textInputButtonTitle = textInputButtonTitle
            ?? L10n.NotificationsConfigurator.Action.Rows.TextInputButtonTitle.title
        self.textInputPlaceholder = textInputPlaceholder
            ?? L10n.NotificationsConfigurator.Action.Rows.TextInputPlaceholder.title
    }

    public init(action: MobileAppConfigPushCategory.Action) {
        self.init(
            identifier: action.identifier,
            title: action.title,
            textInput: action.behavior.lowercased() == "textinput",
            isServerControlled: true,
            icon: action.icon,
            foreground: action.activationMode.lowercased() == "foreground",
            destructive: action.destructive,
            authenticationRequired: action.authenticationRequired,
            textInputButtonTitle: action.textInputButtonTitle,
            textInputPlaceholder: action.textInputPlaceholder
        )
    }

    public var options: UNNotificationActionOptions {
        var actionOptions = UNNotificationActionOptions([])
        if authenticationRequired { actionOptions.insert(.authenticationRequired) }
        if destructive { actionOptions.insert(.destructive) }
        if foreground { actionOptions.insert(.foreground) }

        return actionOptions
    }

    public var action: UNNotificationAction {
        let action: UNNotificationAction
        let actionIcon: UNNotificationActionIcon?

        if let icon, icon.hasPrefix("sfsymbols:") {
            actionIcon = .init(systemImageName: icon.replacingOccurrences(of: "sfsymbols:", with: ""))
        } else {
            actionIcon = nil
        }

        if textInput {
            action = UNTextInputNotificationAction(
                identifier: identifier,
                title: title,
                options: options,
                icon: actionIcon,
                textInputButtonTitle: textInputButtonTitle,
                textInputPlaceholder: textInputPlaceholder
            )
        } else {
            action = UNNotificationAction(
                identifier: identifier,
                title: title,
                options: options,
                icon: actionIcon
            )
        }

        return action
    }

    public static func exampleTrigger(
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
