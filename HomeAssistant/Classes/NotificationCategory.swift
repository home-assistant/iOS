//
//  NotificationCategory.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/28/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import Shared
import RealmSwift
import DeviceKit
import UserNotifications

public class NotificationCategory: Object {
    static let FallbackActionIdentifier = "_"

    @objc dynamic var Name: String = ""
    @objc dynamic var Identifier: String = ""
    // iOS 11+ only
    @objc dynamic var HiddenPreviewsBodyPlaceholder: String?
    // iOS 12+ only
    @objc dynamic var CategorySummaryFormat: String?

    // Options
    @objc dynamic var SendDismissActions: Bool = true
    // iOS 11+ only
    @objc dynamic var HiddenPreviewsShowTitle: Bool = false
    @objc dynamic var HiddenPreviewsShowSubtitle: Bool = false

    // Maybe someday, HA will be on CarPlay (hey that rhymes!)...
    // @objc dynamic var AllowInCarPlay: Bool = false

    var Actions = List<NotificationAction>()

    override public static func primaryKey() -> String? {
        return "Identifier"
    }

    var options: UNNotificationCategoryOptions {
        var categoryOptions = UNNotificationCategoryOptions([])

        if self.SendDismissActions { categoryOptions.insert(.customDismissAction) }

        if #available(iOS 11.0, *) {
            if self.HiddenPreviewsShowTitle { categoryOptions.insert(.hiddenPreviewsShowTitle) }
            if self.HiddenPreviewsShowSubtitle { categoryOptions.insert(.hiddenPreviewsShowSubtitle) }
        }

        return categoryOptions
    }

    var categories: [UNNotificationCategory] {
        let allActions = Array(self.Actions.map({ $0.action }))

        // both lowercase and uppercase since this is a point of confusion
        return [ Identifier.uppercased(), Identifier.lowercased() ].map { anIdentifier in
            if #available(iOS 12.0, *) {
                return UNNotificationCategory(identifier: anIdentifier, actions: allActions, intentIdentifiers: [],
                                              hiddenPreviewsBodyPlaceholder: self.HiddenPreviewsBodyPlaceholder,
                                              categorySummaryFormat: self.CategorySummaryFormat,
                                              options: self.options)
            } else if #available(iOS 11.0, *), let placeholder = self.HiddenPreviewsBodyPlaceholder {
                return UNNotificationCategory(identifier: anIdentifier, actions: allActions, intentIdentifiers: [],
                                              hiddenPreviewsBodyPlaceholder: placeholder,
                                              options: self.options)
            } else {
                return UNNotificationCategory(identifier: anIdentifier, actions: allActions,
                                              intentIdentifiers: [], options: self.options)
            }
        }
    }

    public var exampleServiceCall: String {
        let urlStrings = Actions.map { "\"\($0.Identifier)\": \"http://example.com/url\"" }

        let indentation = "\n  "

        return """
        service: notify.mobile_app_#name_here
        data:
          push:
            category: \(Identifier.uppercased())
          action_data:
            # see example trigger in action
            # value will be in fired event

          # url can be absolute path like:
          # "http://example.com/url"
          # or relative like:
          # "/lovelace/dashboard"

          # pick one of the following styles:

          # always open when opening notification
          url: "/lovelace/dashboard"

          # open a different url per action
          # use "\(Self.FallbackActionIdentifier)" as key for no action chosen
          url:
          - "\(Self.FallbackActionIdentifier)": "http://example.com/fallback"
          - \(urlStrings.joined(separator: indentation + "- "))
        """
    }
}
