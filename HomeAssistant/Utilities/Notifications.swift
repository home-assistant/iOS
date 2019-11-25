//
//  Notifications.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/28/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import Shared
import RealmSwift
import UserNotifications
import PromiseKit

extension HomeAssistantAPI {
    public static func ProvideNotificationCategoriesToSystem() {
        let realm = Current.realm()
        var categories = Set<UNNotificationCategory>(realm.objects(NotificationCategory.self).map({ $0.category }))

        if Current.appConfiguration == .FastlaneSnapshot {
            let cameraCat = UNNotificationCategory(identifier: "camera",
                                                   actions: [],
                                                   intentIdentifiers: [],
                                                   options: UNNotificationCategoryOptions([.customDismissAction]))
            let mapCat = UNNotificationCategory(identifier: "map",
                                                actions: [],
                                                intentIdentifiers: [],
                                                options: UNNotificationCategoryOptions([.customDismissAction]))
            categories.formUnion([cameraCat, mapCat])
        }

        Current.Log.verbose("Providing \(categories.count) categories to system: \(categories)")

        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

    public func MigratePushSettingsToLocal() -> Promise<[NotificationCategory]> {
        return firstly {
            self.GetPushSettings()
        }.compactMap { settings -> [NotificationCategory] in
            var cats: [NotificationCategory] = []
            guard let categories = settings.Categories else {
                Current.Log.warning("Unable to unwrap push categories or none exist! \(settings)")
                return cats
            }

            let realm = Current.realm()
            for remoteCategory in categories {
                let localCategory = NotificationCategory()
                Current.Log.verbose("Attempting import of category \(remoteCategory.Identifier)")
                localCategory.Identifier = remoteCategory.Identifier
                localCategory.Name = remoteCategory.Name

                if let catActions = remoteCategory.Actions {
                    for remoteAction in catActions {
                        Current.Log.verbose("Attempting import of action \(remoteAction.Identifier)")
                        let localAction = NotificationAction()
                        localAction.Title = remoteAction.Title
                        localAction.Identifier = remoteAction.Identifier
                        localAction.AuthenticationRequired = remoteAction.AuthenticationRequired
                        localAction.Foreground = (remoteAction.ActivationMode.lowercased() == "foreground")
                        localAction.Destructive = remoteAction.Destructive
                        localAction.TextInput = (remoteAction.Behavior.lowercased() == "textinput")
                        if let buttonTitle = remoteAction.TextInputButtonTitle {
                            localAction.TextInputButtonTitle = buttonTitle
                        }
                        if let placeholder = remoteAction.TextInputPlaceholder {
                            localAction.TextInputPlaceholder = placeholder
                        }

                        // swiftlint:disable:next force_try
                        try! realm.write {
                            realm.add(localAction, update: .all)
                            localCategory.Actions.append(localAction)
                        }
                    }
                }

                // swiftlint:disable:next force_try
                try! realm.write {
                    realm.add(localCategory, update: .all)
                }
                cats.append(localCategory)
            }
            HomeAssistantAPI.ProvideNotificationCategoriesToSystem()
            return cats
        }
    }
}
