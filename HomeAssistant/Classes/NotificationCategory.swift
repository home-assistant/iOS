//
//  NotificationCategory.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/28/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import RealmSwift
import UserNotifications

public class NotificationCategory: Object {
    @objc dynamic var Name: String = ""
    @objc dynamic var Identifier: String = ""
    @objc dynamic var HiddenPreviewsBodyPlaceholder: String?
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

        if self.HiddenPreviewsShowTitle { categoryOptions.insert(.hiddenPreviewsShowTitle) }
        if self.HiddenPreviewsShowSubtitle { categoryOptions.insert(.hiddenPreviewsShowSubtitle) }

        return categoryOptions
    }

    var category: UNNotificationCategory {

        let allActions = Array(self.Actions.map({ $0.action }))

        return UNNotificationCategory(identifier: self.Identifier, actions: allActions,
                                      intentIdentifiers: [],
                                      hiddenPreviewsBodyPlaceholder: self.HiddenPreviewsBodyPlaceholder,
                                      categorySummaryFormat: self.CategorySummaryFormat,
                                      options: self.options)

    }
}
