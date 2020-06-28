//
//  NotificationAction.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/28/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import RealmSwift
import Shared
import UserNotifications

public class NotificationAction: Object {
    @objc dynamic var Identifier: String = ""
    @objc dynamic var Title: String = ""
    @objc dynamic var TextInput: Bool = false

    // Options
    @objc dynamic var Foreground: Bool = false
    @objc dynamic var Destructive: Bool = false
    @objc dynamic var AuthenticationRequired: Bool = false

    // Text Input Options
    // swiftlint:disable line_length
    @objc dynamic var TextInputButtonTitle: String = L10n.NotificationsConfigurator.Action.Rows.TextInputButtonTitle.title
    @objc dynamic var TextInputPlaceholder: String = L10n.NotificationsConfigurator.Action.Rows.TextInputPlaceholder.title
    // swiftlint:enable line_length

    let categories = LinkingObjects(fromType: NotificationCategory.self, property: "Actions")
    var Category: NotificationCategory? { return categories.first }

    override public static func primaryKey() -> String? {
        return "Identifier"
    }

    var options: UNNotificationActionOptions {
        var actionOptions = UNNotificationActionOptions([])
        if self.AuthenticationRequired { actionOptions.insert(.authenticationRequired) }
        if self.Destructive { actionOptions.insert(.destructive) }
        if self.Foreground { actionOptions.insert(.foreground) }

        return actionOptions
    }

    var action: UNNotificationAction {
        if self.TextInput {
            return UNTextInputNotificationAction(identifier: self.Identifier, title: self.Title, options: self.options,
                                                 textInputButtonTitle: self.TextInputButtonTitle,
                                                 textInputPlaceholder: self.TextInputPlaceholder)
        }

        return UNNotificationAction(identifier: self.Identifier, title: self.Title, options: self.options)
    }

    public class func exampleTrigger(
        identifier: String,
        category: String?,
        textInput: Bool
    ) -> String {
        let data = HomeAssistantAPI.notificationActionEvent(
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
